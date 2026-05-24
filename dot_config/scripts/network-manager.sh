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
    
    # Get saved connections to identify "known" networks
    local saved_ssids=$(nmcli -t -f NAME connection show)

    echo "["
    # Get list with tech specs, skip header and empty SSIDs
    # Format: SSID:SIGNAL:SECURITY:FREQ:CHAN:RATE:ACTIVE
    nmcli -t -f SSID,SIGNAL,SECURITY,FREQ,CHAN,RATE,ACTIVE device wifi list | grep -v "^:" | sort -t':' -k2 -nr | head -n 12 | while read -r line; do
        # Extract fields from the back to handle potential colons in SSID
        local active=$(echo "$line" | rev | cut -d':' -f1 | rev)
        local rate=$(echo "$line" | rev | cut -d':' -f2 | rev)
        local chan=$(echo "$line" | rev | cut -d':' -f3 | rev)
        local freq=$(echo "$line" | rev | cut -d':' -f4 | rev)
        local security=$(echo "$line" | rev | cut -d':' -f5 | rev)
        local signal=$(echo "$line" | rev | cut -d':' -f6 | rev)
        
        # SSID is everything before the signal
        # Use sed to remove the suffix :SIGNAL:SECURITY:FREQ:CHAN:RATE:ACTIVE
        # We need to be careful with colons.
        local suffix=":$signal:$security:$freq:$chan:$rate:$active"
        local ssid=$(echo "$line" | sed "s/$(echo "$suffix" | sed 's/[]\/$*.^[]/\\&/g')$//")

        [ -z "$ssid" ] && continue
        
        # Determine if known
        local known="false"
        if echo "$saved_ssids" | grep -qFx "$ssid"; then
            known="true"
        fi

        # Convert frequency to Band
        local band="2.4 GHz"
        if [ "${freq//[!0-9]/}" -gt 5000 ] 2>/dev/null; then
            band="5 GHz"
        fi

        ssid_esc=$(echo "$ssid" | sed 's/"/\\"/g')
        printf '  {"ssid":"%s","signal":%d,"security":"%s","band":"%s","chan":"%s","rate":"%s","known":%s},' \
            "$ssid_esc" "$signal" "$security" "$band" "$chan" "$rate" "$known"
        echo
    done | sed '$ s/,$//'
    echo "]"
}

case "$1" in
    info) get_info ;;
    scan) get_scan ;;
    *) echo '{"error":"unknown_command"}' ;;
esac
