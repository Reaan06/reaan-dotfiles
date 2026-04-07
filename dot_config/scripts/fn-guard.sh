#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Uso: $0 <accion>" >&2
    exit 2
fi

action="$1"

# Consultamos ventana activa; si falla, mantenemos fallback normal.
active_json="$(hyprctl activewindow -j 2>/dev/null || true)"

if [ -n "${active_json}" ]; then
    fullscreen_state="$(printf '%s' "${active_json}" | jq -r '.fullscreen // 0' 2>/dev/null || echo 0)"
    win_class_lc="$(printf '%s' "${active_json}" | jq -r '.class // ""' 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    win_title_lc="$(printf '%s' "${active_json}" | jq -r '.title // ""' 2>/dev/null | tr '[:upper:]' '[:lower:]')"
else
    fullscreen_state=0
    win_class_lc=""
    win_title_lc=""
fi

# Bloquear acciones multimedia si estamos en fullscreen o en juegos conocidos.
if [ "${fullscreen_state}" != "0" ]; then
    exit 0
fi
if printf '%s\n%s\n' "${win_class_lc}" "${win_title_lc}" | grep -Eq '(mta|multi theft auto|wine|lutris|steam_app_|proton)'; then
    exit 0
fi

case "${action}" in
    volume_mute)
        exec ~/.config/scripts/osd-control.sh volume mute
        ;;
    volume_down)
        exec ~/.config/scripts/osd-control.sh volume down
        ;;
    volume_up)
        exec ~/.config/scripts/osd-control.sh volume up
        ;;
    mic_toggle)
        exec pamixer --default-source -t
        ;;
    camera_toggle)
        exec ~/.config/scripts/toggle-camera.sh
        ;;
    lock)
        exec hyprlock
        ;;
    displays)
        exec nwg-displays
        ;;
    brightness_down)
        exec ~/.config/scripts/osd-control.sh brightness down
        ;;
    brightness_up)
        exec ~/.config/scripts/osd-control.sh brightness up
        ;;
    *)
        echo "Accion desconocida: ${action}" >&2
        exit 2
        ;;
esac
