#!/usr/bin/env python3
"""
Token-aware context guardian for OpenClaw.
Tracks token usage, handles sub-agent spawn, model switches, and overflow prevention.
"""

import json
import sys
from datetime import datetime
from pathlib import Path

# Model context limits (in tokens)
MODEL_LIMITS = {
    "ollama/kimi-k2.5": 8192,
    "ollama/kimi-k2.5:cloud": 8192,
    "ollama/qwen3.5:397b-cloud": 32768,
    "ollama/qwen3.5": 32768,
    "claude-3-5-sonnet": 200000,
    "claude-3-5-sonnet-20241022": 200000,
    "gpt-4": 8192,
    "gpt-4-turbo": 128000,
    "gpt-4o": 128000,
}

# Default limits if model unknown
DEFAULT_LIMIT = 8192
WARN_THRESHOLD = 0.75
ACT_THRESHOLD = 0.85
EMERGENCY_THRESHOLD = 0.95


class TokenGuardian:
    """Tracks token usage and manages context lifecycle."""
    
    def __init__(self, session_key, model, current_tokens=0, is_subagent=False, parent_session=None):
        self.session_key = session_key
        self.model = model
        self.limit = MODEL_LIMITS.get(model, DEFAULT_LIMIT)
        self.current = current_tokens
        self.is_subagent = is_subagent
        self.parent_session = parent_session
        self.percent = (current_tokens / self.limit) * 100 if self.limit > 0 else 0
        self.timestamp = datetime.now().isoformat()
    
    def update_model(self, new_model):
        """Handle model switch - preserves tokens, recalculates percentage."""
        old_limit = self.limit
        self.model = new_model
        self.limit = MODEL_LIMITS.get(new_model, DEFAULT_LIMIT)
        self.percent = (self.current / self.limit) * 100 if self.limit > 0 else 0
        
        return {
            "event": "model_switched",
            "timestamp": datetime.now().isoformat(),
            "old_model": self.model,
            "new_model": new_model,
            "old_limit": old_limit,
            "new_limit": self.limit,
            "current_tokens": self.current,
            "new_percent": round(self.percent, 1)
        }
    
    def spawn_subagent(self, child_session_key, child_model=None):
        """Create guardian for sub-agent with fresh context."""
        child_model = child_model or self.model
        return TokenGuardian(
            session_key=child_session_key,
            model=child_model,
            current_tokens=0,  # Fresh start
            is_subagent=True,
            parent_session=self.session_key
        )
    
    def to_dict(self):
        """Serialize for storage."""
        return {
            "session_key": self.session_key,
            "model": self.model,
            "limit": self.limit,
            "current_tokens": self.current,
            "percent": round(self.percent, 1),
            "is_subagent": self.is_subagent,
            "parent_session": self.parent_session,
            "timestamp": self.timestamp
        }
    
    @classmethod
    def from_dict(cls, data):
        """Deserialize from storage."""
        return cls(
            session_key=data["session_key"],
            model=data["model"],
            current_tokens=data["current_tokens"],
            is_subagent=data.get("is_subagent", False),
            parent_session=data.get("parent_session")
        )
    
    def check(self, auto_execute=True):
        """Returns action needed based on current token usage."""
        result = {
            "session_key": self.session_key,
            "model": self.model,
            "limit": self.limit,
            "current_tokens": self.current,
            "percent": round(self.percent, 1),
            "is_subagent": self.is_subagent,
            "timestamp": self.timestamp
        }
        
        if self.percent >= EMERGENCY_THRESHOLD * 100:
            result.update({
                "status": "emergency",
                "action": "upgrade_model",
                "message": f"🚨 CRITICAL: {self.percent:.1f}% token usage ({self.current}/{self.limit}). Switching to larger model or context will be lost.",
                "recommendation": self._get_upgrade_recommendation(),
                "can_summarize": False
            })
        elif self.percent >= ACT_THRESHOLD * 100:
            result.update({
                "status": "high",
                "action": "summarize",
                "message": f"⚠️ HIGH: {self.percent:.1f}% token usage. Summarizing oldest 20% of context to prevent overflow.",
                "strategy": "Extract key decisions to MEMORY.md, summarize conversation",
                "can_summarize": True,
                "tokens_to_summarize": int(self.current * 0.2)
            })
        elif self.percent >= WARN_THRESHOLD * 100:
            result.update({
                "status": "warning",
                "action": "warn",
                "message": f"⚡ WARNING: {self.percent:.1f}% token usage. Monitor closely. {self.limit - self.current} tokens remaining.",
                "can_summarize": True
            })
        else:
            result.update({
                "status": "ok",
                "action": "none",
                "message": f"✅ Healthy: {self.percent:.1f}% token usage.",
                "can_summarize": False
            })
        
        return result
    
    def _get_upgrade_recommendation(self):
        """Suggest larger model based on current usage."""
        if self.current < 32000:
            return "Switch to qwen3.5:397b-cloud (32K context)"
        elif self.current < 200000:
            return "Switch to claude-3-5-sonnet (200K context)"
        else:
            return "Context critically full. Immediate /reset required."
    
    def summarize_oldest(self, percent=20):
        """Calculate how many tokens to summarize."""
        tokens_to_remove = int(self.current * (percent / 100))
        new_count = self.current - tokens_to_remove
        new_percent = (new_count / self.limit) * 100
        
        return {
            "tokens_removed": tokens_to_remove,
            "new_token_count": new_count,
            "new_percent": round(new_percent, 1),
            "strategy": f"Summarize oldest {percent}% ({tokens_to_remove} tokens) to MEMORY.md"
        }


class TokenGuardianManager:
    """Manages multiple session guardians with model validation."""
    
    def __init__(self, state_file=None):
        self.state_file = state_file or Path.home() / ".openclaw/workspace/memory/token-guardian-state.json"
        self.sessions = {}
        self._load_state()
    
    def _load_state(self):
        """Load persisted state."""
        if self.state_file.exists():
            try:
                data = json.loads(self.state_file.read_text())
                for session_key, session_data in data.get("sessions", {}).items():
                    self.sessions[session_key] = TokenGuardian.from_dict(session_data)
            except (json.JSONDecodeError, KeyError):
                pass
    
    def _save_state(self):
        """Persist current state."""
        self.state_file.parent.mkdir(parents=True, exist_ok=True)
        data = {
            "last_update": datetime.now().isoformat(),
            "sessions": {k: v.to_dict() for k, v in self.sessions.items()}
        }
        self.state_file.write_text(json.dumps(data, indent=2))
    
    def _load_auto_config(self):
        """Load auto-action configuration from config file."""
        config_file = Path.home() / ".openclaw/workspace/memory/token-guardian-config.json"
        if config_file.exists():
            try:
                with open(config_file) as f:
                    config = json.load(f)
                    return config.get("auto_action", {
                        "enabled": True,
                        "at_85_percent": True,
                        "at_95_percent": False,
                        "notify_on_action": True
                    })
            except:
                pass
        return {
            "enabled": True,
            "at_85_percent": True,
            "at_95_percent": False,
            "notify_on_action": True
        }
    
    def _validate_model(self, session_key, actual_model):
        """Check if saved model matches actual model. Auto-update if mismatch."""
        if session_key not in self.sessions:
            return None
        
        saved = self.sessions[session_key]
        if saved.model != actual_model:
            old_model = saved.model
            old_percent = saved.percent
            saved.update_model(actual_model)
            new_percent = saved.percent
            self._save_state()
            
            return {
                "model_mismatch_detected": True,
                "old_model": old_model,
                "actual_model": actual_model,
                "old_percent": old_percent,
                "recalculated_percent": new_percent,
                "action": "auto_updated"
            }
        return None
    
    def register_session(self, session_key, model, current_tokens=0, is_subagent=False, parent_session=None):
        """Register a new or update existing session with model validation."""
        if session_key in self.sessions:
            self._validate_model(session_key, model)
            self.sessions[session_key].current = current_tokens
            self.sessions[session_key].percent = (current_tokens / self.sessions[session_key].limit * 100) if self.sessions[session_key].limit > 0 else 0
            self._save_state()
            return self.sessions[session_key].check()
        
        guardian = TokenGuardian(
            session_key=session_key,
            model=model,
            current_tokens=current_tokens,
            is_subagent=is_subagent,
            parent_session=parent_session
        )
        self.sessions[session_key] = guardian
        self._save_state()
        return guardian.check()
    
    def get_all_sessions(self):
        """Return status of all tracked sessions."""
        return {key: guardian.check() for key, guardian in self.sessions.items()}
    
    def get_stats(self):
        """Get aggregate statistics."""
        total = len(self.sessions)
        warnings = sum(1 for g in self.sessions.values() if g.percent >= WARN_THRESHOLD * 100)
        critical = sum(1 for g in self.sessions.values() if g.percent >= EMERGENCY_THRESHOLD * 100)
        subagents = sum(1 for g in self.sessions.values() if g.is_subagent)
        
        return {
            "total_sessions": total,
            "warning_sessions": warnings,
            "critical_sessions": critical,
            "subagent_sessions": subagents,
            "healthy_sessions": total - warnings
        }


def check_main():
    """Check main session - designed for cron usage."""
    import os
    
    session_key = os.environ.get('OPENCLAW_SESSION_KEY', 'main')
    model = os.environ.get('OPENCLAW_MODEL', 'ollama/kimi-k2.5')
    tokens_used = 0
    
    manager = TokenGuardianManager()
    result = manager.register_session(session_key, model, tokens_used)
    
    if result.get('status') in ['high', 'emergency']:
        print(f"[{datetime.now().isoformat()}] ALERT: {result['message']}")
        if result.get('auto_executed'):
            print(f"  Auto-action: {result.get('execution_result', {})}")
    
    return result


def main():
    """CLI interface."""
    if len(sys.argv) < 2:
        print("Usage: token-guardian.py <command> [args...]")
        print("")
        print("Commands:")
        print("  check <session_key> <model> [current_tokens]")
        print("  status")
        print("  stats")
        print("  check-main")
        sys.exit(1)
    
    command = sys.argv[1]
    manager = TokenGuardianManager()
    
    if command == "check" and len(sys.argv) >= 4:
        result = manager.register_session(
            session_key=sys.argv[2],
            model=sys.argv[3],
            current_tokens=int(sys.argv[4]) if len(sys.argv) > 4 else 0
        )
        print(json.dumps(result, indent=2))
    
    elif command == "status":
        sessions = manager.get_all_sessions()
        print(json.dumps(sessions, indent=2))
    
    elif command == "stats":
        stats = manager.get_stats()
        print(json.dumps(stats, indent=2))
    
    elif command == "check-main":
        result = check_main()
        print(json.dumps(result, indent=2))
    
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)


if __name__ == "__main__":
    main()
