#!/bin/bash
# bt-manager.sh — Backend for Bluetooth Graph Panel (Robust JSON)

_bt_norm_id() {
    echo "$1" | tr -d ':-' | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]'
}

_bt_field() {
    local info="$1" field="$2"
    echo "$info" | awk -v f="$field:" '$1 == f { sub(/^[^:]*:[[:space:]]*/, ""); print; exit }'
}

_bt_mac_like_name() {
    local name="$1" mac="$2"
    [ -z "$name" ] && return 0
    local n m
    n=$(_bt_norm_id "$name")
    m=$(_bt_norm_id "$mac")
    [ "$n" = "$m" ] && return 0
    local dashed upper
    dashed=$(echo "$mac" | tr ':' '-')
    upper=$(echo "$name" | tr '[:lower:]' '[:upper:]')
    [ "$upper" = "$(echo "$dashed" | tr '[:lower:]' '[:upper:]')" ] && return 0
    return 1
}

_bt_strip_ansi() {
    sed 's/\x1b\[[0-9;]*m//g'
}

# Populate associative array BT_DISC_NAMES[mac]=friendly name from scan stream.
_bt_collect_discovery_names() {
    local -n _out="$1"
    local line mac name rest

    while IFS= read -r line; do
        line=$(_bt_strip_ansi <<<"$line")

        if [[ "$line" =~ ^\[(NEW|CHG)\][[:space:]]+Device[[:space:]]+(([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2})[[:space:]]+Name:[[:space:]]+(.+)$ ]]; then
            mac="${BASH_REMATCH[2]}"
            name="${BASH_REMATCH[4]}"
            [ -n "$name" ] && _out["$mac"]="$name"
            continue
        fi

        if [[ "$line" =~ ^\[(NEW|CHG)\][[:space:]]+Device[[:space:]]+(([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2})[[:space:]]+Alias:[[:space:]]+(.+)$ ]]; then
            mac="${BASH_REMATCH[2]}"
            name="${BASH_REMATCH[4]}"
            if [ -n "$name" ] && ! _bt_mac_like_name "$name" "$mac"; then
                _out["$mac"]="$name"
            fi
            continue
        fi

        if [[ "$line" =~ ^\[NEW\][[:space:]]+Device[[:space:]]+(([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2})[[:space:]]+(.+)$ ]]; then
            mac="${BASH_REMATCH[1]}"
            rest="${BASH_REMATCH[3]}"
            if [ -n "$rest" ] && ! _bt_mac_like_name "$rest" "$mac"; then
                _out["$mac"]="$rest"
            fi
        fi
    done
}

resolve_bt_name() {
    local mac="$1" list_name="${2:-}" disc_name="${3:-}"
    local dev_info alias name candidate resolved=""

    dev_info=$(bluetoothctl info "$mac" 2>/dev/null)
    alias=$(_bt_field "$dev_info" "Alias")
    name=$(_bt_field "$dev_info" "Name")

    for candidate in "$alias" "$name" "$disc_name" "$list_name"; do
        [ -z "$candidate" ] && continue
        if ! _bt_mac_like_name "$candidate" "$mac"; then
            resolved="$candidate"
            break
        fi
    done

    if [ -z "$resolved" ]; then
        for candidate in "$disc_name" "$list_name" "$alias" "$name"; do
            [ -n "$candidate" ] && { resolved="$candidate"; break; }
        done
    fi

    if [ -z "$resolved" ]; then
        resolved=$(echo "$mac" | tr ':' '-')
    fi

    echo "$resolved"
}

get_info() {
    local connected_mac
    connected_mac=$(bluetoothctl devices Connected 2>/dev/null | head -n 1 | awk '{print $2}')

    if [ -n "$connected_mac" ]; then
        local dev_info list_name dev_name battery icon
        list_name=$(bluetoothctl devices Connected 2>/dev/null | head -n 1 | cut -d' ' -f3-)
        dev_info=$(bluetoothctl info "$connected_mac" 2>/dev/null)
        dev_name=$(resolve_bt_name "$connected_mac" "$list_name")
        battery=$(echo "$dev_info" | grep "Battery Percentage" | awk -F '[()]' '{print $2}' | tr -d ' %')
        [ -z "$battery" ] && battery=$(echo "$dev_info" | grep "Battery Percentage" | awk '{print $3}' | tr -d ' %')
        [ -z "$battery" ] && battery="N/A"

        icon=$(_bt_field "$dev_info" "Icon")
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
    declare -A BT_DISC_NAMES=()

    _bt_collect_discovery_names BT_DISC_NAMES < <(
        bluetoothctl --timeout 8 scan on 2>&1 | _bt_strip_ansi
    ) || true

    sleep 0.6

    local items=""

    while read -r line; do
        [[ "$line" =~ ^Device[[:space:]]+(([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2})[[:space:]]*(.*)$ ]] || continue
        local mac="${BASH_REMATCH[1]}"
        local list_name="${BASH_REMATCH[3]}"

        local dev_info paired=false trusted=false icon resolved_name disc_name
        disc_name="${BT_DISC_NAMES[$mac]:-}"
        dev_info=$(bluetoothctl info "$mac" 2>/dev/null)
        [[ "$dev_info" =~ "Paired: yes" ]] && paired=true
        [[ "$dev_info" =~ "Trusted: yes" ]] && trusted=true
        icon=$(_bt_field "$dev_info" "Icon")
        [ -z "$icon" ] && icon="bluetooth"

        resolved_name=$(resolve_bt_name "$mac" "$list_name" "$disc_name")
        if _bt_mac_like_name "$resolved_name" "$mac"; then
            sleep 0.2
            resolved_name=$(resolve_bt_name "$mac" "$list_name" "$disc_name")
        fi

        items+="$mac	$resolved_name	$paired	$trusted	$icon"$'\n'
    done < <(bluetoothctl devices 2>/dev/null | head -n 20)

    if [ -z "$items" ]; then
        echo '[]'
        return
    fi

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
