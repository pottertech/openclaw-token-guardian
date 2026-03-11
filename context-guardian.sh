#!/bin/bash
# Context Guardian — prevents memory bloat with MODEL-AWARE thresholds
# Run daily or at session start

WORKSPACE="$HOME/.openclaw/workspace"

# Model context limits (in tokens)
# Using simple variable names (colons cause issues in bash arrays on macOS)
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

# Default limits if model not found
DEFAULT_LIMIT=32000
WARNING_PCT=60
DANGER_PCT=80

echo "🧹 Context Guardian Check — $(date)"
echo "=================================="

# 1. Detect current model
CURRENT_MODEL="unknown"
MODEL_FILE="$WORKSPACE/.current_model"
if [ -f "$MODEL_FILE" ]; then
    CURRENT_MODEL=$(cat "$MODEL_FILE")
elif [ -f "$WORKSPACE/AGENTS.md" ]; then
    CURRENT_MODEL=$(grep "model=" "$WORKSPACE/AGENTS.md" | head -1 | sed 's/.*model=//' | sed 's/|.*//' | tr -d ' ')
fi

# Get model limit
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

WARNING_THRESHOLD=$((MODEL_LIMIT * WARNING_PCT / 100))
DANGER_THRESHOLD=$((MODEL_LIMIT * DANGER_PCT / 100))

echo "🤖 Model: $CURRENT_MODEL (limit: ${MODEL_LIMIT}t)"
echo "⚠️  Warning at: ${WARNING_THRESHOLD}t | 🔴 Danger at: ${DANGER_THRESHOLD}t"

# 2. Check current session context (if available)
SESSION_FILE="$WORKSPACE/.session_tokens"
if [ -f "$SESSION_FILE" ]; then
    TOKENS_IN=$(grep "in:" "$SESSION_FILE" | awk '{print $2}')
    TOKENS_OUT=$(grep "out:" "$SESSION_FILE" | awk '{print $2}')
    TOTAL_TOKENS=$((TOKENS_IN + TOKENS_OUT))
    
    if [ -n "$TOTAL_TOKENS" ] && [ $TOTAL_TOKENS -gt 0 ] 2>/dev/null; then
        if [ $TOTAL_TOKENS -gt $DANGER_THRESHOLD ]; then
            echo "🔴 DANGER: $TOTAL_TOKENS tokens (>$DANGER_PCT% of limit)"
        elif [ $TOTAL_TOKENS -gt $WARNING_THRESHOLD ]; then
            echo "⚠️  WARNING: $TOTAL_TOKENS tokens (>$WARNING_PCT% of limit)"
        else
            echo "✅ Context: $TOTAL_TOKENS / ${MODEL_LIMIT}t (healthy)"
        fi
    fi
fi

# 3. Check MEMORY.md bloat
MEMORY_LINES=$(wc -l < "$WORKSPACE/MEMORY.md" 2>/dev/null || echo 0)
if [ $MEMORY_LINES -gt 800 ]; then
    echo "⚠️  WARNING: MEMORY.md is $MEMORY_LINES lines. Run compaction."
else
    echo "✅ MEMORY.md: $MEMORY_LINES lines (healthy)"
fi

# 4. Check SESSION-STATE staleness
if [ -f "$WORKSPACE/SESSION-STATE.md" ]; then
    LAST_UPDATE=$(stat -f %m "$WORKSPACE/SESSION-STATE.md" 2>/dev/null || stat -c %Y "$WORKSPACE/SESSION-STATE.md" 2>/dev/null || echo 0)
    DAYS_SINCE=$(( ($(date +%s) - LAST_UPDATE) / 86400 ))
    if [ $DAYS_SINCE -gt 14 ]; then
        echo "⚠️  SESSION-STATE.md is stale ($DAYS_SINCE days old). Needs refresh."
    else
        echo "✅ SESSION-STATE.md: Fresh ($DAYS_SINCE days old)"
    fi
fi

# 5. Check working buffer size
if [ -f "$WORKSPACE/memory/working-buffer.md" ]; then
    BUFFER_LINES=$(wc -l < "$WORKSPACE/memory/working-buffer.md")
    if [ $BUFFER_LINES -gt 500 ]; then
        echo "⚠️  working-buffer.md is $BUFFER_LINES lines. Extract and clear."
    else
        echo "✅ working-buffer.md: $BUFFER_LINES lines (healthy)"
    fi
fi

# 6. Check daily notes count
DAILY_COUNT=$(find "$WORKSPACE/memory/" -name "2026-*.md" -type f 2>/dev/null | wc -l)
if [ $DAILY_COUNT -gt 30 ]; then
    echo "⚠️  $DAILY_COUNT daily notes. Archive old ones (>7 days)."
else
    echo "✅ Daily notes: $DAILY_COUNT files (healthy)"
fi

echo "=================================="