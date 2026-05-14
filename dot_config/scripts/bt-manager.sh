#!/bin/bash
# bt-manager.sh — Backend for Bluetooth Graph Panel
# Usage: bt-manager.sh [info|scan|devices]

get_info() {
    # Get connected device info using bluetoothctl
    local connected_mac=$(bluetoothctl devices Connected | head -n 1 | awk '{print $2}')
    
    if [ -n "$connected_mac" ]; then
        local dev_info=$(bluetoothctl info "$connected_mac")
        local dev_name=$(echo "$dev_info" | grep "Name:" | cut -d' ' -f2-)
        local battery=$(echo "$dev_info" | grep "Battery Percentage" | awk -F '[()]' '{print $2}' | tr -d ' %')
        [ -z "$battery" ] && battery=$(echo "$dev_info" | grep "Battery Percentage" | awk '{print $3}' | tr -d ' %')
        [ -z "$battery" ] && battery="N/A"
        
        local type=$(echo "$dev_info" | grep "Icon:" | awk '{print $2}')
        [ -z "$type" ] && type="unknown"
        
        echo "connected|$dev_name|$connected_mac|$battery|$type"
    else
        echo "disconnected"
    fi
}

get_devices() {
    # List paired devices
    bluetoothctl devices | head -n 5
}

get_scan() {
    # Trigger a short scan and return results
    # Note: bluetoothctl scan is a persistent process, so we just return discovered devices
    bluetoothctl devices | grep -v "Paired" | head -n 5
}

case "$1" in
    info) get_info ;;
    devices) get_devices ;;
    scan) get_scan ;;
    *) echo "Usage: $0 [info|scan|devices]" ;;
esac
