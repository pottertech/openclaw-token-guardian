#!/bin/bash
#
# Hook: Called by OpenClaw when model changes
# Installation: Add to OpenClaw config under hooks.modelSwitch
#
# Usage: on-model-switch.sh <session_key> <old_model> <new_model>

SESSION_KEY="${1:-main}"
OLD_MODEL="$2"
NEW_MODEL="$3"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN_GUARDIAN="$SCRIPT_DIR/../token-guardian.py"

echo "[Token Guardian] Model switch detected"
echo "  Session: $SESSION_KEY"
echo "  Old: $OLD_MODEL"
echo "  New: $NEW_MODEL"

# Update guardian with new model
python3 "$TOKEN_GUARDIAN" switch "$SESSION_KEY" "$NEW_MODEL"

# Log the switch
cat >> "$HOME/.openclaw/workspace/memory/model-switches.log" << EOF
[$(date -Iseconds)] Model switched in $SESSION_KEY
  Old: $OLD_MODEL
  New: $NEW_MODEL
EOF

echo "[Token Guardian] Model switch recorded"
