#!/usr/bin/env bash
runtime_paths_load() { : "${HOME:?HOME must be set}"; RUNTIME_PATHS_CONFIG_HOME="${QS_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}"; RUNTIME_PATHS_RUNTIME_DIR="${QS_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/tmp}}"; RUNTIME_PATHS_WALLPAPER_ROOT="${QS_WALLPAPER_ROOT:-${XDG_PICTURES_DIR:-$HOME/Pictures}/wallpapers}"; RUNTIME_PATHS_SCRIPTS_DIR="$RUNTIME_PATHS_CONFIG_HOME/scripts"; }
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    set -euo pipefail; runtime_paths_load
    case "${1:-}" in
        config) printf '%s\n' "$RUNTIME_PATHS_CONFIG_HOME" ;;
        runtime) printf '%s\n' "$RUNTIME_PATHS_RUNTIME_DIR" ;;
        wallpaper) printf '%s\n' "$RUNTIME_PATHS_WALLPAPER_ROOT" ;;
        *) printf 'Usage: %s [config|runtime|wallpaper]\n' "$0" >&2; exit 64 ;;
    esac
fi
