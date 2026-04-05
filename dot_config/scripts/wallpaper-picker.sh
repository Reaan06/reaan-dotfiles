#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
#  Wallpaper Picker — GTK4 Gallery + Hyprpaper + Colores
#  Ruta de wallpapers: ~/Pictures/wallpapers/
# ═══════════════════════════════════════════════════════════

# Kill existing instance
pkill -f "wallpaper-picker.py" 2>/dev/null

python3 ~/.config/scripts/wallpaper-picker.py &
PID=$!

# Wait for window to appear, then float + center it
for i in $(seq 1 20); do
    sleep 0.2
    ADDR=$(hyprctl clients -j | jq -r '.[] | select(.class == "com.reaan.wallpicker") | .address' 2>/dev/null)
    if [ -n "$ADDR" ]; then
        hyprctl dispatch togglefloating "address:$ADDR" 2>/dev/null
        hyprctl dispatch resizewindowpixel "exact 90% 85%,address:$ADDR" 2>/dev/null
        hyprctl dispatch centerwindow "address:$ADDR" 2>/dev/null
        break
    fi
done

wait $PID 2>/dev/null
