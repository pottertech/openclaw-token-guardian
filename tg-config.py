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

def set_auto_action(enabled):
    """Enable or disable auto-action globally."""
    config = load_config()
    if 'auto_action' not in config:
        config['auto_action'] = {
            "enabled": True,
            "at_85_percent": True,
            "at_95_percent": False,
            "notify_on_action": True
        }
    config['auto_action']['enabled'] = bool(enabled)
    save_config(config)
    status = "enabled" if enabled else "disabled"
    print(f"✅ Auto-action {status}")
    print(f"   At 85%: {'AUTO-COMPACT' if config['auto_action'].get('at_85_percent', True) else 'warn only'}")
    print(f"   At 95%: {'CRITICAL WARNING (no auto-switch)'}")
    return True

def set_auto_85(enabled):
    """Enable or disable auto-compact at 85%."""
    config = load_config()
    if 'auto_action' not in config:
        config['auto_action'] = {
            "enabled": True,
            "at_85_percent": True,
            "at_95_percent": False,
            "notify_on_action": True
        }
    config['auto_action']['at_85_percent'] = bool(enabled)
    save_config(config)
    status = "AUTO-COMPACT" if enabled else "warn only"
    print(f"✅ At 85%: {status}")
    return True

def set_notify_on_action(enabled):
    """Enable or disable notifications when auto-action runs."""
    config = load_config()
    if 'auto_action' not in config:
        config['auto_action'] = {
            "enabled": True,
            "at_85_percent": True,
            "at_95_percent": False,
            "notify_on_action": True
        }
    config['auto_action']['notify_on_action'] = bool(enabled)
    save_config(config)
    status = "enabled" if enabled else "disabled"
    print(f"✅ Notifications on auto-action: {status}")
    return True