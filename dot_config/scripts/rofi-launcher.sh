#!/usr/bin/env bash
# Lanzador inteligente Rofi con categorías y estética unificada

PALETTE="$HOME/.config/quickshell/.palette"
if [ -f "$PALETTE" ]; then
    read -r C_BG C_BLUE C_GREEN C_MAUVE _ C_RED C_TEXT C_SUB < "$PALETTE"
else
    C_BG="#1E1E2E"
    C_MAUVE="#cba6f7"
    C_TEXT="#cdd6f4"
fi

# Definimos las categorías
CATEGORIES="APPS\nMUSICA\nJUEGOS\nDESARROLLO"

# Lanzamos el menú de selección de categorías
SELECTED=$(echo -e "$CATEGORIES" | rofi -dmenu -p "Categoria" -theme theme.rasi)

# Según la selección, lanzamos el Rofi principal con el filtro adecuado
case $SELECTED in
    "JUEGOS")
        rofi -show drun -drun-categories Game -theme theme.rasi
        ;;
    "DESARROLLO")
        rofi -show drun -drun-categories Development,IDE -theme theme.rasi
        ;;
    "MUSICA")
        rofi -show drun -drun-categories Audio,Music -theme theme.rasi
        ;;
    *)
        rofi -show drun -theme theme.rasi
        ;;
esac
EOF
