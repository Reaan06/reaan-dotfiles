import json
import os
import sys
import tempfile
from pathlib import Path


def config_home():
    return Path(os.environ.get("QS_CONFIG_HOME") or os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")


def pinned_file():
    return config_home() / "scripts" / "pinned_apps.json"


def load_apps(path):
    try:
        with path.open(encoding="utf-8") as source:
            apps = json.load(source)
    except (FileNotFoundError, OSError, json.JSONDecodeError):
        return []
    return apps if isinstance(apps, list) and all(isinstance(app, str) for app in apps) else []


def save_apps(path, apps):
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(prefix=".pinned-apps.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as output:
            json.dump(apps, output)
        os.replace(temporary_name, path)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)

def toggle_pin(app_class):
    path = pinned_file()
    pinned = load_apps(path)
    if app_class in pinned:
        pinned.remove(app_class)
        action = "unpinned"
    else:
        pinned.append(app_class)
        action = "pinned"
        
    save_apps(path, pinned)
    print(f"App {app_class} {action}")

if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1]:
        toggle_pin(sys.argv[1])
    else:
        print("Usage: python3 pin_app.py <AppClass>", file=sys.stderr)
        raise SystemExit(64)
