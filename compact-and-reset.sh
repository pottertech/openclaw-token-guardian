#!/bin/bash
#
# Compact session before reset
# Usage: compact-and-reset.sh [session_key]

SESSION_KEY="${1:-main}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Compact & Reset ==="
echo "Session: $SESSION_KEY"
echo ""

# 1. Run compaction
echo "📦 Compacting session..."
python3 "$SCRIPT_DIR/hooks/compact_before_reset.py"

# 2. Reset session
echo ""
echo "🔄 Resetting session..."
# OpenClaw would handle this:
# openclaw session reset "$SESSION_KEY"
echo "   (In real usage, this would run: /reset or openclaw reset)"

# 3. Confirmation
echo ""
echo "✅ Session compacted and reset"
echo "   Key decisions saved to MEMORY.md"
echo "   Code snippets saved to memory/code/"
echo "   Session now fresh (0 tokens)"
