#!/usr/bin/env python3
"""
PRIORITY Token Guardian Check
Runs BEFORE message processing to prevent overflow

Installation:
  This must be the FIRST hook in preMessage chain
  
Behavior:
  - If tokens < 75%: Allow message, update tracking
  - If tokens 75-85%: Warn user, allow with notice
  - If tokens 85-95%: Force summarize first, then allow
  - If tokens > 95%: Block message, require action
"""

import json
import sys
import os
import subprocess
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
from token_guardian import TokenGuardianManager, MODEL_LIMITS

def get_openclaw_model():
    """Get current model from environment or OpenClaw."""
    model = os.environ.get('OPENCLAW_MODEL')
    if model:
        return model
    
    try:
        result = subprocess.run(
            ['openclaw', 'status', '--json'],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            status = json.loads(result.stdout)
            return status.get('model', 'ollama/kimi-k2.5')
    except:
        pass
    
    return 'ollama/kimi-k2.5'

def estimate_tokens(message):
    """Rough token estimate: ~4 chars per token."""
    return len(message) // 4

def priority_check():
    """
    PRIORITY CHECK: Run before message processing
    Returns exit code that controls message flow
    """
    session_key = os.environ.get('OPENCLAW_SESSION_KEY', 'main')
    model = get_openclaw_model()
    
    # Get incoming message (if available)
    message = os.environ.get('OPENCLAW_INCOMING_MESSAGE', '')
    incoming_tokens = estimate_tokens(message)
    
    manager = TokenGuardianManager()
    
    # Get current state
    if session_key in manager.sessions:
        current_tokens = manager.sessions[session_key].current
        limit = manager.sessions[session_key].limit
    else:
        # First time - initialize
        current_tokens = 0
        limit = MODEL_LIMITS.get(model, 8192)
    
    # Calculate projected usage
    projected = current_tokens + incoming_tokens
    percent = (current_tokens / limit) * 100
    projected_percent = (projected / limit) * 100
    
    result = {
        "session": session_key,
        "model": model,
        "current_tokens": current_tokens,
        "incoming_tokens": incoming_tokens,
        "projected_tokens": projected,
        "limit": limit,
        "current_percent": round(percent, 1),
        "projected_percent": round(projected_percent, 1)
    }
    
    # PRIORITY DECISIONS
    
    if projected_percent >= 95:
        # BLOCK: Would overflow
        result.update({
            "action": "BLOCK",
            "priority": "CRITICAL",
            "message": f"🚨 BLOCKED: This message would exceed context limit!",
            "reason": f"Projected {projected_percent:.1f}% ({projected}/{limit} tokens)",
            "solutions": [
                "/reset to start fresh session",
                "/model ollama/qwen3.5:397b-cloud (32K limit)",
                "Summarize conversation first"
            ]
        })
        print(json.dumps(result, indent=2))
        return 1  # Exit code 1 = BLOCK
    
    elif projected_percent >= 85:
        # WARN: High risk
        result.update({
            "action": "WARN",
            "priority": "HIGH", 
            "message": f"⚠️ WARNING: Context at {projected_percent:.1f}%",
            "notice": "Message allowed, but consider summarizing soon",
            "suggestion": "Type '/summarize' to compress context"
        })
        # Update tracking and ALLOW
        manager.register_session(session_key, model, projected)
        print(json.dumps(result, indent=2), file=sys.stderr)
        return 0  # Exit code 0 = ALLOW
    
    elif projected_percent >= 75:
        # NOTICE: Approaching limit
        result.update({
            "action": "NOTICE",
            "priority": "MEDIUM",
            "message": f"⚡ Context at {projected_percent:.1f}%",
            "notice": "Still safe, but monitor usage"
        })
        manager.register_session(session_key, model, projected)
        print(json.dumps(result, indent=2), file=sys.stderr)
        return 0
    
    else:
        # OK: Safe to proceed
        result.update({
            "action": "OK",
            "priority": "LOW",
            "message": f"✅ Context healthy ({projected_percent:.1f}%)"
        })
        manager.register_session(session_key, model, projected)
        return 0

if __name__ == "__main__":
    sys.exit(priority_check())
