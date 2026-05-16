#!/bin/bash
# network-manager.sh — Backend for Wifi Graph Panel (Robust JSON)

get_info() {
    # Get basic connection info
    local active_data=$(nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY,DEVICE device wifi | grep "^yes" | head -n 1)
    
    if [ -n "$active_data" ]; then
        IFS=':' read -r active ssid signal security device <<< "$active_data"
        local mac=$(nmcli -t -f GENERAL.HWADDR device show "$device" | cut -d':' -f2-6)
        local ip_local=$(ip -4 addr show dev "$device" scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n 1)
        
        # Escape quotes for JSON
        ssid_esc=$(echo "$ssid" | sed 's/"/\\"/g')
        
        printf '{"status":"connected","ssid":"%s","signal":%d,"security":"%s","mac":"%s","local_ip":"%s"}\n' \
            "$ssid_esc" "$signal" "$security" "$mac" "$ip_local"
    else
        echo '{"status":"disconnected"}'
    fi
}

get_scan() {
    # Force a rescan to get fresh results
    nmcli device wifi rescan > /dev/null 2>&1
    sleep 0.5
    
    echo "["
    # Get list, skip header and empty SSIDs
    nmcli -t -f SSID,SIGNAL,SECURITY device wifi list | grep -v "^:" | sort -t':' -k2 -nr | head -n 12 | while read -r line; do
        # nmcli -t uses ':' as separator. We need to handle colons in SSID if possible, 
        # but nmcli -t doesn't escape them well. Using -f with specific order.
        # Format: SSID:SIGNAL:SECURITY
        
        # Extract signal (last but one field) and security (last field)
        local signal=$(echo "$line" | rev | cut -d':' -f2 | rev)
        local security=$(echo "$line" | rev | cut -d':' -f1 | rev)
        # SSID is everything before the signal
        local ssid=$(echo "$line" | sed "s/:$signal:$security$//")
        
        [ -z "$ssid" ] && continue
        
        ssid_esc=$(echo "$ssid" | sed 's/"/\\"/g')
        printf '  {"ssid":"%s","signal":%d,"security":"%s"},' "$ssid_esc" "$signal" "$security"
        echo
    done | sed '$ s/,$//'
    echo "]"
}

case "$1" in
    info) get_info ;;
    scan) get_scan ;;
    *) echo '{"error":"unknown_command"}' ;;
esac
