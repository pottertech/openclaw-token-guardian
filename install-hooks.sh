#!/bin/bash
#
# Install Token Guardian hooks into OpenClaw
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$HOME/.openclaw/config.yaml"

echo "=== Token Guardian Hook Installation ==="
echo ""

# Check if OpenClaw is installed
if ! command -v openclaw &> /dev/null; then
    echo "Error: openclaw not found in PATH"
    echo "Please install OpenClaw first"
    exit 1
fi

# Make hooks executable
echo "Making hooks executable..."
chmod +x "$SCRIPT_DIR/hooks"/*.sh "$SCRIPT_DIR/hooks"/*.py 2>/dev/null || true
chmod +x "$SCRIPT_DIR"/*.py "$SCRIPT_DIR"/*.sh 2>/dev/null || true

# Backup existing config
if [ -f "$CONFIG_FILE" ]; then
    BACKUP="$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    echo "Backing up existing config to: $BACKUP"
    cp "$CONFIG_FILE" "$BACKUP"
fi

# Apply config patch
echo "Applying OpenClaw hooks config..."
if openclaw config patch < "$SCRIPT_DIR/openclaw-hooks-config.yaml"; then
    echo "Config updated successfully"
else
    echo "Error: Failed to apply config patch"
    echo "Manual installation required - see README.md"
    exit 1
fi

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Token Guardian is now active:"
echo "  - Syncs on every message"
echo "  - Handles model switches automatically"
echo "  - Tracks sub-agents separately"
echo ""
echo "Test it:"
echo "  openclaw config get gateway.hooks"
echo ""
echo "View status:"
echo "  python3 $SCRIPT_DIR/token-guardian.py stats"
