#!/bin/bash
# init-workspaces.sh — Inicializar grupos de workspaces por monitor
# Monitor 0 → WS 1, Monitor 1 → WS 11, Monitor 2 → WS 21, etc.
# Se ejecuta al inicio de sesión (exec-once en hyprland.conf)

sleep 1  # Esperar a que Hyprland esté listo

MONITORS=$(hyprctl monitors -j | jq -r '.[].name')
INDEX=0

for MON in $MONITORS; do
    WS=$(( INDEX * 10 + 1 ))
    hyprctl dispatch focusmonitor "$MON"
    sleep 0.15
    hyprctl dispatch focusworkspaceoncurrentmonitor "$WS"
    sleep 0.15
    INDEX=$(( INDEX + 1 ))
done

# Volver al primer monitor
FIRST=$(echo "$MONITORS" | head -1)
hyprctl dispatch focusmonitor "$FIRST"
