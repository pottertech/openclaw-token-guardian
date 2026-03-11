#!/bin/bash
#
# Detect current model from OpenClaw runtime
# Usage: get-current-model.sh [session_key]

SESSION_KEY="${1:-main}"

# Try to get model from OpenClaw status
# Note: This requires OpenClaw to expose model in status output
MODEL=$(openclaw status --json 2>/dev/null | jq -r '.model // "ollama/kimi-k2.5"')

# Fallback to environment or default
if [ -z "$MODEL" ] || [ "$MODEL" = "null" ]; then
    MODEL="${OPENCLAW_MODEL:-ollama/kimi-k2.5}"
fi

echo "$MODEL"
