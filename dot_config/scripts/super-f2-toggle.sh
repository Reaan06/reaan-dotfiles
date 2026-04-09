#!/bin/bash
# super-f2-toggle.sh — Toggle Super F2 Panel UI
# Usage: super-f2-toggle.sh toggle

RTDIR="${XDG_RUNTIME_DIR:-/tmp}"
FILE="$RTDIR/qs-super-f2"

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
