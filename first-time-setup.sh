#!/bin/bash
#
# First-time Token Guardian setup
# Detects current OpenClaw model and initializes tracking
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN_GUARDIAN="$SCRIPT_DIR/token-guardian.py"

echo "=== Token Guardian First-Time Setup ==="
echo ""

# Detect current model from OpenClaw
MODEL=""
SESSION_KEY="${OPENCLAW_SESSION_KEY:-main}"

# Method 1: Environment variable
if [ -n "$OPENCLAW_MODEL" ]; then
    MODEL="$OPENCLAW_MODEL"
    echo "✓ Found model in environment: $MODEL"
fi

# Method 2: Query OpenClaw status
if [ -z "$MODEL" ] && command -v openclaw >/dev/null 2>&1; then
    echo "Detecting model from OpenClaw..."
    MODEL=$(openclaw status --json 2>/dev/null | jq -r '.model // empty')
    if [ -n "$MODEL" ]; then
        echo "✓ Found model from OpenClaw status: $MODEL"
    fi
fi

# Method 3: Read from config
if [ -z "$MODEL" ]; then
    CONFIG_FILE="$HOME/.openclaw/config.yaml"
    if [ -f "$CONFIG_FILE" ]; then
        # Extract model from YAML
        MODEL=$(grep -E '^model:' "$CONFIG_FILE" | head -1 | sed 's/^model: *//' | tr -d '"')
        if [ -n "$MODEL" ]; then
            echo "✓ Found model from config: $MODEL"
        fi
    fi
fi

# Method 4: Default fallback
if [ -z "$MODEL" ]; then
    MODEL="ollama/kimi-k2.5"
    echo "⚠ Using default model: $MODEL"
    echo "  (Run after OpenClaw is connected to auto-detect)"
fi

echo ""
echo "Initializing Token Guardian..."
echo "  Session: $SESSION_KEY"
echo "  Model: $MODEL"

# Initialize guardian with detected model
python3 "$TOKEN_GUARDIAN" check "$SESSION_KEY" "$MODEL" 0

echo ""
echo "✅ Token Guardian initialized!"
echo ""
echo "Current status:"
python3 "$TOKEN_GUARDIAN" status | jq '.["'"$SESSION_KEY"'"] | {model, percent, status}'
echo ""
echo "Model will auto-update on:"
echo "  - Next message sent"
echo "  - Model switch (/model command)"
echo "  - Manual sync: python3 $TOKEN_GUARDIAN sync $SESSION_KEY $MODEL 0"
