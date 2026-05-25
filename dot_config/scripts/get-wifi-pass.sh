#!/bin/bash
# get-wifi-pass.sh - Fetch WiFi password using sudo
SSID=$1
PASS=$2
echo "$PASS" | sudo -S nmcli -s -g 802-11-wireless-security.psk connection show "$SSID" --show-secrets 2>/dev/null
