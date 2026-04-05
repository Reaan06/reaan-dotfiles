#!/bin/bash
# Toggle touchpad via Hyprland keyword
STATE_FILE="/tmp/touchpad-state"

if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "off" ]; then
    hyprctl keyword "device[elan-touchpad]:enabled" true
    echo "on" > "$STATE_FILE"
    notify-send "Touchpad" "Activado" -t 2000
else
    hyprctl keyword "device[elan-touchpad]:enabled" false
    echo "off" > "$STATE_FILE"
    notify-send "Touchpad" "Desactivado" -t 2000
fi
