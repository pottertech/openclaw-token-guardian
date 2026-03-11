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
git clone https://github.com/pottertech/openclaw-memory-utilities.git
cd openclaw-memory-utilities

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
