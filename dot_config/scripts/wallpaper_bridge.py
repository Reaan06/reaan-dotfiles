#!/usr/bin/env python3
"""
Wallpaper Bridge - Backend for the Quickshell Wallpaper Picker.
Handles listing approved images and uploading approved relative paths.
"""
import sys
import json
import shutil
from pathlib import Path

from runtime_paths import paths


WALLPAPER_DIR = Path(paths()["wallpaper_root"])


class WallpaperPathError(ValueError):
    pass


def approved_path(value):
    source = Path(value)
    if source.is_absolute():
        raise WallpaperPathError("Wallpaper path must be relative to the approved root.")
    if ".." in source.parts:
        raise WallpaperPathError("Wallpaper path traversal is not allowed.")
    root = WALLPAPER_DIR.resolve()
    resolved = (root / source).resolve()
    try:
        resolved.relative_to(root)
    except ValueError as error:
        raise WallpaperPathError("Wallpaper path resolves outside the approved root.") from error
    return resolved


def list_wallpapers():
    """Returns a JSON list of available wallpapers."""
    if not WALLPAPER_DIR.exists():
        return json.dumps([])

    wallpapers = []
    # Supported image extensions
    extensions = {'.jpg', '.jpeg', '.png', '.webp', '.bmp'}

    try:
        for file in WALLPAPER_DIR.iterdir():
            if file.is_file() and file.suffix.lower() in extensions:
                resolved = approved_path(file.name)
                wallpapers.append({
                    "name": file.stem.replace('_', ' ').capitalize(),
                    "filename": file.name,
                    "path": str(resolved),
                    "relativePath": file.name
                })

        # Sort by name for a consistent UI
        return json.dumps(sorted(wallpapers, key=lambda x: x['name']), indent=2)
    except WallpaperPathError:
        raise
    except OSError as error:
        raise WallpaperPathError(str(error)) from error


def upload_wallpaper(source_path):
    """Copies an approved image to the wallpapers folder."""
    source = approved_path(source_path)
    if not source.is_file():
        raise WallpaperPathError("Wallpaper file does not exist.")

    # Ensure destination directory exists
    WALLPAPER_DIR.mkdir(parents=True, exist_ok=True)
    target = WALLPAPER_DIR / source.name
    try:
        if source != target:
            shutil.copy2(source, target)
        return json.dumps({
            "success": True,
            "message": f"Uploaded {source.name} successfully",
            "path": str(target),
            "relativePath": target.name
        })
    except OSError as error:
        raise WallpaperPathError(str(error)) from error


def main():
    if len(sys.argv) < 2:
        print("Usage: wallpaper_bridge.py [list|upload <relative-path>]", file=sys.stderr)
        return 64

    try:
        cmd = sys.argv[1]
        if cmd == "list" and len(sys.argv) == 2:
            print(list_wallpapers())
            return 0
        if cmd == "upload" and len(sys.argv) == 3:
            print(upload_wallpaper(sys.argv[2]))
            return 0
    except WallpaperPathError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1

    print(f"Error: Unknown command '{sys.argv[1]}' or missing path argument.", file=sys.stderr)
    return 64


if __name__ == "__main__":
    raise SystemExit(main())
