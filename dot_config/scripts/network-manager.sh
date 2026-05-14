#!/bin/bash
# network-manager.sh — Backend for Wifi Graph Panel
# Usage: network-manager.sh [info|scan|ip_public|ip_local]

get_info() {
    # Detect connection more robustly using a unique separator for nmcli
    local active_conn=$(nmcli -t -m multiline -f ACTIVE,SSID,SIGNAL,SECURITY,DEVICE device wifi | grep -A 4 "^ACTIVE:yes" | tr '\n' '|')
    
    if [[ "$active_conn" == *"ACTIVE:yes"* ]]; then
        local ssid=$(echo "$active_conn" | grep -o "SSID:[^|]*" | cut -d':' -f2)
        local signal=$(echo "$active_conn" | grep -o "SIGNAL:[^|]*" | cut -d':' -f2)
        local security=$(echo "$active_conn" | grep -o "SECURITY:[^|]*" | cut -d':' -f2)
        local device=$(echo "$active_conn" | grep -o "DEVICE:[^|]*" | cut -d':' -f2)
        local mac=$(nmcli -t -f GENERAL.HWADDR device show "$device" | cut -d':' -f2-6)
        
        echo "connected|$ssid|$signal|$security|$mac"
    else
        echo "disconnected"
    fi
}

get_ip_local() {
    ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n 1
}

get_ip_public() {
    # Asynchronous friendly (caller should handle timeout or run in background)
    curl -s --connect-timeout 2 ifconfig.me || echo "Error"
}

get_scan() {
    # Scan for available networks (limit to top 5 for performance)
    nmcli -t -f ssid,signal,security device wifi list | head -n 5
}

case "$1" in
    info) get_info ;;
    ip_local) get_ip_local ;;
    ip_public) get_ip_public ;;
    scan) get_scan ;;
    *) echo "Usage: $0 [info|scan|ip_public|ip_local]" ;;
esac
