#!/bin/bash
#
# Test script to demonstrate model mismatch detection
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN_GUARDIAN="$SCRIPT_DIR/token-guardian.py"

echo "=== Token Guardian Model Mismatch Test ==="
echo ""

# Step 1: Create session with small model (8K limit)
echo "Step 1: Creating session with kimi-k2.5 (8K limit)..."
python3 "$TOKEN_GUARDIAN" check "test-session" "ollama/kimi-k2.5" 6400
echo ""

# Step 2: Check status - should show 78.1% (warning)
echo "Step 2: Current status (should be ~78%):"
python3 "$TOKEN_GUARDIAN" status | jq '.["test-session"] | {model, percent, status}'
echo ""

# Step 3: User switches to larger model in OpenClaw
# Guardian auto-detects mismatch on next check
echo "Step 3: User switches to qwen3.5 (32K) - guardian auto-detects:"
python3 "$TOKEN_GUARDIAN" check "test-session" "ollama/qwen3.5:397b-cloud" 6400 | jq '. | {model_sync, percent, status}'
echo ""

# Step 4: Verify corrected percentage
echo "Step 4: Status after sync (should be ~20%):"
python3 "$TOKEN_GUARDIAN" status | jq '.["test-session"] | {model, percent, status}'
echo ""

# Step 5: Show the reverse - switching to smaller model
echo "Step 5: Switching back to smaller model (should trigger warning):"
python3 "$TOKEN_GUARDIAN" check "test-session" "ollama/kimi-k2.5" 6400 | jq '. | {model_sync, percent, status}'
echo ""

echo "=== Test Complete ==="
echo ""
echo "Key Takeaway:"
echo "  - Guardian auto-detects model mismatches on every check"
echo "  - Recalculates percentage with correct limits"
echo "  - Prevents false warnings (big model) and missed warnings (small model)"

# Cleanup
python3 "$TOKEN_GUARDIAN" cleanup "test-session"