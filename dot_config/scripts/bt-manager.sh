#!/bin/bash
# bt-manager.sh — Backend for Bluetooth Graph Panel (Robust JSON)

get_info() {
    local connected_mac=$(bluetoothctl devices Connected | head -n 1 | awk '{print $2}')
    
    if [ -n "$connected_mac" ]; then
        local dev_info=$(bluetoothctl info "$connected_mac")
        local dev_name=$(echo "$dev_info" | grep "Name:" | sed 's/.*Name: //')
        local battery=$(echo "$dev_info" | grep "Battery Percentage" | awk -F '[()]' '{print $2}' | tr -d ' %')
        [ -z "$battery" ] && battery=$(echo "$dev_info" | grep "Battery Percentage" | awk '{print $3}' | tr -d ' %')
        [ -z "$battery" ] && battery="N/A"
        
        local icon=$(echo "$dev_info" | awk '/Icon:/ {print $2}')
        [ -z "$icon" ] && icon="bluetooth"
        
        jq -n --arg status "connected" \
            --arg name "$dev_name" \
            --arg mac "$connected_mac" \
            --arg battery "$battery" \
            --arg icon "$icon" \
            '{status: $status, name: $name, mac: $mac, battery: $battery, icon: $icon}'
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
    
    local items=""
    
    # Get all known devices and format as JSON
    while read -r _ mac name; do
        [ -z "$mac" ] && continue
        
        # Get detailed info for each device
        local dev_info=$(bluetoothctl info "$mac")
        local paired=false
        [[ "$dev_info" =~ "Paired: yes" ]] && paired=true
        local trusted=false
        [[ "$dev_info" =~ "Trusted: yes" ]] && trusted=true
        local icon=$(echo "$dev_info" | awk '/Icon:/ {print $2}')
        [ -z "$icon" ] && icon="bluetooth"
        
        # Collect data with tab delimiter for final jq processing
        items+="$mac	$name	$paired	$trusted	$icon"$'\n'
    done < <(bluetoothctl devices | head -n 15)
    
    echo -n "$items" | jq -R -s '
        split("\n") | map(select(length > 0) | split("\t") | {
            mac: .[0],
            name: .[1],
            paired: (.[2] == "true"),
            trusted: (.[3] == "true"),
            icon: .[4]
        })
    '
}

case "$1" in
    info) get_info ;;
    scan) get_scan ;;
    *) echo '{"error":"unknown_command"}' ;;
esac
