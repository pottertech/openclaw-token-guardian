#!/usr/bin/env python3
"""
Runtime sync with OpenClaw
Polls OpenClaw session status and updates token guardian
"""

import json
import sys
import subprocess
from pathlib import Path

# Add parent dir
sys.path.insert(0, str(Path(__file__).parent))
from token_guardian import TokenGuardianManager

def get_openclaw_status():
    """Get current session info from OpenClaw."""
    try:
        result = subprocess.run(
            ['openclaw', 'status', '--json'],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            return json.loads(result.stdout)
    except (subprocess.TimeoutExpired, json.JSONDecodeError, FileNotFoundError):
        pass
    return None

def get_session_info(session_key='main'):
    """Get session-specific info."""
    status = get_openclaw_status()
    if not status:
        return None
    
    return {
        'session_key': session_key,
        'model': status.get('model', 'ollama/kimi-k2.5'),
        'runtime': status.get('runtime', 'unknown'),
        'tokens_used': status.get('sessionTokens', 0),  # If OpenClaw exposes this
    }

def sync_guardian():
    """Main sync loop."""
    info = get_session_info()
    if not info:
        print(json.dumps({"status": "error", "reason": "openclaw_not_available"}))
        return
    
    manager = TokenGuardianManager()
    result = manager.register_session(
        session_key=info['session_key'],
        model=info['model'],
        current_tokens=info.get('tokens_used', 0)
    )
    
    # Add runtime info
    result['runtime'] = info['runtime']
    result['sync_source'] = 'openclaw_api'
    
    print(json.dumps(result, indent=2))
    
    # Return exit code based on status
    if result.get('status') == 'emergency':
        return 2
    elif result.get('status') in ['warning', 'high']:
        return 1
    return 0

if __name__ == '__main__':
    sys.exit(sync_guardian())
