#!/bin/bash
# eq-control.sh — Real PipeWire/EasyEffects 10-Band Equalizer Controller
# Uses EasyEffects via DBus for real audio processing.
# Falls back to pw-cli filter-chain if EasyEffects is not running.

ACTION="$1"
VAL1="$2"   # Band index (0-9) OR Preset name
VAL2="$3"   # Gain in dB (-12 to 12)

EQ_PRESET_DIR="$HOME/.config/easyeffects/output"
EQ_STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/qs-eq-state"
EQ_FILTER_CHAIN_CONF="$HOME/.config/pipewire/filter-chain.conf.d/eq10.conf"

# ─── Helpers ───────────────────────────────────────────────────────────────────

is_easyeffects_running() {
    pgrep -x easyeffects &>/dev/null
}

# Apply gain via EasyEffects DBus (parametric equalizer, band 0-9)
# EasyEffects uses com.github.wwmm.easyeffects
apply_band_easyeffects() {
    local band="$1"
    local gain="$2"
    # EasyEffects band names: band0..band9
    dbus-send --session --print-reply \
        --dest=com.github.wwmm.easyeffects \
        /com/github/wwmm/easyeffects/sink/equalizer \
        com.github.wwmm.easyeffects.Equalizer.SetBand \
        "int32:$band" "double:$gain" &>/dev/null
    if [ $? -ne 0 ]; then
        # Fallback: write to EasyEffects JSON preset directly and reload
        apply_band_json "$band" "$gain"
    fi
}

# Fallback: modify the active EasyEffects preset JSON and signal reload
apply_band_json() {
    local band="$1"
    local gain="$2"
    local preset_file="$EQ_PRESET_DIR/qs-dynamic.json"

    # Create default preset if it doesn't exist
    if [ ! -f "$preset_file" ]; then
        mkdir -p "$EQ_PRESET_DIR"
        cat > "$preset_file" << 'PRESET_EOF'
{
  "output": {
    "blocklist": [],
    "equalizer#0": {
      "balance": 0.0,
      "band0": {"frequency": 31.0, "gain": 0.0, "mode": "APO (DR)", "mute": false, "q": 4.36, "slope": "x1", "solo": false, "type": "Bell", "width": 4.0},
      "band1": {"frequency": 62.0, "gain": 0.0, "mode": "APO (DR)", "mute": false, "q": 4.36, "slope": "x1", "solo": false, "type": "Bell", "width": 4.0},
      "band2": {"frequency": 125.0, "gain": 0.0, "mode": "APO (DR)", "mute": false, "q": 4.36, "slope": "x1", "solo": false, "type": "Bell", "width": 4.0},
      "band3": {"frequency": 250.0, "gain": 0.0, "mode": "APO (DR)", "mute": false, "q": 4.36, "slope": "x1", "solo": false, "type": "Bell", "width": 4.0},
      "band4": {"frequency": 500.0, "gain": 0.0, "mode": "APO (DR)", "mute": false, "q": 4.36, "slope": "x1", "solo": false, "type": "Bell", "width": 4.0},
      "band5": {"frequency": 1000.0, "gain": 0.0, "mode": "APO (DR)", "mute": false, "q": 4.36, "slope": "x1", "solo": false, "type": "Bell", "width": 4.0},
      "band6": {"frequency": 2000.0, "gain": 0.0, "mode": "APO (DR)", "mute": false, "q": 4.36, "slope": "x1", "solo": false, "type": "Bell", "width": 4.0},
      "band7": {"frequency": 4000.0, "gain": 0.0, "mode": "APO (DR)", "mute": false, "q": 4.36, "slope": "x1", "solo": false, "type": "Bell", "width": 4.0},
      "band8": {"frequency": 8000.0, "gain": 0.0, "mode": "APO (DR)", "mute": false, "q": 4.36, "slope": "x1", "solo": false, "type": "Bell", "width": 4.0},
      "band9": {"frequency": 16000.0, "gain": 0.0, "mode": "APO (DR)", "mute": false, "q": 4.36, "slope": "x1", "solo": false, "type": "Bell", "width": 4.0},
      "input-gain": 0.0,
      "mode": "IIR",
      "num-bands": 10,
      "output-gain": 0.0,
      "split-channels": false
    },
    "plugins_order": ["equalizer#0"]
  }
}
PRESET_EOF
    fi

    # Use python3 to modify the specific band gain in the JSON
    python3 - "$preset_file" "$band" "$gain" << 'PYEOF'
import json, sys
f, band, gain = sys.argv[1], int(sys.argv[2]), float(sys.argv[3])
with open(f) as fp:
    d = json.load(fp)
d["output"]["equalizer#0"][f"band{band}"]["gain"] = gain
with open(f, "w") as fp:
    json.dump(d, fp, indent=2)
PYEOF

    # Signal EasyEffects to load the preset
    dbus-send --session \
        --dest=com.github.wwmm.easyeffects \
        /com/github/wwmm/easyeffects \
        com.github.wwmm.easyeffects.Application.LoadOutputPreset \
        "string:qs-dynamic" &>/dev/null 2>&1 || true
}

# pw-cli filter-chain fallback for when EasyEffects is completely absent
apply_band_pwcli() {
    local band="$1"
    local gain="$2"
    local node_name="eq_band_$band"
    local node_id
    node_id=$(pw-dump 2>/dev/null | python3 -c "
import json,sys
data=json.load(sys.stdin)
for n in data:
    if 'Node' in n.get('type',''):
        props=n.get('info',{}).get('props',{})
        if props.get('node.name','') == '$node_name':
            print(n['id'])
            break
" 2>/dev/null)
    if [ -n "$node_id" ]; then
        pw-cli s "$node_id" Props "{ \"control\": [ { \"name\": \"Gain\", \"value\": $gain } ] }" &>/dev/null
    fi
}

save_state() {
    # Save current band states to runtime file
    local gains=("$@")
    printf "%s\n" "${gains[@]}" > "$EQ_STATE_FILE"
}

# ─── Main ──────────────────────────────────────────────────────────────────────

case "$ACTION" in
    set-band)
        BAND_IDX="$VAL1"
        GAIN="$VAL2"
        if [[ ! "$BAND_IDX" =~ ^[0-9]$ ]]; then exit 1; fi
        # Clamp gain to -12..12
        GAIN=$(python3 -c "print(max(-12.0, min(12.0, float('$GAIN'))))" 2>/dev/null || echo "$GAIN")

        if is_easyeffects_running; then
            apply_band_easyeffects "$BAND_IDX" "$GAIN"
        else
            apply_band_pwcli "$BAND_IDX" "$GAIN"
        fi
        echo "$GAIN" > "${XDG_RUNTIME_DIR:-/tmp}/qs-eq-band-$BAND_IDX"
        ;;

    set-preset)
        PRESET_NAME="$VAL1"
        PRESET=$(echo "$VAL1" | tr '[:upper:]' '[:lower:]')
        case "$PRESET" in
            flat)    gains=(0 0 0 0 0 0 0 0 0 0) ;;
            bass)    gains=(10 8 6 3 1 0 -1 -2 -3 -4) ;;
            treble)  gains=(-4 -3 -2 -1 0 2 5 8 10 12) ;;
            rock)    gains=(8 6 4 -1 -3 -1 3 5 7 8) ;;
            pop)     gains=(-2 -1 2 5 7 6 3 1 -1 -2) ;;
            jazz)    gains=(6 4 2 4 -1 -1 2 4 5 6) ;;
            vocal)   gains=(-4 -2 0 2 5 6 5 2 0 -2) ;;
            classic) gains=(5 4 3 2 0 0 -2 -3 -4 -5) ;;
            *)       gains=(0 0 0 0 0 0 0 0 0 0) ;;
        esac
        for i in "${!gains[@]}"; do
            "$0" set-band "$i" "${gains[$i]}"
        done
        notify-send -t 1200 -i audio-speakers "Audio EQ" "Preset: $PRESET_NAME" &>/dev/null 2>&1 || true
        ;;

    start-easyeffects)
        if ! is_easyeffects_running; then
            easyeffects --gapplication-service &
            sleep 1
            notify-send -t 1500 "Audio EQ" "EasyEffects iniciado" &>/dev/null 2>&1 || true
        fi
        ;;

    status)
        if is_easyeffects_running; then
            echo "easyeffects"
        else
            # Check for pw filter-chain
            if pw-dump 2>/dev/null | grep -q "eq_band_0"; then
                echo "pwcli"
            else
                echo "none"
            fi
        fi
        ;;
esac
