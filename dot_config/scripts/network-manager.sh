#!/bin/bash
# network-manager.sh — Backend for Wifi Graph Panel (Robust JSON)

# nmcli -t uses ':' separators; SSID is last and may contain colons.
parse_info_line() {
    local line="$1"
    ACTIVE="${line%%:*}"; line="${line#*:}"
    SIGNAL="${line%%:*}"; line="${line#*:}"
    SECURITY="${line%%:*}"; line="${line#*:}"
    DEVICE="${line%%:*}"; line="${line#*:}"
    SSID="${line}"
}

parse_scan_line() {
    local line="$1"
    SIGNAL="${line%%:*}"; line="${line#*:}"
    SECURITY="${line%%:*}"; line="${line#*:}"
    FREQ="${line%%:*}"; line="${line#*:}"
    CHAN="${line%%:*}"; line="${line#*:}"
    RATE="${line%%:*}"; line="${line#*:}"
    ACTIVE="${line%%:*}"; line="${line#*:}"
    SSID="${line}"
}

get_info() {
    local active_data
    active_data=$(nmcli -t -f ACTIVE,SIGNAL,SECURITY,DEVICE,SSID device wifi 2>/dev/null | grep "^yes" | head -n 1)

    if [ -n "$active_data" ]; then
        parse_info_line "$active_data"

        local mac ip_local
        mac=$(nmcli -t -f GENERAL.HWADDR device show "$DEVICE" 2>/dev/null | head -n 1 | cut -d':' -f2- | xargs)
        ip_local=$(ip -4 addr show dev "$DEVICE" scope global 2>/dev/null | awk '/inet / {print $2}' | head -n 1 | cut -d/ -f1)

        jq -n \
            --arg ssid "$SSID" \
            --argjson signal "${SIGNAL:-0}" \
            --arg security "$SECURITY" \
            --arg mac "$mac" \
            --arg ip_local "$ip_local" \
            '{status: "connected", ssid: $ssid, signal: $signal, security: $security, mac: $mac, local_ip: $ip_local}'
    else
        echo '{"status":"disconnected"}'
    fi
}

get_scan() {
    local -a saved_ssids_arr=()
    mapfile -t saved_ssids_arr < <(nmcli -t -f NAME connection show 2>/dev/null)

    local json_lines=()
    local line signal security freq chan rate active ssid band freq_num known

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        parse_scan_line "$line"
        [ -z "$SSID" ] && continue

        known=false
        for s in "${saved_ssids_arr[@]}"; do
            if [[ "$s" == "$SSID" ]]; then
                known=true
                break
            fi
        done

        band="2.4 GHz"
        freq_num="${FREQ//[!0-9]/}"
        if [ -n "$freq_num" ] && [ "$freq_num" -gt 5000 ]; then
            band="5 GHz"
        fi

        json_lines+=("$(
            jq -n \
                --arg ssid "$SSID" \
                --argjson signal "${SIGNAL:-0}" \
                --arg security "$SECURITY" \
                --arg band "$band" \
                --arg chan "$CHAN" \
                --arg rate "$RATE" \
                --argjson known "$known" \
                '{ssid: $ssid, signal: $signal, security: $security, band: $band, chan: $chan, rate: $rate, known: $known}'
        )")
    done < <(
        nmcli -t -f SIGNAL,SECURITY,FREQ,CHAN,RATE,ACTIVE,SSID device wifi list --rescan yes 2>/dev/null \
            | grep -v "^:" \
            | sort -t':' -k1 -nr \
            | head -n 20
    )

    if [ "${#json_lines[@]}" -eq 0 ]; then
        echo '[]'
        return
    fi

    printf '%s\n' "${json_lines[@]}" | jq -s '
        unique_by(.ssid)
        | sort_by(-(if .known then 1 else 0 end), -.signal)
        | .[0:12]'
}

case "$1" in
    info) get_info ;;
    scan) get_scan ;;
    *) echo '{"error":"unknown_command"}' ;;
esac
