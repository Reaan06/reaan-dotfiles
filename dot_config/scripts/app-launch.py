#!/usr/bin/env python3
"""Launch desktop commands without evaluating their metadata as shell source."""

from __future__ import annotations

import os
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path


FIELD_CODE = re.compile(r"(?<!%)%[fFuUdDnNickvm]")


def parse_exec_line(value: str) -> list[str]:
    if not value.strip():
        raise ValueError("application command is required.")
    try:
        arguments = shlex.split(value)
    except ValueError as error:
        raise ValueError("application command is invalid.") from error
    arguments = [FIELD_CODE.sub("", argument).replace("%%", "%") for argument in arguments]
    arguments = [argument for argument in arguments if argument]
    if not arguments or any("\x00" in argument for argument in arguments):
        raise ValueError("application command is invalid.")
    return arguments


def desktop_roots() -> list[Path]:
    home = Path(os.environ.get("HOME", str(Path.home())))
    data_home = Path(os.environ.get("XDG_DATA_HOME", home / ".local/share"))
    data_dirs = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
    return [data_home / "applications", *(Path(directory) / "applications" for directory in data_dirs if directory)]


def fallback_exec(command: str) -> str | None:
    expected_name = Path(command).name.casefold()
    for root in desktop_roots():
        if not root.is_dir():
            continue
        for entry in root.glob("*.desktop"):
            try:
                name = ""
                exec_line = ""
                for line in entry.read_text(encoding="utf-8", errors="replace").splitlines():
                    if line.startswith("Name="):
                        name = line.removeprefix("Name=").strip()
                    elif line.startswith("Exec="):
                        exec_line = line.removeprefix("Exec=").strip()
                if name.casefold() == expected_name and exec_line:
                    return exec_line
            except OSError:
                continue
    return None


def launch(command: str) -> None:
    arguments = parse_exec_line(command)
    if shutil.which(arguments[0]) is None:
        fallback = fallback_exec(arguments[0])
        if fallback is not None:
            arguments = parse_exec_line(fallback)
    if shutil.which(arguments[0]) is None:
        raise ValueError("application executable is unavailable.")
    try:
        subprocess.Popen(
            arguments,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except OSError as error:
        raise ValueError("application could not be launched.") from error


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: python3 app-launch.py <exec-line>", file=sys.stderr)
        return 64
    try:
        launch(sys.argv[1])
    except ValueError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1 if sys.argv[1].strip() else 64
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
