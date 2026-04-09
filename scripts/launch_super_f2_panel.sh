#!/bin/bash
# Lanzador del panel Super F2
QML_FILE="/home/reaan/reaan-dotfiles/SuperF2Panel.qml"
if [ ! -f "$QML_FILE" ]; then
    echo "Error: $QML_FILE no encontrado." >&2
    exit 1
fi
qmlscene "$QML_FILE"
