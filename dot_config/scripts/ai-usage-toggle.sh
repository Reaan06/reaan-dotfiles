#!/bin/bash
# ai-usage-toggle.sh - Toggle the AI Usage panel on the focused monitor.

set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
[[ "$SCRIPT_DIR" == "${BASH_SOURCE[0]}" ]] && SCRIPT_DIR="."
source "$SCRIPT_DIR/runtime-paths.sh"
runtime_paths_load
RTDIR="$RUNTIME_PATHS_RUNTIME_DIR"
FILE="$RTDIR/qs-ai-usage"
FOCUSED="$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name' | head -n 1)"
REQUESTED_MONITOR="${2:-}"
MONITOR="${REQUESTED_MONITOR:-$FOCUSED}"

case "${1:-}" in
    toggle)
        state=""
        current_monitor=""
        if [[ -f "$FILE" ]]; then
            read -r state current_monitor < "$FILE" || true
        fi
        if [[ "$state" == "visible" && "$current_monitor" == "$MONITOR" ]]; then
            printf 'hidden %s\n' "$MONITOR" > "$FILE"
        else
            printf 'visible %s\n' "$MONITOR" > "$FILE"
        fi
        ;;
    show)
        printf 'visible %s\n' "$MONITOR" > "$FILE"
        ;;
    hide)
        printf 'hidden %s\n' "$MONITOR" > "$FILE"
        ;;
    *)
        printf 'Usage: ai-usage-toggle.sh {toggle|show|hide}\n' >&2
        exit 64
        ;;
esac
