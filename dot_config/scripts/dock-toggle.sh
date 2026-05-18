#!/bin/bash
# dock-toggle.sh — Toggle Dock UI
# Usage: dock-toggle.sh toggle

RTDIR="${XDG_RUNTIME_DIR:-/tmp}"
FILE="$RTDIR/qs-dock-toggle"

case "$1" in
    toggle)
        FOCUSED=$(hyprctl monitors -j | jq -r '.[] | select(.focused==true) | .name')
        if [ -f "$FILE" ]; then
            STATE=$(cat "$FILE" | awk '{print $1}')
            if [ "$STATE" == "visible" ]; then
                echo "hidden $FOCUSED" > "$FILE"
            else
                echo "visible $FOCUSED" > "$FILE"
            fi
        else
            echo "visible $FOCUSED" > "$FILE"
        fi
        ;;
    show)
        FOCUSED=$(hyprctl monitors -j | jq -r '.[] | select(.focused==true) | .name')
        echo "visible $FOCUSED" > "$FILE"
        ;;
    hide)
        FOCUSED=$(hyprctl monitors -j | jq -r '.[] | select(.focused==true) | .name')
        echo "hidden $FOCUSED" > "$FILE"
        ;;
esac
