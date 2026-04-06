#!/bin/bash
# restore-wallpaper.sh — Restore saved wallpapers on boot using swaybg
# Reads per-monitor state from ~/.config/hypr/wallpaper-state.conf

STATE="$HOME/.config/hypr/wallpaper-state.conf"
DEFAULT_WP="$HOME/Pictures/wallpapers/default.png"
PIDDIR="$HOME/.cache/swaybg-pids"
mkdir -p "$PIDDIR"

sleep 1.5  # Wait for Hyprland + monitors

# Kill any old swaybg/hyprpaper instances
pkill -x swaybg 2>/dev/null
pkill -x hyprpaper 2>/dev/null
sleep 0.3

ALL_MONS=$(hyprctl monitors -j | jq -r '.[].name' 2>/dev/null)

if [ -f "$STATE" ]; then
    while IFS='=' read -r mon wp; do
        mon=$(echo "$mon" | xargs)
        wp=$(echo "$wp" | xargs)
        if [ -n "$mon" ] && [ -n "$wp" ] && [ -f "$wp" ]; then
            swaybg -o "$mon" -i "$wp" -m fill &>/dev/null &
            echo $! > "$PIDDIR/$mon"
        fi
    done < "$STATE"

    # Cover any monitors not in state file with default
    for mon in $ALL_MONS; do
        if [ ! -f "$PIDDIR/$mon" ] && [ -f "$DEFAULT_WP" ]; then
            swaybg -o "$mon" -i "$DEFAULT_WP" -m fill &>/dev/null &
            echo $! > "$PIDDIR/$mon"
        fi
    done
else
    # No state: set default on all monitors
    for mon in $ALL_MONS; do
        if [ -f "$DEFAULT_WP" ]; then
            swaybg -o "$mon" -i "$DEFAULT_WP" -m fill &>/dev/null &
            echo $! > "$PIDDIR/$mon"
        fi
    done
fi
