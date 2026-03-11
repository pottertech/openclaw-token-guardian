#!/bin/bash
#
# Set default compact option for Token Guardian
# Usage: tg-set-default.sh <1-5>
#   1 = Smart Compact (auto-detect)
#   2 = pg-memory only
#   3 = Files only
#   4 = Just Reset (no save)
#   5 = Show Status

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -lt 1 ]; then
    echo "Usage: tg-set-default.sh <1-5>"
    echo ""
    echo "Options:"
    echo "  1 = Smart Compact (auto-detect) [DEFAULT]"
    echo "  2 = pg-memory only"
    echo "  3 = Files only"
    echo "  4 = Just Reset (no save)"
    echo "  5 = Show Status"
    echo ""
    echo "Current:"
    python3 "$SCRIPT_DIR/tg-config.py" show 2>/dev/null | grep "Default Compact" || echo "  (not configured)"
    exit 1
fi

python3 "$SCRIPT_DIR/tg-config.py" set-default "$1"
