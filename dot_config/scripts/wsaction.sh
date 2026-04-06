#!/bin/bash
# wsaction.sh — Per-monitor workspace groups
# eDP-1: WS 1-7 | HDMI-A-1: WS 11-17
#
# Uso: wsaction.sh <dispatcher> <number|prev|next>
#   wsaction.sh workspace 3          → WS 3 o 13 según el monitor enfocado
#   wsaction.sh workspace next       → siguiente WS dentro del grupo
#   wsaction.sh movetoworkspace 5    → mueve ventana al WS 5 o 15

DISPATCHER="$1"
TARGET="$2"
MAX_PER_GROUP=7

# Get current workspace and calculate group
ACTIVE_WS=$(hyprctl activeworkspace -j | jq -r '.id')
GROUP=$(( (ACTIVE_WS - 1) / 10 * 10 ))
GROUP_MIN=$(( GROUP + 1 ))
GROUP_MAX=$(( GROUP + MAX_PER_GROUP ))

# Calculate target workspace
case "$TARGET" in
    next)
        REAL_WS=$(( ACTIVE_WS + 1 ))
        [ "$REAL_WS" -gt "$GROUP_MAX" ] && REAL_WS="$GROUP_MIN"
        ;;
    prev)
        REAL_WS=$(( ACTIVE_WS - 1 ))
        [ "$REAL_WS" -lt "$GROUP_MIN" ] && REAL_WS="$GROUP_MAX"
        ;;
    *)
        REAL_WS=$(( GROUP + TARGET ))
        ;;
esac

# Dispatch
if [ "$DISPATCHER" = "workspace" ]; then
    hyprctl dispatch focusworkspaceoncurrentmonitor "$REAL_WS"
else
    hyprctl dispatch movetoworkspacesilent "$REAL_WS"
fi
