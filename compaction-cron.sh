#!/bin/bash
# Daily Compaction — Archive old content and compact MEMORY.md
# NOW WITH MODEL-AWARE THRESHOLDS

WORKSPACE="$HOME/.openclaw/workspace"
DATE=$(date +%Y-%m-%d)
ARCHIVE_DIR="$WORKSPACE/memory/archive"
mkdir -p "$ARCHIVE_DIR"

# Model context limits (in tokens)
QWEN_7B=32000
QWEN_14B=32000
QWEN_72B=32000
LLAMA3=8192
LLAMA31=128000
MISTRAL=8192
MINIMAX_CLOUD=205000
MINIMAX=32000
GEMMA2=8192
PHI3=4096
DEFAULT_LIMIT=32000
WARNING_PCT=60

echo "🗜️ Memory Compaction — $DATE"
echo "=================================="

# 1. Detect current model
CURRENT_MODEL="unknown"
if [ -f "$WORKSPACE/.current_model" ]; then
    CURRENT_MODEL=$(cat "$WORKSPACE/.current_model")
fi

case "$CURRENT_MODEL" in
    *"qwen2.5"*"7b"*|*qwen_7b*) MODEL_LIMIT=$QWEN_7B ;;
    *"qwen2.5"*"14b"*|*qwen_14b*) MODEL_LIMIT=$QWEN_14B ;;
    *"qwen2.5"*"72b"*|*qwen_72b*) MODEL_LIMIT=$QWEN_72B ;;
    *"llama3.1"*) MODEL_LIMIT=$LLAMA31 ;;
    *"llama3"*) MODEL_LIMIT=$LLAMA3 ;;
    *"mistral"*) MODEL_LIMIT=$MISTRAL ;;
    *"minimax"*"cloud"*|*minimax_cloud*) MODEL_LIMIT=$MINIMAX_CLOUD ;;
    *"minimax"*) MODEL_LIMIT=$MINIMAX ;;
    *"gemma2"*) MODEL_LIMIT=$GEMMA2 ;;
    *"phi3"*) MODEL_LIMIT=$PHI3 ;;
    *) MODEL_LIMIT=$DEFAULT_LIMIT ;;
esac

echo "🤖 Model: $CURRENT_MODEL | Context limit: ${MODEL_LIMIT}t"

# 2. Check session context
SESSION_FILE="$WORKSPACE/.session_tokens"
if [ -f "$SESSION_FILE" ]; then
    TOKENS_IN=$(grep "in:" "$SESSION_FILE" | awk '{print $2}')
    TOKENS_OUT=$(grep "out:" "$SESSION_FILE" | awk '{print $2}')
    TOTAL_TOKENS=$((TOKENS_IN + TOKENS_OUT))
    WARNING_THRESHOLD=$((MODEL_LIMIT * WARNING_PCT / 100))
    
    if [ -n "$TOTAL_TOKENS" ] && [ $TOTAL_TOKENS -gt 0 ] 2>/dev/null; then
        if [ $TOTAL_TOKENS -gt $WARNING_THRESHOLD ]; then
            echo "⚠️  Session at $TOTAL_TOKENS/${MODEL_LIMIT}t — Consider /reset"
        else
            echo "✅ Session at $TOTAL_TOKENS/${MODEL_LIMIT}t (healthy)"
        fi
    fi
fi

# 3. Archive old daily notes (>7 days)
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

# 4. Compact MEMORY.md if >800 lines
LINES=$(wc -l < "$WORKSPACE/MEMORY.md")
if [ $LINES -gt 800 ]; then
    echo "📦 MEMORY.md is $LINES lines. Auto-compacting..."
    
    # Archive full version
    cp "$WORKSPACE/MEMORY.md" "$ARCHIVE_DIR/memory-full-$DATE.md"
    
    # Create minimal version with critical sections only
    {
        echo "# MEMORY.md - Critical Information Only"
        echo "*Compacted $DATE from $LINES lines*"
        echo ""
        grep -E "^## ⛔|^## 🔐|^## 🔒|^###.*CRITICAL|^###.*PERMANENT|^###.*REMEMBER" "$ARCHIVE_DIR/memory-full-$DATE.md" 2>/dev/null || true
    } > "$WORKSPACE/MEMORY.md"
    
    NEW_LINES=$(wc -l < "$WORKSPACE/MEMORY.md")
    echo "✅ MEMORY.md compacted to $NEW_LINES lines"
fi

# 5. Auto-refresh SESSION-STATE.md if stale (>14 days)
if [ -f "$WORKSPACE/SESSION-STATE.md" ]; then
    LAST_UPDATE=$(stat -f %m "$WORKSPACE/SESSION-STATE.md" 2>/dev/null || stat -c %Y "$WORKSPACE/SESSION-STATE.md" 2>/dev/null || echo 0)
    DAYS_SINCE=$(( ($(date +%s) - LAST_UPDATE) / 86400 ))
    if [ $DAYS_SINCE -gt 14 ]; then
        echo "📝 Refreshing stale SESSION-STATE.md ($DAYS_SINCE days)..."
        {
            echo "# SESSION-STATE.md — Refreshed $DATE"
            echo ""
            echo "**Last refresh:** $DATE"
            echo "**Context:** Auto-refreshed by compaction"
        } > "$WORKSPACE/SESSION-STATE.md"
    else
        echo "✅ SESSION-STATE.md: Fresh ($DAYS_SINCE days old)"
    fi
fi

# 6. Auto-extract working-buffer if >100 lines
if [ -f "$WORKSPACE/memory/working-buffer.md" ]; then
    BUFFER_LINES=$(wc -l < "$WORKSPACE/memory/working-buffer.md")
    if [ $BUFFER_LINES -gt 100 ]; then
        echo "📝 Extracting working-buffer.md ($BUFFER_LINES lines)..."
        cat "$WORKSPACE/memory/working-buffer.md" >> "$WORKSPACE/SESSION-STATE.md"
        echo "# Buffer cleared $DATE" > "$WORKSPACE/memory/working-buffer.md"
    else
        echo "✅ working-buffer.md: $BUFFER_LINES lines (healthy)"
    fi
fi

echo "✅ Compaction complete — $(date +%H:%M)"