#!/bin/bash
# Daily Compaction — Archive old content and compact MEMORY.md
# Run: 0 3 * * * ~/workspace/memory/compaction-cron.sh

WORKSPACE="/Users/skipppotter/.openclaw/workspace"
DATE=$(date +%Y-%m-%d)
ARCHIVE_DIR="$WORKSPACE/memory/archive"
mkdir -p "$ARCHIVE_DIR"

echo "🗜️ Memory Compaction — $DATE"
echo "=================================="

# 1. Archive old daily notes (>7 days)
ARCHIVED_DAILY=0
for file in "$WORKSPACE"/memory/2026-*.md; do
    if [ -f "$file" ]; then
        FILE_AGE=$(( ($(date +%s) - $(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo 0)) / 86400 ))
        if [ $FILE_AGE -gt 7 ]; then
            mv "$file" "$ARCHIVE_DIR/"
            ARCHIVED_DAILY=$((ARCHIVED_DAILY + 1))
        fi
    fi
done

if [ $ARCHIVED_DAILY -gt 0 ]; then
    echo "✅ Archived $ARCHIVED_DAILY old daily notes"
else
    echo "✅ No daily notes to archive"
fi

# 2. Compact MEMORY.md if >800 lines - AUTO CLEAN
LINES=$(wc -l < "$WORKSPACE/MEMORY.md")
if [ $LINES -gt 800 ]; then
    echo "📦 MEMORY.md is $LINES lines. Auto-compacting..."
    
    # Create backup
    cp "$WORKSPACE/MEMORY.md" "$WORKSPACE/MEMORY.md.backup-$DATE"
    
    # Keep only critical sections (lines with ⛔ CRITICAL, ## Key, ## Critical)
    # Extract lines that are marked as important
    grep -E "^(## |### |**.*⛔|##.*⛔|##.*PERMANENT|##.*CRITICAL|##.*Policy)" "$WORKSPACE/MEMORY.md" > "$WORKSPACE/MEMORY.md.compact" 2>/dev/null || true
    
    # If compact is too small, keep original
    COMPACT_LINES=$(wc -l < "$WORKSPACE/MEMORY.md.compact" 2>/dev/null || echo 0)
    if [ $COMPACT_LINES -lt 50 ]; then
        echo "⚠️ Compact too small, keeping original"
        mv "$WORKSPACE/MEMORY.md.backup-$DATE" "$WORKSPACE/MEMORY.md"
    else
        # Archive full version
        mv "$WORKSPACE/MEMORY.md" "$ARCHIVE_DIR/memory-full-$DATE.md"
        mv "$WORKSPACE/MEMORY.md.compact" "$WORKSPACE/MEMORY.md"
        echo "✅ MEMORY.md compacted to ~$COMPACT_LINES lines"
    fi
fi

# 3. Auto-refresh SESSION-STATE.md if stale (>14 days)
if [ -f "$WORKSPACE/SESSION-STATE.md" ]; then
    LAST_UPDATE=$(stat -f %m "$WORKSPACE/SESSION-STATE.md" 2>/dev/null || stat -c %Y "$WORKSPACE/SESSION-STATE.md" 2>/dev/null || echo 0)
    DAYS_SINCE=$(( ($(date +%s) - LAST_UPDATE) / 86400 ))
    if [ $DAYS_SINCE -gt 14 ]; then
        echo "📝 SESSION-STATE.md is $DAYS_SINCE days old. Refreshing..."
        echo "# SESSION-STATE.md — Refreshed $DATE" > "$WORKSPACE/SESSION-STATE.md"
        echo "" >> "$WORKSPACE/SESSION-STATE.md"
        echo "**Last refresh:** $DATE" >> "$WORKSPACE/SESSION-STATE.md"  
        echo "**Context:** Fresh session after compaction" >> "$WORKSPACE/SESSION-STATE.md"
    else
        echo "✅ SESSION-STATE.md is fresh ($DAYS_SINCE days old)"
    fi
fi

# 4. Auto-extract working-buffer if >100 lines
if [ -f "$WORKSPACE/memory/working-buffer.md" ]; then
    BUFFER_LINES=$(wc -l < "$WORKSPACE/memory/working-buffer.md")
    if [ $BUFFER_LINES -gt 100 ]; then
        echo "📝 Extracting working-buffer.md ($BUFFER_LINES lines)..."
        # Archive to SESSION-STATE
        cat "$WORKSPACE/memory/working-buffer.md" >> "$WORKSPACE/SESSION-STATE.md"
        # Clear buffer
        echo "# Working Buffer — Cleared $DATE" > "$WORKSPACE/memory/working-buffer.md"
    else
        echo "✅ working-buffer.md: $BUFFER_LINES lines (healthy)"
    fi
fi

# 5. Log completion
echo "" >> "$WORKSPACE/memory/compaction.log"
echo "[$DATE] Compaction complete — $(date +%H:%M)" >> "$WORKSPACE/memory/compaction.log"
echo "✅ Compaction finished — $(date +%H:%M)"
