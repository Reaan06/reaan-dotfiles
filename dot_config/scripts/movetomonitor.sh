#!/bin/bash
# movetomonitor.sh — Move focused window to the next/previous monitor
# Usage: movetomonitor.sh [next|prev]

DIR="${1:-next}"

# Get all monitors and current focused monitor
FOCUSED=$(hyprctl monitors -j | jq -r '.[] | select(.focused==true) | .name')
ALL=($(hyprctl monitors -j | jq -r '.[].name'))
COUNT=${#ALL[@]}

# Find index of focused
IDX=0
for i in "${!ALL[@]}"; do
    [ "${ALL[$i]}" = "$FOCUSED" ] && IDX=$i
done

# Calculate target
if [ "$DIR" = "next" ]; then
    TARGET_IDX=$(( (IDX + 1) % COUNT ))
else
    TARGET_IDX=$(( (IDX - 1 + COUNT) % COUNT ))
fi
TARGET="${ALL[$TARGET_IDX]}"

# Move active window to that monitor
hyprctl dispatch movewindow "mon:$TARGET"
