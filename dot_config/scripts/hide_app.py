import json
import os
import sys
import tempfile
from pathlib import Path


def config_home():
    return Path(os.environ.get("QS_CONFIG_HOME") or os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")


def hidden_file():
    return config_home() / "scripts" / "hidden_apps.json"


def load_apps(path):
    try:
        with path.open(encoding="utf-8") as source:
            apps = json.load(source)
    except (FileNotFoundError, OSError, json.JSONDecodeError):
        return []
    return apps if isinstance(apps, list) and all(isinstance(app, str) for app in apps) else []


def save_apps(path, apps):
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(prefix=".hidden-apps.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as output:
            json.dump(apps, output)
        os.replace(temporary_name, path)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)

def main():
    if len(sys.argv) != 2 or not sys.argv[1]:
        print("Usage: python3 hide_app.py <AppClass>", file=sys.stderr)
        return 64

    app_class = sys.argv[1]
    path = hidden_file()
    hidden = load_apps(path)

    if app_class in hidden:
        hidden.remove(app_class)
    else:
        hidden.append(app_class)

    save_apps(path, hidden)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
