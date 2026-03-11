#!/bin/bash
#
# Manual sync script for Token Guardian
# Pulls actual model/token info from OpenClaw and updates guardian state
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN_GUARDIAN="$SCRIPT_DIR/token-guardian.py"

# Get current OpenClaw session info
SESSION_KEY="${OPENCLAW_SESSION_KEY:-main}"
MODEL="${OPENCLAW_MODEL:-ollama/kimi-k2.5}"

# Get token usage from OpenClaw (requires OpenClaw to expose this)
# For now, estimate or use 0
TOKENS_USED="${OPENCLAW_TOKENS_USED:-0}"

echo "Syncing Token Guardian with OpenClaw..."
echo "  Session: $SESSION_KEY"
echo "  Model: $MODEL"
echo "  Tokens: $TOKENS_USED"

# Validate and sync
python3 "$TOKEN_GUARDIAN" sync "$SESSION_KEY" "$MODEL" "$TOKENS_USED"

# Also check all tracked sessions
# python3 "$TOKEN_GUARDIAN" validate "$SESSION_KEY" "$MODEL"

echo "Done."
