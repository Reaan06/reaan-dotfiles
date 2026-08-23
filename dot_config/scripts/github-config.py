#!/usr/bin/env python3
"""Persist GitHub credentials through stdin-backed, private configuration files."""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path


USERNAME = re.compile(r"^[A-Za-z0-9-]+$")


def config_path() -> Path:
    home = Path(os.environ.get("HOME", str(Path.home())))
    config_home = Path(os.environ.get("QS_CONFIG_HOME") or os.environ.get("XDG_CONFIG_HOME") or home / ".config")
    return config_home / "quickshell" / ".github-config"


def validate_username(value: str) -> str:
    username = value.strip()
    if not USERNAME.fullmatch(username):
        raise ValueError("GitHub username is invalid.")
    return username


def save(username: str, token: str) -> None:
    path = config_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    content = username + ("\n" + token if token else "") + "\n"
    descriptor, temporary_name = tempfile.mkstemp(prefix=".github-config.", dir=path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as output:
            os.chmod(temporary, 0o600)
            output.write(content)
        os.replace(temporary, path)
        os.chmod(path, 0o600)
    finally:
        if temporary.exists():
            temporary.unlink()


def load() -> dict[str, str]:
    try:
        lines = config_path().read_text(encoding="utf-8").splitlines()
    except FileNotFoundError:
        return {"username": "", "token": ""}
    username = lines[0].strip() if lines else ""
    token = lines[1] if len(lines) > 1 else ""
    return {"username": username, "token": token}


def login() -> None:
    subprocess.run(["gh", "auth", "login", "-w", "-p", "https"], check=True)
    token = subprocess.run(["gh", "auth", "token"], check=True, capture_output=True, text=True).stdout.strip()
    username = subprocess.run(["gh", "api", "user", "-q", ".login"], check=True, capture_output=True, text=True).stdout.strip()
    save(validate_username(username), token)


def main() -> int:
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        if command == "save" and len(sys.argv) == 3:
            save(validate_username(sys.argv[2]), sys.stdin.readline().rstrip("\n"))
        elif command == "load" and len(sys.argv) == 2:
            print(json.dumps(load(), sort_keys=True))
        elif command == "delete" and len(sys.argv) == 2:
            config_path().unlink(missing_ok=True)
        elif command == "login" and len(sys.argv) == 2:
            login()
        else:
            print("Usage: github-config.py [save <username>|load|delete|login]", file=sys.stderr)
            return 64
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
