#!/bin/bash
# eq-control.sh — Real PipeWire 10-Band Equalizer Controller
# Uses pw-cli for live parameter updates and pactl for routing.

ACTION="$1"
VAL1="$2"   # Band index (0-9) OR Preset name
VAL2="$3"   # Gain in dB (-12 to 12)

EQ_STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/qs-eq"
mkdir -p "$EQ_STATE_DIR"

# ─── Helpers ───────────────────────────────────────────────────────────────────

get_node_id() {
    pw-dump | jq -r '.[] | select(.info.props["node.name"] == "effect_input.eq10") | .id' | head -n1
}

apply_band_pwcli() {
    local band="$1"
    local gain="$2"
    local node_id=$(get_node_id)
    
    if [ -n "$node_id" ]; then
        pw-cli s "$node_id" Props "{ \"params\": [ \"eq_band_${band}:Gain\", $gain ] }" &>/dev/null
    fi
}

route_to_eq() {
    local eq_sink="effect_input.eq10"
    if ! pactl list sinks short | grep -q "$eq_sink"; then
        return
    fi
    pactl set-default-sink "$eq_sink" 2>/dev/null
    pactl list sink-inputs short | cut -f1 | while read -r id; do
        pactl move-sink-input "$id" "$eq_sink" 2>/dev/null
    done
}

# ─── Main ──────────────────────────────────────────────────────────────────────

case "$ACTION" in
    set-band)
        BAND_IDX="$VAL1"
        GAIN="$VAL2"
        if [[ ! "$BAND_IDX" =~ ^[0-9]$ ]]; then exit 1; fi
        GAIN=$(python3 -c "print(max(-20.0, min(20.0, float('$GAIN'))))")
        apply_band_pwcli "$BAND_IDX" "$GAIN"
        echo "$GAIN" > "$EQ_STATE_DIR/band-$BAND_IDX"
        ;;

    set-preset)
        PRESET_NAME="$VAL1"
        # Corrected Standard 10-Band Curves
        case "${PRESET_NAME,,}" in
            flat)    gains=(0 0 0 0 0 0 0 0 0 0) ;;
            bass)    gains=(12 10 7 3 0 0 0 0 0 0) ;; 
            treble)  gains=(0 0 0 0 0 0 3 7 10 12) ;;
            rock)    gains=(8 5 -2 -5 -7 -4 3 6 8 11) ;;
            pop)     gains=(-2 2 5 7 4 -2 -3 -3 -2 -2) ;;
            jazz)    gains=(4 3 1 3 -3 -3 0 2 4 5) ;;
            vocal)   gains=(-6 -3 0 4 10 12 9 4 0 -4) ;;
            classic) gains=(6 5 4 2 -3 -3 0 3 5 6) ;;
            *)       gains=(0 0 0 0 0 0 0 0 0 0) ;;
        esac
        
        for i in "${!gains[@]}"; do
            apply_band_pwcli "$i" "${gains[$i]}"
            echo "${gains[$i]}" > "$EQ_STATE_DIR/band-$i"
        done
        
        route_to_eq
        echo "$PRESET_NAME" > "$EQ_STATE_DIR/preset"
        notify-send -t 1500 -i audio-speakers "Audio EQ" "Preset: $PRESET_NAME" &>/dev/null
        ;;

    route)
        route_to_eq
        ;;

    start)
        route_to_eq
        ;;

    status)
        echo "pipewire"
        ;;
esac
