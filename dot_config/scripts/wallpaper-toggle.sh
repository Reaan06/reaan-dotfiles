#!/bin/bash
set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
[[ "$SCRIPT_DIR" == "${BASH_SOURCE[0]}" ]] && SCRIPT_DIR="."
source "$SCRIPT_DIR/runtime-paths.sh"
runtime_paths_load

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        printf 'Error: Required command unavailable: %s\n' "$1" >&2
        exit 1
    }
}

require_command hyprctl
require_command jq
STATE_FILE="$RUNTIME_PATHS_RUNTIME_DIR/qs-wallpaper-picker"
MONITOR=$(hyprctl monitors -j | jq -r ".[] | select(.focused==true) | .name")
[[ -n "$MONITOR" ]] || { printf 'Error: Unable to determine the focused monitor.\n' >&2; exit 1; }

if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE" | cut -d' ' -f1)" == "visible" ]; then
    echo "hidden $MONITOR" > "$STATE_FILE"
else
    echo "visible $MONITOR" > "$STATE_FILE"
fi
