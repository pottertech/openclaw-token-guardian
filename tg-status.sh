#!/bin/bash
#
# Show Token Guardian status without changing defaults
# Quick check: current tokens, thresholds, storage availability
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Token Guardian Status ==="
echo ""

# Show current config
echo "Configuration:"
python3 "$SCRIPT_DIR/tg-config.py" show 2>/dev/null | grep -E "(Default|Threshold|Storage)" | head -6
echo ""

# Check storage availability
echo "Storage Availability:"
if python3 -c "from pg_memory_adapter import PG_MEMORY_AVAILABLE; print('✅' if PG_MEMORY_AVAILABLE else '❌')" 2>/dev/null | grep -q "✅"; then
    echo "  ✅ pg-memory: Available"
else
    echo "  ❌ pg-memory: Not installed"
fi
echo "  ✅ File storage: Always available"
echo ""

# Show current sessions
echo "Tracked Sessions:"
python3 "$SCRIPT_DIR/token-guardian.py" stats 2>/dev/null || echo "  No active sessions"
echo ""

# Show thresholds
echo "Thresholds:"
echo "  ⚡ Warning:  Show options at 75%"
echo "  ⚠️ Action:   Suggest compact at 85%"
echo "  🚨 Emergency: Urgent action at 95%"
echo ""

echo "Quick Actions:"
echo "  tg-set-default.sh 1    # Use Smart Compact"
echo "  tg-set-default.sh 2    # Use pg-memory"
echo "  tg-set-default.sh 3    # Use Files"
echo "  tg-config.py show      # Full config"
