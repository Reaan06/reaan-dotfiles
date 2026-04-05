#!/bin/bash
# Bajar brillo con floor de 5% para evitar pantalla negra
brightnessctl set 5%-
max=$(brightnessctl max)
floor=$((max * 5 / 100))
cur=$(brightnessctl get)
if [ "$cur" -lt "$floor" ]; then
    brightnessctl set 5%
fi
