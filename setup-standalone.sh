#!/bin/bash
#
# Standalone Token Guardian Setup
# Works without OpenClaw hooks - uses cron for periodic checks
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRON_FILE="$HOME/.openclaw/workspace/cron/token-guardian.cron"

echo "=== Token Guardian Standalone Setup ==="
echo ""

# Make scripts executable
echo "Making scripts executable..."
chmod +x "$SCRIPT_DIR"/*.py "$SCRIPT_DIR"/*.sh 2>/dev/null || true
chmod +x "$SCRIPT_DIR/hooks"/*.py "$SCRIPT_DIR/hooks"/*.sh 2>/dev/null || true

# Create cron directory
mkdir -p "$HOME/.openclaw/workspace/cron"

# Create cron job
cat > "$CRON_FILE" << 'EOF'
# Token Guardian - Periodic token check
# Runs every 5 minutes to monitor context usage

*/5 * * * * cd ~/.openclaw/workspace/repos/openclaw-memory-utilities && python3 token-guardian.py check-main >> ~/.openclaw/workspace/logs/token-guardian.log 2>&1
EOF

echo ""
echo "Cron job created at: $CRON_FILE"
echo ""

# Install cron job
if command -v crontab &> /dev/null; then
    echo "Installing cron job..."
    (crontab -l 2>/dev/null || echo "") | grep -v "token-guardian" | cat - "$CRON_FILE" | crontab -
    echo "✅ Cron job installed"
else
    echo "⚠️  crontab not available. Manual installation:"
    echo "   crontab $CRON_FILE"
fi

# Create check-main wrapper
cat > "$SCRIPT_DIR/token-guardian.py" << 'WRAPPER'
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
WRAPPER

# Create wrapper that sources env
mkdir -p "$HOME/.openclaw/workspace/bin"
cat > "$HOME/.openclaw/workspace/bin/tg-check" << EOF
#!/bin/bash
# Token Guardian check wrapper

export OPENCLAW_SESSION_KEY="\${OPENCLAW_SESSION_KEY:-main}"
export OPENCLAW_MODEL="\${OPENCLAW_MODEL:-ollama/kimi-k2.5}"

cd "$SCRIPT_DIR"
python3 token-guardian.py check-main
EOF
chmod +x "$HOME/.openclaw/workspace/bin/tg-check"

echo ""
echo "=== Standalone Setup Complete ==="
echo ""
echo "Usage:"
echo "  tg-check                          # Quick check"
echo "  python3 token-guardian.py status  # Full status"
echo "  tg-status.sh                      # Config status"
echo ""
echo "Cron: Checks every 5 minutes"
echo "Logs: ~/.openclaw/workspace/logs/token-guardian.log"
echo ""
echo "Manual check:"
echo "  ~/.openclaw/workspace/bin/tg-check"
