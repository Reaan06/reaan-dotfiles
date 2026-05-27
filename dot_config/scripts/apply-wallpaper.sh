#!/bin/bash
# apply-wallpaper.sh — Apply wallpaper to the focused monitor using swaybg
# Usage: apply-wallpaper.sh /path/to/image.png

LOG="/tmp/wallpaper-apply.log"
exec > >(tee -a "$LOG") 2>&1
echo "--- $(date) ---"
echo "Arguments: $@"

IMAGE="$1"

# 1. Normalize path
if [ -z "$IMAGE" ]; then
    echo "Error: No image provided"
    exit 1
fi

if [ -f "$IMAGE" ]; then
    IMAGE=$(realpath "$IMAGE")
    echo "Resolved path: $IMAGE"
    if [ ! -s "$IMAGE" ]; then
        echo "Error: File is empty (0 bytes): $IMAGE"
        exit 1
    fi
else
    echo "Error: File not found: $IMAGE"
    exit 1
fi

STATE="$HOME/.config/hypr/wallpaper-state.conf"
EXTRACT="$HOME/.config/scripts/extract-colors.py"
PALETTE="$HOME/.config/quickshell/.palette"
PIDDIR="/tmp/swaybg-pids"
mkdir -p "$PIDDIR" || true

# 2. Detect focused monitor
FOCUSED=$(hyprctl monitors -j | jq -r '.[] | select(.focused==true) | .name')
ALL_MONS=$(hyprctl monitors -j | jq -r '.[].name')
[ -z "$FOCUSED" ] && FOCUSED=$(echo "$ALL_MONS" | head -1)
echo "Monitor: $FOCUSED"

# 3. Load existing state
declare -A STATE_MAP
if [ -f "$STATE" ]; then
    while IFS='=' read -r mon wp; do
        mon=$(echo "$mon" | xargs)
        wp=$(echo "$wp" | xargs)
        [ -n "$mon" ] && STATE_MAP["$mon"]="$wp"
    done < "$STATE"
fi

# 4. Update focused monitor
STATE_MAP["$FOCUSED"]="$IMAGE"

# 5. Ensure all connected monitors have a wallpaper
for mon in $ALL_MONS; do
    [ -z "${STATE_MAP[$mon]}" ] && STATE_MAP["$mon"]="$IMAGE"
done

# 6. Save persistent state
mkdir -p "$(dirname "$STATE")"
> "$STATE"
for mon in "${!STATE_MAP[@]}"; do
    echo "$mon=${STATE_MAP[$mon]}" >> "$STATE"
done

# 7. Kill old swaybg for this monitor and start new one
if [ -f "$PIDDIR/$FOCUSED" ]; then
    kill "$(cat "$PIDDIR/$FOCUSED")" 2>/dev/null
    sleep 0.1
fi
swaybg -o "$FOCUSED" -i "$IMAGE" -m fill &>/dev/null &
PID=$!
echo "swaybg PID: $PID"
echo $PID > "$PIDDIR/$FOCUSED"

# 8. Extract colors and generate palette
RAW="/tmp/qs-colors-raw"
magick "$IMAGE" -resize 200x200! -colors 8 -unique-colors -depth 8 txt:- \
    2>/dev/null | tail -n +2 | grep -oE '#[0-9A-Fa-f]{6}' | head -8 > "$RAW"

if [ -f "$EXTRACT" ] && [ -f "$RAW" ]; then
    python3 "$EXTRACT" "$RAW" "$PALETTE" 2>/dev/null
    echo "Palette updated."
fi
[ -f "$RAW" ] && rm -f "$RAW"

notify-send "Wallpaper" "$(basename "$IMAGE") → $FOCUSED" -i "$IMAGE" -t 3000
