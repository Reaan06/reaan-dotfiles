#!/bin/bash
# powermenu.sh — Modern power menu with rofi + Nerd Font icons

THEME="$HOME/.config/rofi/powermenu.rasi"

chosen=$(echo -e \
"<span color='#f38ba8'>  </span>  Apagar\n<span color='#fab387'>  </span>  Reiniciar\n<span color='#a6e3a1'>󰒲  </span>  Suspender\n<span color='#89b4fa'>  </span>  Bloquear\n<span color='#cba6f7'>󰍃  </span>  Salir" \
    | rofi -dmenu \
    -mesg "  Sesión" \
    -markup-rows \
    -theme "$THEME" \
    -hover-select \
    -me-select-entry '' \
    -me-accept-entry 'MousePrimary')

case "$chosen" in
    *Apagar)     systemctl poweroff ;;
    *Reiniciar)  systemctl reboot ;;
    *Suspender)  systemctl suspend ;;
    *Bloquear)   hyprlock ;;
    *Salir)      hyprctl dispatch exit ;;
esac
