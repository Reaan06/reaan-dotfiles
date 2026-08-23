#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path
def paths():
    home = os.environ.get("HOME", str(Path.home()))
    config = os.environ.get("QS_CONFIG_HOME") or os.environ.get("XDG_CONFIG_HOME") or f"{home}/.config"; pictures = os.environ.get("XDG_PICTURES_DIR") or f"{home}/Pictures"
    return {
        "config_home": config,
        "runtime_dir": os.environ.get("QS_RUNTIME_DIR") or os.environ.get("XDG_RUNTIME_DIR") or "/tmp",
        "wallpaper_root": os.environ.get("QS_WALLPAPER_ROOT") or f"{pictures}/wallpapers",
    }
if __name__ == "__main__":
    resolved = paths()
    key = sys.argv[1] if len(sys.argv) > 1 else "json"
    if key == "json": print(json.dumps(resolved, sort_keys=True))
    elif key in resolved: print(resolved[key])
    else: print("Usage: runtime_paths.py [json|config_home|runtime_dir|wallpaper_root]", file=sys.stderr); sys.exit(64)
