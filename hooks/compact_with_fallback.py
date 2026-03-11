#!/usr/bin/env python3
"""
Compact context before reset - with smart fallback
Tries pg-memory first, falls back to file storage
"""

import json
import sys
from pathlib import Path

# Try pg-memory adapter first
try:
    from ..pg_memory_adapter import save_context_snapshot, PG_MEMORY_AVAILABLE
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent.parent))
    try:
        from pg_memory_adapter import save_context_snapshot, PG_MEMORY_AVAILABLE
    except ImportError:
        PG_MEMORY_AVAILABLE = False
        save_context_snapshot = None

def compact_with_fallback(session_key, model, tokens_used, percent, messages, decisions, actions):
    """Save context with automatic fallback.
    
    Priority:
      1. pg-memory (if installed and working)
      2. File storage (MEMORY.md, daily notes)
      3. Log only (last resort)
    """
    
    result = {
        "session_key": session_key,
        "model": model,
        "tokens_used": tokens_used,
        "percent": percent,
        "attempted": [],
        "succeeded": False
    }
    
    # Try pg-memory first
    if PG_MEMORY_AVAILABLE and save_context_snapshot:
        try:
            pg_result = save_context_snapshot(
                session_key=session_key,
                model=model,
                tokens_used=tokens_used,
                percent=percent,
                messages=messages,
                decisions=decisions,
                actions=actions
            )
            
            if pg_result.get("saved"):
                result["succeeded"] = True
                result["storage"] = "pg-memory"
                result["location"] = pg_result.get("location")
                result["observation_id"] = pg_result.get("observation_id")
                return result
            else:
                result["attempted"].append({"pg-memory": pg_result.get("error", "unknown error")})
        except Exception as e:
            result["attempted"].append({"pg-memory": str(e)})
    else:
        result["attempted"].append({"pg-memory": "not available"})
    
    # Fallback to file storage
    try:
        file_result = save_to_files(
            session_key=session_key,
            model=model,
            tokens_used=tokens_used,
            percent=percent,
            decisions=decisions,
            actions=actions
        )
        
        if file_result.get("saved"):
            result["succeeded"] = True
            result["storage"] = "files"
            result["location"] = file_result.get("location")
            return result
        else:
            result["attempted"].append({"files": file_result.get("error", "failed")})
    except Exception as e:
        result["attempted"].append({"files": str(e)})
    
    # Last resort: just log
    result["succeeded"] = False
    result["fallback"] = "logged_only"
    print(f"[Token Guardian] Failed to save context for {session_key}", file=sys.stderr)
    
    return result

def save_to_files(session_key, model, tokens_used, percent, decisions, actions):
    """Fallback: Save to MEMORY.md and daily notes."""
    from datetime import datetime
    from pathlib import Path
    
    workspace = Path.home() / ".openclaw/workspace"
    today = datetime.now().strftime("%Y-%m-%d")
    
    summary = {
        "session_key": session_key,
        "model": model,
        "tokens_used": tokens_used,
        "percent": percent,
        "compacted_at": datetime.now().isoformat(),
        "decisions": decisions[:10],
        "actions": actions[:10]
    }
    
    # Save to daily notes
    daily_file = workspace / f"memory/{today}.md"
    daily_file.parent.mkdir(parents=True, exist_ok=True)
    
    with open(daily_file, "a") as f:
        f.write(f"\n\n## Context Compaction: {session_key}\n")
        f.write(f"**Model:** {model}\n")
        f.write(f"**Tokens:** {tokens_used} ({percent:.1f}%)\n\n")
        f.write(f"```json\n{json.dumps(summary, indent=2)}\n```\n")
    
    return {
        "saved": True,
        "location": str(daily_file)
    }

if __name__ == "__main__":
    # Example usage
    result = compact_with_fallback(
        session_key="main",
        model="ollama/kimi-k2.5",
        tokens_used=6400,
        percent=78.1,
        messages=[],
        decisions=["Test decision"],
        actions=["Test action"]
    )
    print(json.dumps(result, indent=2))
