#!/bin/bash
#
# Hook: Called by OpenClaw when session ends
# Cleans up token guardian state for completed sessions
#

SESSION_KEY="${1:-main}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN_GUARDIAN="$SCRIPT_DIR/../token-guardian.py"

# Remove session from guardian tracking
python3 "$TOKEN_GUARDIAN" cleanup "$SESSION_KEY"

echo "[Token Guardian] Cleaned up session: $SESSION_KEY"
