#!/usr/bin/env python3
"""
Token Guardian - Standalone Wrapper
Adds 'check-main' command for cron usage
"""

# ... existing code ...

def check_main():
    """Check main session - designed for cron usage."""
    import os
    
    # Get session from environment or default
    session_key = os.environ.get('OPENCLAW_SESSION_KEY', 'main')
    model = os.environ.get('OPENCLAW_MODEL', 'ollama/kimi-k2.5')
    
    # Estimate tokens from message history length
    # (Simplified - in real use would query OpenClaw)
    tokens_used = 0  # Will be updated on actual use
    
    manager = TokenGuardianManager()
    result = manager.register_session(session_key, model, tokens_used)
    
    # Log if at threshold
    if result.get('status') in ['high', 'emergency']:
        print(f"[{datetime.now().isoformat()}] ALERT: {result['message']}")
        if result.get('auto_executed'):
            print(f"  Auto-action: {result.get('execution_result', {})}")
    
    return result

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == 'check-main':
        result = check_main()
        print(json.dumps(result, indent=2))
    else:
        main()
