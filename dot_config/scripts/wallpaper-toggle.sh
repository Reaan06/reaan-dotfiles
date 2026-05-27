#!/bin/bash
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/qs-wallpaper-picker"
MONITOR=$(hyprctl monitors -j | jq -r ".[] | select(.focused==true) | .name")

if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE" | cut -d' ' -f1)" == "visible" ]; then
    echo "hidden $MONITOR" > "$STATE_FILE"
else
    echo "visible $MONITOR" > "$STATE_FILE"
fi
