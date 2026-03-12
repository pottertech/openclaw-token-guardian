# Token Guardian v1.0.0 - Usage Guide

**Context overflow prevention for OpenClaw**

---

## Quick Start

```bash
# Check current status
tg-check

# Check specific session
python3 token-guardian.py check my-session ollama/kimi-k2.5:cloud 6400

# View all sessions
python3 token-guardian.py status

# View statistics
python3 token-guardian.py stats
```

---

## Installation

### Option 1: Standalone (Recommended)

```bash
cd ~/.openclaw/workspace/repos/openclaw-token-guardian
./setup-standalone.sh
```

This installs:
- Cron job (checks every 5 minutes)
- `tg-check` command
- Logs to `~/.openclaw/workspace/logs/token-guardian.log`

### Option 2: Manual

```bash
# Make executable
chmod +x token-guardian.py tg-*.sh

# Use directly
python3 token-guardian.py check <session> <model> <tokens>
```

---

## How It Works

### Thresholds

| Usage | Action | Auto-Execute |
|-------|--------|--------------|
| **75%** | ⚡ Warning | Display only |
| **85%** | 🔄 **Auto-Compact** | **YES** (default) |
| **95%** | 🚨 Critical Warning | Manual action required |

### Auto-Compact

When context reaches 85%:
1. Extracts key decisions
2. Saves to pg-memory (or files as fallback)
3. Summarizes conversation
4. Continues with reduced tokens

---

## Commands

### `tg-check`

Quick status check for current session.

```bash
$ tg-check
{
  "session_key": "main",
  "model": "ollama/kimi-k2.5:cloud",
  "percent": 78.1,
  "status": "warning",
  "message": "⚡ WARNING: 78.1% token usage..."
}
```

### `python3 token-guardian.py check <session> <model> <tokens>`

Check specific session with token count.

```bash
# Example: 78% usage
$ python3 token-guardian.py check main ollama/kimi-k2.5:cloud 6400
{
  "status": "warning",
  "percent": 78.1,
  "message": "⚡ WARNING: 78.1% token usage..."
}

# Example: 85% usage → triggers auto-compact
$ python3 token-guardian.py check main ollama/kimi-k2.5:cloud 7000
{
  "status": "high",
  "percent": 85.4,
  "auto_executed": true,
  "message": "⚠️ HIGH: 85.4% token usage. AUTO-COMPACTING..."
}
```

### `python3 token-guardian.py status`

Show all tracked sessions.

```bash
$ python3 token-guardian.py status
{
  "main": {
    "session_key": "main",
    "model": "ollama/kimi-k2.5:cloud",
    "percent": 45.2,
    "status": "ok"
  },
  "discord-session": {
    "session_key": "discord-session",
    "model": "ollama/qwen3.5:397b-cloud",
    "percent": 23.1,
    "status": "ok"
  }
}
```

### `python3 token-guardian.py stats`

Show aggregate statistics.

```bash
$ python3 token-guardian.py stats
{
  "total_sessions": 3,
  "warning_sessions": 1,
  "critical_sessions": 0,
  "healthy_sessions": 2
}
```

---

## Configuration

### Change Thresholds

```bash
# Set warning at 70% (default: 75%)
python3 tg-config.py set-threshold warning 70

# Set action at 80% (default: 85%)
python3 tg-config.py set-threshold action 80

# Set emergency at 90% (default: 95%)
python3 tg-config.py set-threshold emergency 90
```

### Toggle Auto-Action

```bash
# Disable auto-compact
python3 tg-config.py set-auto-action false

# Disable auto-compact at 85% specifically
python3 tg-config.py set-auto-85 false

# Disable notifications
python3 tg-config.py set-notify false
```

### Change Default Compact Option

```bash
# Option 1: Smart Compact (auto-detect pg-memory vs files) [DEFAULT]
tg-set-default.sh 1

# Option 2: Always use pg-memory
tg-set-default.sh 2

# Option 3: Always use files
tg-set-default.sh 3

# Option 4: Just reset (no save)
tg-set-default.sh 4
```

### View Current Config

```bash
python3 tg-config.py show
tg-status.sh
```

---

## Examples

### Example 1: Monitor Long Session

```bash
# Start monitoring
$ tg-check
{
  "session_key": "main",
  "percent": 45.0,
  "status": "ok",
  "message": "✅ Healthy: 45.0% token usage."
}

# After many messages...
$ tg-check
{
  "percent": 78.1,
  "status": "warning",
  "message": "⚡ WARNING: 78.1% token usage..."
}
# → Continue working, but be aware

# Approaching limit...
$ tg-check
{
  "percent": 85.4,
  "status": "high",
  "auto_executed": true,
  "execution_result": {
    "action": "auto_compact",
    "succeeded": true,
    "storage": "files",
    "location": "~/.openclaw/workspace/memory/2026-03-11.md"
  }
}
# → Auto-compacted! Context saved, session continues.
```

### Example 2: Model Switch

```bash
# Before switch (8K model)
$ python3 token-guardian.py check main ollama/kimi-k2.5:cloud 6400
{
  "model": "ollama/kimi-k2.5:cloud",
  "limit": 8192,
  "percent": 78.1
}

# After switching to 32K model
$ python3 token-guardian.py check main ollama/qwen3.5:397b-cloud 6400
{
  "model": "ollama/qwen3.5:397b-cloud",
  "limit": 32768,
  "percent": 19.5,
  "model_sync": {
    "model_mismatch_detected": true,
    "old_percent": 78.1,
    "recalculated_percent": 19.5
  }
}
# → Same tokens, bigger limit = lower percentage
```

### Example 3: Query Saved Context

```bash
# After auto-compact, view saved context
$ cat ~/.openclaw/workspace/memory/2026-03-11.md | grep -A 20 "Context Compaction"
## Context Compaction: main
**Model:** ollama/kimi-k2.5:cloud
**Tokens:** 7000 (85.4%)

```json
{
  "decisions": ["Auto-compacted at 85%"],
  "actions": ["Prevent overflow"]
}
```

# If using pg-memory
$ python3 pg_memory_adapter.py query main
[
  {
    "tags": ["context_snapshot", "main"],
    "content": "{...}"
  }
]
```

### Example 4: Cron Monitoring

```bash
# View cron logs
$ tail -f ~/.openclaw/workspace/logs/token-guardian.log
[2026-03-11T10:00:00] Status: ok (45.0%)
[2026-03-11T10:05:00] Status: ok (52.3%)
[2026-03-11T10:10:00] ALERT: WARNING (78.1%)
[2026-03-11T10:15:00] ALERT: HIGH (85.4%)
  Auto-action: auto_compact succeeded
```

---

## Troubleshooting

### Command Not Found

```bash
# Add to PATH or use full path
export PATH="$HOME/.openclaw/workspace/bin:$PATH"
# Or
~/.openclaw/workspace/bin/tg-check
```

### No pg-memory

```bash
# Falls back to files automatically
# Check fallback worked:
ls ~/.openclaw/workspace/memory/2026-03-11.md
```

### Reset Config

```bash
python3 tg-config.py reset
```

---

## Files

| File | Purpose |
|------|---------|
| `token-guardian.py` | Core tracking |
| `tg-check` | Quick status command |
| `tg-config.py` | Configuration manager |
| `tg-status.sh` | Status display |
| `~/.openclaw/workspace/memory/token-guardian-state.json` | Session state |
| `~/.openclaw/workspace/memory/token-guardian-config.json` | User config |

---

## Support

- **Issues**: Check `~/.openclaw/workspace/logs/token-guardian.log`
- **Config**: `python3 tg-config.py show`
- **Reset**: `python3 tg-config.py reset`

---

**Token Guardian v1.0.0** 🎨