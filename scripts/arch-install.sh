#!/bin/bash
# Instalador de dependencias para Arch Linux
echo "Instalando dependencias..."
sudo pacman -Sy --noconfirm qt5-declarative qt5-tools github-cli lm_sensors
if [ $? -eq 0 ]; then
    echo "Dependencias instaladas correctamente."
else
    echo "Error en la instalación." >&2
    exit 1
fi
