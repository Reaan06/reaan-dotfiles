#!/bin/bash
# bt-toggle.sh — Toggle Bluetooth Panel UI
# Usage: bt-toggle.sh toggle

SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
[[ "$SCRIPT_DIR" == "${BASH_SOURCE[0]}" ]] && SCRIPT_DIR="."
source "$SCRIPT_DIR/runtime-paths.sh"
runtime_paths_load
RTDIR="$RUNTIME_PATHS_RUNTIME_DIR"
FILE="$RTDIR/qs-bt-panel"

case "$1" in
    toggle)
        FOCUSED=$(hyprctl monitors -j | jq -r '.[] | select(.focused==true) | .name')
        if [ -f "$FILE" ]; then
            STATE=$(cat "$FILE" | awk '{print $1}')
            if [ "$STATE" == "visible" ]; then
                echo "hidden $FOCUSED" > "$FILE"
            else
                # Al abrir, forzamos un refresco de datos si fuera necesario
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
