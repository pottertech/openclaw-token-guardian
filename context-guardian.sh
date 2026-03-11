#!/bin/bash
# Context Guardian — prevents memory bloat
# Run daily or at session start

WORKSPACE="/Users/skipppotter/.openclaw/workspace"
MEMORY_LINES=$(wc -l < "$WORKSPACE/MEMORY.md" 2>/dev/null || echo 0)
WARNINGS=0

echo "🧹 Context Guardian Check — $(date)"
echo "=================================="

# Check MEMORY.md bloat
if [ $MEMORY_LINES -gt 800 ]; then
    echo "⚠️ WARNING: MEMORY.md is $MEMORY_LINES lines. Run compaction."
    WARNINGS=$((WARNINGS + 1))
else
    echo "✅ MEMORY.md: $MEMORY_LINES lines (healthy)"
fi

# Check SESSION-STATE staleness (older than 14 days)
if [ -f "$WORKSPACE/SESSION-STATE.md" ]; then
    LAST_UPDATE=$(grep -o "Updated:.*EST\|Updated:.*EDT" "$WORKSPACE/SESSION-STATE.md" | head -1)
    if echo "$LAST_UPDATE" | grep -q "2026-02-19\|2026-02-2[0-9]"; then
        echo "⚠️ SESSION-STATE.md is stale (February). Needs refresh."
        WARNINGS=$((WARNINGS + 1))
    else
        echo "✅ SESSION-STATE.md: $LAST_UPDATE"
    fi
fi

# Check working buffer size
if [ -f "$WORKSPACE/memory/working-buffer.md" ]; then
    BUFFER_LINES=$(wc -l < "$WORKSPACE/memory/working-buffer.md")
    if [ $BUFFER_LINES -gt 500 ]; then
        echo "⚠️ working-buffer.md is $BUFFER_LINES lines. Extract and clear."
        WARNINGS=$((WARNINGS + 1))
    else
        echo "✅ working-buffer.md: $BUFFER_LINES lines (healthy)"
    fi
fi

# Check daily notes count
DAILY_COUNT=$(find "$WORKSPACE/memory/" -name "2026-*.md" -type f 2>/dev/null | wc -l)
if [ $DAILY_COUNT -gt 30 ]; then
    echo "⚠️ $DAILY_COUNT daily notes. Archive old ones (>7 days)."
    WARNINGS=$((WARNINGS + 1))
else
    echo "✅ Daily notes: $DAILY_COUNT files (healthy)"
fi

# Summary
echo "=================================="
if [ $WARNINGS -eq 0 ]; then
    echo "✅ All systems healthy!"
    exit 0
else
    echo "⚠️ $WARNINGS warning(s) found. Run cleanup."
    exit 1
fi
