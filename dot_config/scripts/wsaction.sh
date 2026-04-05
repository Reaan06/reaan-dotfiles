#!/bin/bash
# wsaction.sh — Per-monitor workspace groups (Caelestia-style)
# Cada monitor tiene su propio grupo de 10 workspaces:
#   Monitor 1: WS 1-10, Monitor 2: WS 11-20, Monitor 3: WS 21-30...
#
# Uso: wsaction.sh [-g] <dispatcher> <workspace_number>
#   wsaction.sh workspace 3          → WS 3 del grupo actual (dentro del monitor)
#   wsaction.sh movetoworkspace 5    → mueve ventana al WS 5 del grupo
#   wsaction.sh -g workspace 2       → va al grupo 2 (monitor 2), mismo WS relativo

GROUP_MODE=false
if [ "$1" = "-g" ]; then
    GROUP_MODE=true
    shift
fi

DISPATCHER="$1"
TARGET="$2"

ACTIVE_WS=$(hyprctl activeworkspace -j | jq -r '.id')

if [ "$GROUP_MODE" = true ]; then
    # -g: mover entre grupos (monitores), mantener posición relativa dentro del grupo
    # Fórmula: (target_group - 1) * 10 + (activeWS % 10)
    REAL_WS=$(( (TARGET - 1) * 10 + (ACTIVE_WS - 1) % 10 + 1 ))
else
    # Normal: mover dentro del grupo actual
    # Fórmula: floor((activeWS - 1) / 10) * 10 + target
    GROUP=$(( (ACTIVE_WS - 1) / 10 * 10 ))
    REAL_WS=$(( GROUP + TARGET ))
fi

hyprctl dispatch "$DISPATCHER" "$REAL_WS"
