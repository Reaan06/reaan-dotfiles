#!/bin/bash
# init-workspaces.sh — Inicializar grupos de workspaces por monitor
# eDP-1 → WS 1, HDMI-A-1 → WS 11.
# Se ejecuta al inicio de sesión (exec-once en hyprland.conf)

sleep 1  # Esperar a que Hyprland esté listo

MONITORS=$(hyprctl monitors -j | jq -r '.[].name')
for MON in $MONITORS; do
    case "$MON" in
        eDP-1) WS=1 ;;
        HDMI-A-1) WS=11 ;;
        *) printf 'Skipping monitor without a workspace group: %s\n' "$MON" >&2; continue ;;
    esac
    hyprctl dispatch focusmonitor "$MON"
    sleep 0.15
    hyprctl dispatch focusworkspaceoncurrentmonitor "$WS"
    sleep 0.15
done

# Volver al primer monitor
FIRST=$(echo "$MONITORS" | head -1)
hyprctl dispatch focusmonitor "$FIRST"
