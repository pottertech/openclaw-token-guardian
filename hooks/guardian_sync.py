#!/usr/bin/env python3
"""
OpenClaw Token Guardian Sync Hook
Called automatically by OpenClaw to keep token usage in sync.

Installation:
  Add to OpenClaw config:
    hooks:
      pre_message: ~/.openclaw/workspace/repos/openclaw-memory-utilities/hooks/guardian_sync.py
      post_message: ~/.openclaw/workspace/repos/openclaw-memory-utilities/hooks/guardian_sync.py
"""

import json
import sys
import os
import subprocess
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))
from token_guardian import TokenGuardianManager

def get_openclaw_model():
    """Get current model from OpenClaw runtime."""
    # Try environment variable first (OpenClaw should set this)
    model = os.environ.get('OPENCLAW_MODEL')
    if model:
        return model
    
    # Fallback: try to query OpenClaw status
    try:
        result = subprocess.run(
            ['openclaw', 'status', '--json'],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            status = json.loads(result.stdout)
            model = status.get('model')
            if model:
                return model
    except (subprocess.TimeoutExpired, json.JSONDecodeError, FileNotFoundError):
        pass
    
    # Fallback: read from OpenClaw config
    try:
        config_path = Path.home() / '.openclaw/config.yaml'
        if config_path.exists():
            import yaml
            with open(config_path) as f:
                config = yaml.safe_load(f)
                model = config.get('gateway', {}).get('model')
                if model:
                    return model
    except (ImportError, yaml.YAMLError):
        pass
    
    # Last resort: detect from session context
    return detect_from_context()

def detect_from_context():
    """Detect model from session context clues."""
    # Check if we're in a known model context
    runtime_info = os.environ.get('OPENCLAW_RUNTIME', '')
    
    # Parse runtime string like "agent=main | model=ollama/kimi-k2.5:cloud"
    if 'model=' in runtime_info:
        parts = runtime_info.split('model=')
        if len(parts) > 1:
            model_part = parts[1].split()[0]
            return model_part
    
    # Default fallback
    return 'ollama/kimi-k2.5'

def get_session_key():
    """Get current session key."""
    return os.environ.get('OPENCLAW_SESSION_KEY', 'main')

def get_token_count():
    """Get current token count if available."""
    tokens = os.environ.get('OPENCLAW_TOKENS_USED')
    if tokens:
        try:
            return int(tokens)
        except ValueError:
            pass
    
    # Try to estimate from message history length
    msg_len = os.environ.get('OPENCLAW_MESSAGE_LENGTH', '0')
    # Rough estimate: 1 token ≈ 4 characters for English
    try:
        return int(msg_len) // 4
    except ValueError:
        return 0

def sync_from_environment():
    """Sync guardian state from OpenClaw."""
    session_key = get_session_key()
    model = get_openclaw_model()
    tokens_used = get_token_count()
    
    manager = TokenGuardianManager()
    
    # Register/update with detected values
    result = manager.register_session(
        session_key=session_key,
        model=model,
        current_tokens=tokens_used
    )
    
    # If warning threshold reached, notify OpenClaw
    if result.get('status') in ['warning', 'high', 'emergency']:
        print(json.dumps({
            "guardian_alert": True,
            "session_key": session_key,
            "status": result['status'],
            "percent": result['percent'],
            "action": result['action'],
            "message": result['message']
        }), file=sys.stderr)
    
    return result

if __name__ == "__main__":
    result = sync_from_environment()
    print(json.dumps(result))