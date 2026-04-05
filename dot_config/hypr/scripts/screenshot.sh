#!/bin/bash

# Screenshot script for Hyprland
# Supports area, window, and full screen captures

SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SCREENSHOT_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILENAME="$SCREENSHOT_DIR/screenshot_$TIMESTAMP.png"

case "$1" in
    area)
        # Select area
        grim -g "$(slurp)" "$FILENAME"
        ;;
    window)
        # Capture active window
        grim -g "$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" "$FILENAME"
        ;;
    full)
        # Full screen
        grim "$FILENAME"
        ;;
    *)
        # Default: area selection with swappy editor
        grim -g "$(slurp)" - | swappy -f -
        exit 0
        ;;
esac

# Copy to clipboard and notify
if [ -f "$FILENAME" ]; then
    wl-copy < "$FILENAME"
    notify-send "Screenshot saved" "$FILENAME" -i "$FILENAME"
fi
