#!/bin/bash
# apply-wallpaper.sh — Apply wallpaper to the focused monitor using swaybg
# Usage: apply-wallpaper.sh /path/to/image.png

IMAGE="$1"
STATE="$HOME/.config/hypr/wallpaper-state.conf"
EXTRACT="$HOME/.config/scripts/extract-colors.py"
PALETTE="$HOME/.cache/qs-palette"
PIDDIR="$HOME/.cache/swaybg-pids"
mkdir -p "$PIDDIR"

[ -z "$IMAGE" ] || [ ! -f "$IMAGE" ] && exit 1

# 1. Detect focused monitor
FOCUSED=$(hyprctl monitors -j | jq -r '.[] | select(.focused==true) | .name')
ALL_MONS=$(hyprctl monitors -j | jq -r '.[].name')
[ -z "$FOCUSED" ] && FOCUSED=$(echo "$ALL_MONS" | head -1)

# 2. Load existing state
declare -A STATE_MAP
if [ -f "$STATE" ]; then
    while IFS='=' read -r mon wp; do
        mon=$(echo "$mon" | xargs)
        wp=$(echo "$wp" | xargs)
        [ -n "$mon" ] && STATE_MAP["$mon"]="$wp"
    done < "$STATE"
fi

# 3. Update focused monitor
STATE_MAP["$FOCUSED"]="$IMAGE"

# 4. Ensure all connected monitors have a wallpaper
for mon in $ALL_MONS; do
    [ -z "${STATE_MAP[$mon]}" ] && STATE_MAP["$mon"]="$IMAGE"
done

# 5. Save persistent state
> "$STATE"
for mon in "${!STATE_MAP[@]}"; do
    echo "$mon=${STATE_MAP[$mon]}" >> "$STATE"
done

# 6. Kill old swaybg for this monitor and start new one
if [ -f "$PIDDIR/$FOCUSED" ]; then
    kill "$(cat "$PIDDIR/$FOCUSED")" 2>/dev/null
    sleep 0.1
fi
swaybg -o "$FOCUSED" -i "$IMAGE" -m fill &>/dev/null &
echo $! > "$PIDDIR/$FOCUSED"

# 7. Extract colors
RAW="/tmp/qs-colors-raw"
magick "$IMAGE" -resize 200x200! -colors 8 -unique-colors -depth 8 txt:- \
    2>/dev/null | tail -n +2 | grep -oE '#[0-9A-Fa-f]{6}' | head -8 > "$RAW"
if [ -f "$EXTRACT" ] && [ -f "$RAW" ]; then
    python3 "$EXTRACT" "$RAW" "$PALETTE" 2>/dev/null
    rm -f "$RAW"
fi

notify-send "Wallpaper" "$(basename "$IMAGE") → $FOCUSED" -i "$IMAGE" -t 3000
