#!/bin/bash
# wsaction.sh — Per-monitor workspace groups
# eDP-1: WS 1-7 | HDMI-A-1: WS 11-17
#
# Uso: wsaction.sh <dispatcher> <number|prev|next>
#   wsaction.sh workspace 3          → WS 3 o 13 según el monitor enfocado
#   wsaction.sh workspace next       → siguiente WS dentro del grupo
#   wsaction.sh movetoworkspace 5    → mueve ventana al WS 5 o 15

set -euo pipefail

DISPATCHER="${1:-}"
TARGET="${2:-}"
MAX_PER_GROUP=7

# Resolve the group from the focused monitor, not from the global workspace id.
ACTIVE_WORKSPACE=$(hyprctl activeworkspace -j)
FOCUSED_MONITOR=$(jq -r '.monitor // empty' <<< "$ACTIVE_WORKSPACE")
ACTIVE_WS=$(jq -r '.id // empty' <<< "$ACTIVE_WORKSPACE")
case "$FOCUSED_MONITOR" in
    eDP-1) GROUP_MIN=1 ;;
    HDMI-A-1) GROUP_MIN=11 ;;
    *)
        printf 'Unsupported focused monitor workspace group: %s\n' "$FOCUSED_MONITOR" >&2
        exit 1
        ;;
esac
GROUP_MAX=$(( GROUP_MIN + MAX_PER_GROUP - 1 ))

[[ "$ACTIVE_WS" =~ ^[0-9]+$ ]] || { printf 'Invalid active workspace id: %s\n' "$ACTIVE_WS" >&2; exit 1; }
[[ "$ACTIVE_WS" -ge "$GROUP_MIN" && "$ACTIVE_WS" -le "$GROUP_MAX" ]] || {
    printf 'Active workspace %s is outside the %s group.\n' "$ACTIVE_WS" "$FOCUSED_MONITOR" >&2
    exit 1
}

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
        [[ "$TARGET" =~ ^[1-7]$ ]] || { printf 'Workspace target must be 1-7, prev, or next.\n' >&2; exit 64; }
        REAL_WS=$(( GROUP_MIN + TARGET - 1 ))
        ;;
esac

# Dispatch
case "$DISPATCHER" in
    workspace) hyprctl dispatch focusworkspaceoncurrentmonitor "$REAL_WS" ;;
    movetoworkspace) hyprctl dispatch movetoworkspacesilent "$REAL_WS" ;;
    *) printf 'Usage: %s {workspace|movetoworkspace} {1-7|prev|next}\n' "$0" >&2; exit 64 ;;
esac
