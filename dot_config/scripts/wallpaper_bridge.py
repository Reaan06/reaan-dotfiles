#!/usr/bin/env python3
"""
Wallpaper Bridge - Backend for the Quickshell Wallpaper Picker.
Handles listing images in the dotfiles wallpaper folder and uploading new ones.
"""
import os
import sys
import json
import shutil
from pathlib import Path

# Use HOME from env for maximum reliability in Quickshell/systemd environments
HOME = os.environ.get('HOME', str(Path.home()))
WALLPAPER_DIR = Path(HOME) / "reaan-dotfiles" / "wallps"

def list_wallpapers():
    """Returns a JSON list of available wallpapers."""
    # Log to a file for debugging Quickshell execution
    log_path = Path(HOME) / ".config/quickshell/bridge.log"
    
    if not WALLPAPER_DIR.exists():
        with open(log_path, 'a') as f:
            f.write(f"Error: Directory {WALLPAPER_DIR} does not exist\n")
        return json.dumps([])
    
    wallpapers = []
    # Supported image extensions
    extensions = {'.jpg', '.jpeg', '.png', '.webp', '.bmp'}
    
    try:
        for file in WALLPAPER_DIR.iterdir():
            if file.is_file() and file.suffix.lower() in extensions:
                wallpapers.append({
                    "name": file.stem.replace('_', ' ').capitalize(),
                    "filename": file.name,
                    "path": str(file.absolute())
                })
        
        # Sort by name for a consistent UI
        return json.dumps(sorted(wallpapers, key=lambda x: x['name']), indent=2)
    except Exception as e:
        with open(log_path, 'a') as f:
            f.write(f"Error listing: {str(e)}\n")
        return json.dumps({"error": str(e)})

def upload_wallpaper(source_path):
    """Copies an image from source_path to the wallpapers folder."""
    source = Path(source_path)
    if not source.exists():
        return json.dumps({"error": f"Source file does not exist: {source_path}"})
    
    # Ensure destination directory exists
    WALLPAPER_DIR.mkdir(parents=True, exist_ok=True)
    
    target = WALLPAPER_DIR / source.name
    try:
        shutil.copy2(source, target)
        return json.dumps({
            "success": True, 
            "message": f"Uploaded {source.name} successfully",
            "path": str(target.absolute())
        })
    except Exception as e:
        return json.dumps({"error": str(e)})

def main():
    if len(sys.argv) < 2:
        print("Usage: wallpaper_bridge.py [list|upload <path>]")
        sys.exit(1)
    
    cmd = sys.argv[1]
    if cmd == "list":
        print(list_wallpapers())
    elif cmd == "upload" and len(sys.argv) > 2:
        print(upload_wallpaper(sys.argv[2]))
    else:
        print(f"Error: Unknown command '{cmd}' or missing path argument.")
        sys.exit(1)

if __name__ == "__main__":
    main()
