#!/usr/bin/env bash

# Matar instancias existentes de AGS y Quickshell
killall -q ags || true
killall -q quickshell || true

# Lanzar Quickshell en segundo plano
echo "Iniciando Quickshell..."
nohup quickshell -d > "$HOME/qs.log" 2>&1 &
echo "Quickshell iniciado exitosamente."
