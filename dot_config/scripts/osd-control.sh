#!/bin/bash
# osd-control.sh — Change volume/brightness and trigger OSD
# Usage: osd-control.sh volume up|down|mute
#        osd-control.sh brightness up|down

SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
[[ "$SCRIPT_DIR" == "${BASH_SOURCE[0]}" ]] && SCRIPT_DIR="."
source "$SCRIPT_DIR/runtime-paths.sh"
runtime_paths_load
OSD_FILE="$RUNTIME_PATHS_RUNTIME_DIR/qs-osd"
TYPE="$1"
ACTION="$2"

case "$TYPE" in
    volume)
        case "$ACTION" in
            up)   pamixer -i 5 ;;
            down) pamixer -d 5 ;;
            mute) pamixer -t ;;
        esac
        VOL=$(pamixer --get-volume 2>/dev/null)
        MUTE=$(pamixer --get-mute 2>/dev/null)
        echo "volume $VOL $MUTE" > "$OSD_FILE"
        ;;
    brightness)
        case "$ACTION" in
            up)   brightnessctl set +5% ;;
            down) ~/.config/scripts/brightness-down.sh ;;
        esac
        BRI=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%')
        echo "brightness $BRI" > "$OSD_FILE"
        ;;
esac
