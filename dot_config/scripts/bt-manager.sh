#!/bin/bash
# bt-manager.sh — Backend for Bluetooth Graph Panel (Robust JSON)

get_info() {
    local connected_mac=$(bluetoothctl devices Connected | head -n 1 | awk '{print $2}')
    
    if [ -n "$connected_mac" ]; then
        local dev_info=$(bluetoothctl info "$connected_mac")
        local dev_name=$(echo "$dev_info" | grep "Name:" | cut -d' ' -f2-)
        local battery=$(echo "$dev_info" | grep "Battery Percentage" | awk -F '[()]' '{print $2}' | tr -d ' %')
        [ -z "$battery" ] && battery=$(echo "$dev_info" | grep "Battery Percentage" | awk '{print $3}' | tr -d ' %')
        [ -z "$battery" ] && battery="N/A"
        
        local type=$(echo "$dev_info" | grep "Icon:" | awk '{print $2}')
        [ -z "$type" ] && type="unknown"
        
        name_esc=$(echo "$dev_name" | sed 's/"/\\"/g')
        printf '{"status":"connected","name":"%s","mac":"%s","battery":"%s","type":"%s"}\n' \
            "$name_esc" "$connected_mac" "$battery" "$type"
    else
        echo '{"status":"disconnected"}'
    fi
}

get_scan() {
    # Active scanning (brief)
    # Start scan in background if not already scanning
    if ! bluetoothctl show | grep -q "Discovering: yes"; then
        bluetoothctl scan on > /dev/null 2>&1 &
        local scan_pid=$!
        sleep 3.5
        kill $scan_pid > /dev/null 2>&1
    else
        sleep 2
    fi
    
    echo "["
    # Get all known devices and format as JSON
    bluetoothctl devices | head -n 15 | while read -r line; do
        mac=$(echo "$line" | awk '{print $2}')
        name=$(echo "$line" | cut -d' ' -f3-)
        [ -z "$mac" ] && continue
        
        name_esc=$(echo "$name" | sed 's/"/\\"/g')
        printf '  {"mac":"%s","name":"%s"},' "$mac" "$name_esc"
        echo
    done | sed '$ s/,$//'
    echo "]"
}

case "$1" in
    info) get_info ;;
    scan) get_scan ;;
    *) echo '{"error":"unknown_command"}' ;;
esac
