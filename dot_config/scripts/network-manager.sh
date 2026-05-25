#!/bin/bash
# network-manager.sh — Backend for Wifi Graph Panel (Robust JSON)

get_info() {
    # Get basic connection info. Put SSID last to handle potential colons robustly.
    local active_data=$(nmcli -t -f ACTIVE,SIGNAL,SECURITY,DEVICE,SSID device wifi | grep "^yes" | head -n 1)
    
    if [ -n "$active_data" ]; then
        IFS=':' read -r active signal security device ssid <<< "$active_data"
        
        # Get MAC address (fix extraction to get full address)
        local mac=$(nmcli -t -f GENERAL.HWADDR device show "$device" | cut -d':' -f2-)
        
        # Get local IP
        local ip_local=$(ip -4 addr show dev "$device" scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n 1)
        
        # Use jq for robust JSON generation
        jq -n \
            --arg ssid "$ssid" \
            --argjson signal "${signal:-0}" \
            --arg security "$security" \
            --arg mac "$mac" \
            --arg ip_local "$ip_local" \
            '{status: "connected", ssid: $ssid, signal: $signal, security: $security, mac: $mac, local_ip: $ip_local}'
    else
        echo '{"status":"disconnected"}'
    fi
}

get_scan() {
    # Force a rescan to get fresh results
    nmcli device wifi rescan > /dev/null 2>&1
    sleep 0.5
    
    # Get saved connections to identify "known" networks
    mapfile -t saved_ssids_arr < <(nmcli -t -f NAME connection show)

    # Get list with tech specs. SIGNAL first for sorting, SSID last for colon robustness.
    # Format: SIGNAL:SECURITY:FREQ:CHAN:RATE:ACTIVE:SSID
    nmcli -t -f SIGNAL,SECURITY,FREQ,CHAN,RATE,ACTIVE,SSID device wifi list | grep -v "^:" | sort -t':' -k1 -nr | head -n 12 | while IFS=":" read -r signal security freq chan rate active ssid; do
        [ -z "$ssid" ] && continue
        
        # Determine if known
        local known=false
        for s in "${saved_ssids_arr[@]}"; do
            if [[ "$s" == "$ssid" ]]; then
                known=true
                break
            fi
        done

        # Convert frequency to Band
        local band="2.4 GHz"
        local freq_num="${freq//[!0-9]/}"
        if [ -n "$freq_num" ] && [ "$freq_num" -gt 5000 ]; then
            band="5 GHz"
        fi

        # Output individual objects
        jq -n \
            --arg ssid "$ssid" \
            --argjson signal "${signal:-0}" \
            --arg security "$security" \
            --arg band "$band" \
            --arg chan "$chan" \
            --arg rate "$rate" \
            --argjson known "$known" \
            '{ssid: $ssid, signal: $signal, security: $security, band: $band, chan: $chan, rate: $rate, known: $known}'
    done | jq -s '.' # Slurp all objects into a JSON array
}

case "$1" in
    info) get_info ;;
    scan) get_scan ;;
    *) echo '{"error":"unknown_command"}' ;;
esac
