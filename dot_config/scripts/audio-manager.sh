#!/bin/bash
# audio-manager.sh — Toggle Audio Manager UI
# Usage: audio-manager.sh toggle

RTDIR="${XDG_RUNTIME_DIR:-/tmp}"
FILE="$RTDIR/qs-audio-manager"

case "$1" in
    toggle)
        if [ -f "$FILE" ]; then
            STATE=$(cat "$FILE")
            if [ "$STATE" == "visible" ]; then
                echo "hidden" > "$FILE"
            else
                echo "visible" > "$FILE"
            fi
        else
            echo "visible" > "$FILE"
        fi
        ;;
    show)
        echo "visible" > "$FILE"
        ;;
    hide)
        echo "hidden" > "$FILE"
        ;;
esac
