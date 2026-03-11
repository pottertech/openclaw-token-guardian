#!/bin/bash
#
# Token Guardian - Basic Usage Examples
#

echo "=== Token Guardian Basic Examples ==="
echo ""

# Example 1: Check current session
echo "1. Check current session:"
tg-check
echo ""

# Example 2: Check specific session with tokens
echo "2. Check specific session (78%):"
python3 token-guardian.py check main ollama/kimi-k2.5:cloud 6400
echo ""

# Example 3: Check at 85% (triggers auto-compact)
echo "3. Check at 85% (auto-compact):"
python3 token-guardian.py check main ollama/kimi-k2.5:cloud 7000
echo ""

# Example 4: View all sessions
echo "4. View all sessions:"
python3 token-guardian.py status
echo ""

# Example 5: View statistics
echo "5. View statistics:"
python3 token-guardian.py stats
echo ""

echo "=== Examples Complete ==="