#!/bin/bash
# get-wifi-pass.sh - Fetch WiFi password using sudo

set -euo pipefail

SSID="${1:-}"
PASSWORD=""

if [[ -z "$SSID" ]]; then
    printf 'Error: Wi-Fi network name is required.\n' >&2
    exit 64
fi

IFS= read -r PASSWORD || true
if [[ -z "$PASSWORD" ]]; then
    printf 'Error: sudo password is required.\n' >&2
    exit 64
fi

if ! printf '%s\n' "$PASSWORD" | sudo -S nmcli -s -g 802-11-wireless-security.psk connection show "$SSID" --show-secrets 2>/dev/null; then
    printf 'Error: Unable to read the Wi-Fi password.\n' >&2
    exit 1
fi
