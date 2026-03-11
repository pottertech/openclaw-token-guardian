#!/usr/bin/env python3
"""
pg-memory adapter for Token Guardian
Saves context snapshots before reset/new/model switch
"""

import json
import os
import sys
from datetime import datetime
from pathlib import Path

# Add pg-memory to path
sys.path.insert(0, str(Path.home() / ".openclaw/workspace/repos/openclaw-pg-memory/scripts"))

try:
    from pg_memory import PostgresMemory, MemoryConfig, create_observation
    PG_MEMORY_AVAILABLE = True
except ImportError:
    PG_MEMORY_AVAILABLE = False

def save_context_snapshot(session_key, model, tokens_used, percent, messages, decisions, actions):
    """Save compacted context to pg-memory before reset.
    
    Creates an observation of type 'context_snapshot' that survives
    session resets and can be queried later.
    """
    if not PG_MEMORY_AVAILABLE:
        return {"error": "pg-memory not available", "fallback": "file_storage"}
    
    try:
        config = MemoryConfig()
        mem = PostgresMemory(config)
        
        # Build snapshot
        snapshot = {
            "session_key": session_key,
            "model": model,
            "tokens_used": tokens_used,
            "percent": percent,
            "compacted_at": datetime.now().isoformat(),
            "message_count": len(messages),
            "decisions": decisions[:10],  # Top 10
            "action_items": actions[:10],  # Top 10
            "summary": summarize_messages(messages)
        }
        
        # Create observation
        result = create_observation(
            content=json.dumps(snapshot),
            tags=["context_snapshot", session_key, model.replace("/", "_")],
            chain_id=f"token-guardian-{session_key}"
        )
        
        return {
            "saved": True,
            "observation_id": result.get("id"),
            "type": "context_snapshot",
            "location": "pg-memory.observations"
        }
        
    except Exception as e:
        return {"error": str(e), "fallback": "file_storage"}

def summarize_messages(messages):
    """Extract key points from messages."""
    summary = {
        "topic": "",  # Could extract from first message
        "key_decisions": [],
        "files_modified": [],
        "commands_run": []
    }
    
    for msg in messages:
        content = msg.get("content", "")
        
        # Extract file modifications
        if "write" in content or "edit" in content:
            # Simple extraction
            pass
            
        # Extract commands
        if content.startswith("/"):
            summary["commands_run"].append(content.split()[0])
    
    return summary

def query_context_snapshots(session_key=None, limit=10):
    """Query saved context snapshots from pg-memory."""
    if not PG_MEMORY_AVAILABLE:
        return []
    
    try:
        config = MemoryConfig()
        mem = PostgresMemory(config)
        
        # Query observations
        if session_key:
            results = mem.query(
                tags=["context_snapshot", session_key],
                limit=limit
            )
        else:
            results = mem.query(
                tags=["context_snapshot"],
                limit=limit
            )
        
        return results
        
    except Exception as e:
        return [{"error": str(e)}]

def get_latest_snapshot(session_key):
    """Get most recent context snapshot for session."""
    results = query_context_snapshots(session_key, limit=1)
    return results[0] if results else None

if __name__ == "__main__":
    # Test
    result = save_context_snapshot(
        session_key="test",
        model="ollama/kimi-k2.5",
        tokens_used=6400,
        percent=78.1,
        messages=[{"content": "Test message"}],
        decisions=["Test decision"],
        actions=["Test action"]
    )
    print(json.dumps(result, indent=2))
