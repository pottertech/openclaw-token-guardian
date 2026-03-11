#!/usr/bin/env python3
"""
Auto-compact before context loss
Extracts key info before /reset, /new, or overflow
"""

import json
import sys
import os
import re
from datetime import datetime
from pathlib import Path

def extract_key_info(messages):
    """Extract critical info from conversation."""
    info = {
        "decisions": [],
        "action_items": [],
        "code_snippets": [],
        "important_facts": [],
        "file_changes": []
    }
    
    for msg in messages:
        content = msg.get("content", "")
        
        # Extract decisions ("We decided to...", "Let's use...")
        if any(phrase in content.lower() for phrase in ["decided", "let's", "we will", "agreed"]):
            info["decisions"].append(content[:200])
        
        # Extract action items (TODO, FIXME, "Need to")
        todos = re.findall(r'(TODO|FIXME|XXX|Need to|Should|Must)[\s:]([^\n]+)', content, re.I)
        for _, todo in todos:
            info["action_items"].append(todo.strip())
        
        # Extract code blocks
        code = re.findall(r'```(\w+)?\n(.*?)```', content, re.DOTALL)
        for lang, code_content in code:
            info["code_snippets"].append({
                "language": lang or "text",
                "code": code_content[:500]  # Truncate long blocks
            })
        
        # Extract file paths
        paths = re.findall(r'`([^`]+\.(py|sh|md|yaml|json))`', content)
        for path, _ in paths:
            info["file_changes"].append(path)
    
    return info

def save_compaction(session_key, info):
    """Save compacted info to memory files."""
    workspace = Path.home() / ".openclaw/workspace"
    today = datetime.now().strftime("%Y-%m-%d")
    
    # 1. Append to MEMORY.md (critical decisions)
    memory_file = workspace / "MEMORY.md"
    if memory_file.exists():
        with open(memory_file, "a") as f:
            f.write(f"\n\n## Compacted Session: {session_key}\n")
            f.write(f"**Date:** {datetime.now().isoformat()}\n\n")
            
            if info["decisions"]:
                f.write("### Key Decisions\n")
                for d in info["decisions"][:5]:
                    f.write(f"- {d}\n")
            
            if info["action_items"]:
                f.write("\n### Action Items\n")
                for a in info["action_items"][:5]:
                    f.write(f"- [ ] {a}\n")
    
    # 2. Save code snippets
    if info["code_snippets"]:
        code_dir = workspace / "memory/code"
        code_dir.mkdir(parents=True, exist_ok=True)
        code_file = code_dir / f"{today}_{session_key}.json"
        with open(code_file, "w") as f:
            json.dump(info["code_snippets"][:10], f, indent=2)
    
    # 3. Daily notes
    daily_file = workspace / f"memory/{today}.md"
    daily_file.parent.mkdir(parents=True, exist_ok=True)
    with open(daily_file, "a") as f:
        f.write(f"\n\n## Session Compaction: {session_key}\n")
        f.write(f"**Time:** {datetime.now().strftime('%H:%M')}\n\n")
        f.write(f"- Decisions captured: {len(info['decisions'])}\n")
        f.write(f"- Action items: {len(info['action_items'])}\n")
        f.write(f"- Code snippets: {len(info['code_snippets'])}\n")
        f.write(f"- Files referenced: {', '.join(set(info['file_changes']))}\n")
    
    return {
        "saved_to": [
            str(memory_file) if info["decisions"] else None,
            str(code_file) if info["code_snippets"] else None,
            str(daily_file)
        ],
        "stats": {
            "decisions": len(info["decisions"]),
            "actions": len(info["action_items"]),
            "code": len(info["code_snippets"]),
            "files": len(set(info["file_changes"]))
        }
    }

def compact_session(session_key, messages):
    """Main compaction entry point."""
    info = extract_key_info(messages)
    result = save_compaction(session_key, info)
    
    return {
        "compacted": True,
        "session": session_key,
        "preserved": result["stats"],
        "saved_to": [p for p in result["saved_to"] if p]
    }

if __name__ == "__main__":
    # Called before /reset or /new
    session_key = os.environ.get('OPENCLAW_SESSION_KEY', 'main')
    
    # TODO: Get messages from OpenClaw
    # For now, show structure
    result = {
        "ready": True,
        "message": "Auto-compact hook ready",
        "note": "Will extract decisions/action items/code before /reset or /new"
    }
    
    print(json.dumps(result, indent=2))
