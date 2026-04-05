#!/bin/bash
# Toggle cámara web (cargar/descargar módulo del kernel)
# Requiere: /etc/sudoers.d/camera con:
#   %wheel ALL=(ALL) NOPASSWD: /usr/bin/modprobe -r uvcvideo, /usr/bin/modprobe uvcvideo
if lsmod | grep -q uvcvideo; then
    sudo -n modprobe -r uvcvideo 2>/dev/null
    if [ $? -eq 0 ]; then
        notify-send "Cámara" "Desactivada" -t 2000
    else
        notify-send "Cámara" "Error: configura sudoers para modprobe" -t 4000
    fi
else
    sudo -n modprobe uvcvideo 2>/dev/null
    if [ $? -eq 0 ]; then
        notify-send "Cámara" "Activada" -t 2000
    else
        notify-send "Cámara" "Error: configura sudoers para modprobe" -t 4000
    fi
fi
