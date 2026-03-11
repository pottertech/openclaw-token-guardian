# Compact Options for Token Guardian

## When Context Reaches 85%

The guardian will show these options:

```
⚡ Context at 85% (6,800/8,000 tokens)

Compact Options:

1. 💾 Smart Compact (Recommended) [DEFAULT]
   → Tries pg-memory first, falls back to files
   → Best option: structured if available, simple if not

2. 🗄️ Compact to pg-memory
   → Requires: pg-memory installed
   → Benefits: SQL queries, cross-session search, structured storage
   → Storage: PostgreSQL observations table

3. 📄 Compact to Files  
   → Always available
   → Location: MEMORY.md + memory/YYYY-MM-DD.md
   → Format: Markdown with JSON summary

4. 🔄 Just Reset
   → ⚠️ WARNING: No save - context lost forever
   → Use only if you're done and don't need history

5. 📊 Show Status
   → See current token breakdown
   → View recent messages summary
   → Then decide

Recommendation: Press Enter for #1 (Smart Compact)
```

## Storage Comparison

| Feature | pg-memory | Files | Just Reset |
|---------|-----------|-------|------------|
| **Survives reset** | ✅ Yes | ✅ Yes | ❌ No |
| **Query/search** | ✅ SQL | 🔍 Grep | ❌ N/A |
| **Structured data** | ✅ JSONB | 📝 Markdown | ❌ N/A |
| **Multi-session** | ✅ Yes | ⚠️ Per-machine | ❌ N/A |
| **Requires install** | ⚠️ pg-memory | ✅ No | ✅ No |
| **Speed** | ⚡ Fast | 📄 Slower | ⚡ Instant |

## Implementation

```python
# In guardian check() output
result.update({
    "status": "high",
    "action": "summarize",
    "compact_options": [
        {
            "id": 1,
            "name": "Smart Compact",
            "emoji": "💾",
            "description": "Auto-selects pg-memory or files",
            "default": True,
            "available": True
        },
        {
            "id": 2,
            "name": "Compact to pg-memory",
            "emoji": "🗄️",
            "description": "PostgreSQL storage (requires pg-memory)",
            "available": PG_MEMORY_AVAILABLE
        },
        {
            "id": 3,
            "name": "Compact to Files",
            "emoji": "📄",
            "description": "MEMORY.md + daily notes",
            "available": True
        },
        {
            "id": 4,
            "name": "Just Reset",
            "emoji": "🔄",
            "description": "⚠️ No save - context lost",
            "warning": True,
            "available": True
        },
        {
            "id": 5,
            "name": "Show Status",
            "emoji": "📊",
            "description": "View details before deciding",
            "available": True
        }
    ]
})
```

## User Flow

```
Context at 85% → Guardian shows options
         ↓
User picks #1 (Smart Compact) [Enter]
         ↓
System tries pg-memory first
         ↓
If pg-memory available:
  ✅ Saved to PostgreSQL
  → Query: SELECT * FROM observations WHERE tags @> ['context_snapshot']
         ↓
If pg-memory not available:
  ✅ Saved to MEMORY.md
  → View: cat ~/.openclaw/workspace/memory/2026-03-11.md
         ↓
Reset session
         ↓
✅ Fresh start with context preserved
```

## After Compaction

**Query saved context:**
```bash
# If saved to pg-memory
python3 pg_memory_adapter.py query main

# If saved to files
grep -A 20 "Context Compaction" ~/.openclaw/workspace/memory/2026-03-11.md
```
