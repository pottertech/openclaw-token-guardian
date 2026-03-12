#!/bin/bash
# Setup Context Protection Cron Jobs
# Run once to install hourly guardian + weekly compaction

echo "🦀 Installing Context Protection Cron Jobs..."
echo "=================================="

WORKSPACE="$HOME/.openclaw/workspace"

# Ensure scripts exist and are executable
if [ ! -f "$WORKSPACE/memory/context-guardian.sh" ]; then
    echo "❌ Error: context-guardian.sh not found"
    exit 1
fi

if [ ! -f "$WORKSPACE/memory/compaction-cron.sh" ]; then
    echo "❌ Error: compaction-cron.sh not found"
    exit 1
fi

# Make sure they're executable
chmod +x "$WORKSPACE/memory/context-guardian.sh"
chmod +x "$WORKSPACE/memory/compaction-cron.sh"

# Create logs directory if needed
mkdir -p "$WORKSPACE/logs"

# Get current crontab (or empty if none)
crontab -l > /tmp/crontab-current.txt 2>/dev/null || echo "# No existing crontab" > /tmp/crontab-current.txt

# Check if already installed
if grep -q "context-guardian.sh" /tmp/crontab-current.txt; then
    echo "⚠️ Guardian already in crontab. Skipping..."
else
    echo "➕ Adding hourly guardian..."
    cat >> /tmp/crontab-current.txt << EOF

# OpenClaw Context Protection — 2026-03-09
# Hourly guardian: Check for bloat warnings
0 * * * * $WORKSPACE/memory/context-guardian.sh >> $WORKSPACE/logs/guardian.log 2>&1
EOF
fi

if grep -q "compaction-cron.sh" /tmp/crontab-current.txt; then
    echo "⚠️ Compaction already in crontab. Skipping..."
else
    echo "➕ Adding weekly compaction..."
    cat >> /tmp/crontab-current.txt << EOF
# Weekly compaction: Archive old daily notes (Sundays 2 AM)
0 2 * * 0 $WORKSPACE/memory/compaction-cron.sh >> $WORKSPACE/logs/compaction.log 2>&1
EOF
fi

# Install new crontab
crontab /tmp/crontab-current.txt

# Verify
echo ""
echo "✅ Cron jobs installed:"
crontab -l | tail -5

echo ""
echo "=================================="
echo "🎉 Context Protection is ACTIVE!"
echo ""
echo "Hourly: Guardian checks for bloat"
echo "Weekly: Auto-archive old content"
echo ""
echo "Logs: $WORKSPACE/logs/"
