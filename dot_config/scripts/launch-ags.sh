#!/usr/bin/env bash

# Matar instancias existentes de Quickshell y AGS
killall -q quickshell || true
killall -q ags || true

# Carpeta de desarrollo de AGS
AGS_DIR="$HOME/reaan-dotfiles/ags"

if [ -d "$AGS_DIR" ]; then
    echo "Compilando configuración de AGS..."
    cd "$AGS_DIR" || exit 1
    node build.js
else
    echo "Directorio de AGS no encontrado en $AGS_DIR"
    exit 1
fi

# Lanzar AGS en segundo plano
echo "Iniciando AGS..."
ags run "$AGS_DIR/config.js" --gtk 4 --log-file "$HOME/ags.log" &
echo "AGS iniciado exitosamente."
