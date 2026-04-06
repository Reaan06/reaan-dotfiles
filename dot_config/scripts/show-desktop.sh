#!/bin/bash
# show-desktop.sh — Toggle show desktop (minimize all / restore all)
# Uses Hyprland's special workspace to hide/show all windows

STATE_FILE="/tmp/hypr-show-desktop"

if [ -f "$STATE_FILE" ]; then
    # Restore: move all windows back from special workspace
    while IFS= read -r addr; do
        hyprctl dispatch movetoworkspacesilent "e+0,address:$addr" 2>/dev/null
    done < "$STATE_FILE"
    rm -f "$STATE_FILE"
else
    # Hide: move all visible windows to special workspace
    > "$STATE_FILE"
    hyprctl clients -j | jq -r '.[] | select(.workspace.id >= 0) | .address' | while IFS= read -r addr; do
        echo "$addr" >> "$STATE_FILE"
        hyprctl dispatch movetoworkspacesilent "special:desktop,address:$addr" 2>/dev/null
    done
fi
