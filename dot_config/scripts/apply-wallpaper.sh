#!/bin/bash
# apply-wallpaper.sh — Apply wallpaper to the focused monitor using swaybg
# Usage: apply-wallpaper.sh <relative-approved-image>

set -euo pipefail
SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
[[ "$SCRIPT_DIR" == "${BASH_SOURCE[0]}" ]] && SCRIPT_DIR="."
source "$SCRIPT_DIR/runtime-paths.sh"
runtime_paths_load
die() { printf 'Error: %s\n' "$1" >&2; exit 1; }

IMAGE="${1:-}"
[[ -n "$IMAGE" ]] || die "No wallpaper path provided."
[[ "$IMAGE" != /* ]] || die "Wallpaper path must be relative to the approved root."
[[ "/$IMAGE/" != *"/../"* ]] || die "Wallpaper path traversal is not allowed."
command -v realpath >/dev/null 2>&1 || die "Required command unavailable: realpath"
ROOT="$(realpath -e "$RUNTIME_PATHS_WALLPAPER_ROOT")" || die "Approved wallpaper root does not exist."
IMAGE="$(realpath -e "$ROOT/$IMAGE")" || die "Wallpaper file does not exist."
[[ "$IMAGE" == "$ROOT"/* ]] || die "Wallpaper path resolves outside the approved root."
[[ -s "$IMAGE" ]] || die "Wallpaper file is empty."
command -v hyprctl >/dev/null 2>&1 || die "Required command unavailable: hyprctl"
command -v jq >/dev/null 2>&1 || die "Required command unavailable: jq"

STATE="$RUNTIME_PATHS_CONFIG_HOME/hypr/wallpaper-state.conf"
EXTRACT="$RUNTIME_PATHS_CONFIG_HOME/scripts/extract-colors.py"
PALETTE="$RUNTIME_PATHS_CONFIG_HOME/quickshell/.palette"
PIDDIR="$RUNTIME_PATHS_RUNTIME_DIR/swaybg-pids"
mkdir -p "$PIDDIR"

# 1. Detect focused monitor
if ! FOCUSED=$(hyprctl monitors -j | jq -r '.[] | select(.focused==true) | .name'); then
    die "Unable to query monitors."
fi
if ! ALL_MONS=$(hyprctl monitors -j | jq -r '.[].name'); then
    die "Unable to query monitors."
fi
[ -z "$FOCUSED" ] && FOCUSED=$(echo "$ALL_MONS" | head -1)
echo "Monitor: $FOCUSED"

# 2. Load existing state
declare -A STATE_MAP
if [ -f "$STATE" ]; then
    while IFS='=' read -r mon wp; do
        mon=$(echo "$mon" | xargs)
        wp=$(echo "$wp" | xargs)
        [ -n "$mon" ] && STATE_MAP["$mon"]="$wp"
    done < "$STATE"
fi

# 3. Update focused monitor and connected monitors
STATE_MAP["$FOCUSED"]="$IMAGE"
for mon in $ALL_MONS; do
    [ -z "${STATE_MAP[$mon]}" ] && STATE_MAP["$mon"]="$IMAGE"
done

# 4. Save persistent state
mkdir -p "$(dirname "$STATE")"
> "$STATE"
for mon in "${!STATE_MAP[@]}"; do
    echo "$mon=${STATE_MAP[$mon]}" >> "$STATE"
done

# 5. Kill old swaybg for this monitor and start new one
if [ -f "$PIDDIR/$FOCUSED" ]; then
    kill "$(cat "$PIDDIR/$FOCUSED")" 2>/dev/null || true
fi
swaybg -o "$FOCUSED" -i "$IMAGE" -m fill &>/dev/null &
PID=$!
echo "swaybg PID: $PID"
echo $PID > "$PIDDIR/$FOCUSED"

# 6. Extract colors and generate palette
RAW="$RUNTIME_PATHS_RUNTIME_DIR/qs-colors-raw"
magick "$IMAGE" -resize 200x200! -colors 8 -unique-colors -depth 8 txt:- \
    2>/dev/null | tail -n +2 | grep -oE '#[0-9A-Fa-f]{6}' | head -8 > "$RAW"

if [ -f "$EXTRACT" ] && [ -f "$RAW" ]; then
    python3 "$EXTRACT" "$RAW" "$PALETTE" 2>/dev/null
    echo "Palette updated."
fi
[ -f "$RAW" ] && rm -f "$RAW"

notify-send "Wallpaper" "$(basename "$IMAGE") → $FOCUSED" -i "$IMAGE" -t 3000
