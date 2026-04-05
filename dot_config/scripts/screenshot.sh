#!/bin/bash
# screenshot.sh — Captura de pantalla con selección y editor
# Uso: screenshot.sh [region|full]

pkill swappy 2>/dev/null

case "${1:-region}" in
    region)
        GEOM=$(slurp)
        [ -z "$GEOM" ] && exit 1
        grim -g "$GEOM" - | swappy -f -
        ;;
    full)
        grim - | swappy -f -
        ;;
esac
