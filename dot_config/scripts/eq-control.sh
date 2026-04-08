#!/bin/bash
# eq-control.sh — High-Performance PipeWire 10-Band Equalizer Controller
# Architectural approach: Native Filter Chain with real-time parameter updates.

ACTION="$1"
VAL1="$2" # Band index (0-9) OR Preset name
VAL2="$3" # Gain in dB (-12 to 12)

# Frequencies for reference: 31, 62, 125, 250, 500, 1k, 2k, 4k, 8k, 16k
# PipeWire node name: effect_input.eq10

# Ensure the equalizer is running
check_eq() {
    if ! pw-dump | grep -q "effect_input.eq10"; then
        echo "Equalizer not found. Initializing..."
        # We don't restart PipeWire; we just let the user know they might need to restart
        # or we could try to load it dynamically if pw-cli was cooperative.
        # But since we put it in conf.d, a restart is the cleanest way.
        notify-send -u critical "Audio Manager" "Equalizer backend not active. Please run: systemctl --user restart pipewire"
        return 1
    fi
    return 0
}

case "$ACTION" in
    set-band)
        BAND_IDX="$VAL1"
        GAIN="$VAL2"
        
        # Validation
        if [[ ! "$BAND_IDX" =~ ^[0-9]$ ]]; then exit 1; fi
        
        # Find the node ID for the specific band. 
        # In our config, they are named eq_band_0, eq_band_1, etc.
        # We use pw-cli to set the Gain property.
        NODE_NAME="eq_band_$BAND_IDX"
        
        # Get Node ID from pw-dump (fastest reliable way)
        NODE_ID=$(pw-dump | jq -r ".[] | select(.info.props[\"node.name\"] == \"$NODE_NAME\") | .id" | head -n 1)
        
        if [ -n "$NODE_ID" ]; then
            # Set the Gain parameter via pw-cli
            # Param ID 2 is usually 'Props'
            pw-cli s "$NODE_ID" Props "{ \"control\": [ { \"name\": \"Gain\", \"value\": $GAIN } ] }" &>/dev/null
            # Also update the metadata for state persistence if needed
            echo "Band $BAND_IDX -> $GAIN dB" > /tmp/qs-eq-$BAND_IDX
        fi
        ;;

    set-preset)
        PRESET=$(echo "$VAL1" | tr '[:upper:]' '[:lower:]')
        case "$PRESET" in
            flat)   gains=(0 0 0 0 0 0 0 0 0 0) ;;
            bass)   gains=(12 10 6 2 0 -2 -4 -6 -8 -10) ;;
            treble) gains=(-8 -6 -4 -2 0 2 6 9 11 12) ;;
            rock)   gains=(9 7 4 -1 -3 -1 3 6 8 9) ;;
            pop)    gains=(-3 -1 2 5 8 7 4 1 -1 -3) ;;
            jazz)   gains=(7 5 3 5 -1 -1 2 4 6 7) ;;
            *)      gains=(0 0 0 0 0 0 0 0 0 0) ;;
        esac
        
        for i in "${!gains[@]}"; do
            $0 set-band "$i" "${gains[$i]}"
        done
        notify-send -t 1000 -i audio-speakers "Audio Manager" "Preset Applied: $VAL1"
        ;;
esac
