# OpenClaw Token Guardian

Scripts for managing OpenClaw workspace memory and preventing context bloat.

## Contents

| Script | Purpose |
|--------|---------|
| `compaction-cron.sh` | Daily memory cleanup — archives old notes, compacts MEMORY.md |
| `context-guardian.sh` | Check for memory bloat and warn |
| `setup-cron.sh` | Install cron jobs automatically |

## Quick Setup

```bash
# Clone or download
git clone https://github.com/pottertech/openclaw-token-guardian.git
cd openclaw-token-guardian

# Run setup to install cron jobs
./setup-cron.sh
```

## What Each Script Does

### compaction-cron.sh
- Archives daily notes older than 7 days
- Compacts MEMORY.md if >800 lines
- Auto-refreshes SESSION-STATE.md if stale (>14 days)
- Extracts working-buffer.md if >100 lines

### context-guardian.sh
- Checks MEMORY.md line count
- Checks SESSION-STATE.md freshness
- Checks working-buffer.md size
- Checks daily notes count

### setup-cron.sh
- Installs cron jobs for compaction and guardian
- Configures daily (3 AM) and weekly schedules

## Cron Schedule

| Job | Schedule | Action |
|-----|----------|--------|
| Compaction | Daily 3 AM | Auto-clean memory |
| Guardian | Daily 8 AM | Check for bloat |

## Requirements

- OpenClaw workspace at `~/.openclaw/workspace/`
- Standard macOS/Unix tools (bash, cron, stat)
- Write access to workspace directory

## For OpenClaw Users

Add to your workspace:
```bash
mkdir -p ~/.openclaw/workspace/memory
cp *.sh ~/.openclaw/workspace/memory/
./setup-cron.sh
```

## License

MIT — Feel free to use and modify!

---

## 🆕 Token Guardian (Context Overflow Prevention)

**NEW:** Token-aware context management prevents "prompt too large" errors.

### Features
- Tracks actual token usage per session
- Auto-detects model switches and recalculates thresholds
- Handles sub-agents with fresh context
- Warns at 75%, acts at 85%, emergency at 95%
- Integrates with OpenClaw hooks

### Installation

```bash
# Install Token Guardian hooks
./install-hooks.sh
```

Or manually:
```bash
openclaw config patch < openclaw-hooks-config.yaml
```

### Usage

```bash
# Check current session
python3 token-guardian.py check <session> <model> <tokens>

# View all sessions
python3 token-guardian.py status

# Sync with OpenClaw runtime
python3 runtime-sync.py
```

### Files
| File | Purpose |
|------|---------|
| `token-guardian.py` | Core tracking with auto-validation |
| `runtime-sync.py` | Poll OpenClaw for current state |
| `hooks/guardian_sync.py` | Pre/post message hook |
| `hooks/on-model-switch.sh` | Model change handler |
| `openclaw-hooks-config.yaml` | Gateway config patch |
| `install-hooks.sh` | One-click installer |

### Model Context Limits
| Model | Tokens |
|-------|--------|
| ollama/kimi-k2.5:cloud | 262,144 |
| ollama/minimax-m2.5:cloud | 198,000 |
| ollama/deepseek-v3.2:cloud | 131,072 |
| ollama/mistral-large-3:675b-cloud | 131,072 |
| ollama/qwen3.5:397b-cloud | 32,768 |
| claude-3-5-sonnet | 200,000 |
| gpt-4-turbo | 128,000 |

---

*Token Guardian — Preventing context overflow since 2026*
