#!/bin/bash
# app-volume.sh — Per-Application Audio Volume Controller via PipeWire/PulseAudio
# Usage:
#   app-volume.sh list                    → JSON array of active audio streams
#   app-volume.sh set <sink_input_id> <vol_0_to_100>
#   app-volume.sh mute <sink_input_id>
#   app-volume.sh unmute <sink_input_id>
#   app-volume.sh toggle-mute <sink_input_id>

ACTION="$1"

# App icon map (app name -> nerd font icon)
get_icon() {
    local name="${1,,}"
    case "$name" in
        *spotify*)   echo "󰓇" ;;
        *firefox*)   echo "󰈹" ;;
        *chrome*)    echo "󰊯" ;;
        *chromium*)  echo "󰊯" ;;
        *vlc*)       echo "󰕼" ;;
        *mpv*)       echo "" ;;
        *discord*)   echo "󰙯" ;;
        *telegram*)  echo "" ;;
        *teams*)     echo "󰊻" ;;
        *zoom*)      echo "󰊻" ;;
        *steam*)     echo "󰓓" ;;
        *rhythmbox*) echo "󰓃" ;;
        *amarok*)    echo "󰓃" ;;
        *elisa*)     echo "󰝚" ;;
        *clementine*)echo "󰝚" ;;
        *brave*)     echo "󰊯" ;;
        *obs*)       echo "󰐕" ;;
        *slack*)     echo "󰒱" ;;
        *)           echo "󰕾" ;;
    esac
}

case "$ACTION" in
    list)
        # Output JSON array of current sink-input streams
        python3 - << 'PYEOF'
import subprocess, json, re, os

try:
    result = subprocess.run(
        ["pactl", "list", "sink-inputs"],
        env={"LC_ALL": "C", **os.environ},
        capture_output=True, text=True
    )

    apps = []
    current = {}
    lines = result.stdout.split("\n")

    for line in lines:
        line = line.rstrip()
        # New sink-input block
        m = re.search(r'^Sink Input #(\d+)', line)
        if m:
            if current:
                apps.append(current)
            current = {"id": int(m.group(1)), "muted": False, "volume": 100, "name": "", "icon": "󰕾", "binary": ""}
            continue
        if not current:
            continue

        m = re.search(r'Mute: (yes|no)', line)
        if m:
            current["muted"] = (m.group(1) == "yes")
            continue

        # Volume line: Volume: front-left: 65536 / 100% / 0.00 dB, ...
        m = re.search(r'Volume:.*?(\d+)%', line)
        if m and "volume" not in current or current.get("volume") == 100:
            try:
                current["volume"] = int(m.group(1))
            except:
                pass
            continue

        # Application name
        m = re.search(r'application\.name = "(.*?)"', line)
        if m:
            current["name"] = m.group(1)
            continue

        # Binary / process binary
        m = re.search(r'application\.process\.binary = "(.*?)"', line)
        if m:
            current["binary"] = m.group(1)
            continue

        # Media name (song title, etc.)
        m = re.search(r'media\.name = "(.*?)"', line)
        if m:
            current["media"] = m.group(1)
            continue
            
        # Node name
        m = re.search(r'node\.name = "(.*?)"', line)
        if m:
            current["node_name"] = m.group(1)
            continue

    if current:
        apps.append(current)

    # Add icons and filter empty
    out = []
    for a in apps:
        app_name = a.get("name", "")
        binary = a.get("binary", "")
        node_name = a.get("node_name", "")
        media_name = a.get("media", "")

        # Filter out internal sinks and equalizers
        if "effect_output" in node_name or "Global Equalizer" in media_name or "easyeffects" in app_name.lower():
            continue
            
        label = app_name or binary or media_name or node_name or "Unknown App"
        if label == "Unknown App":
            continue

        icon_key = (app_name + " " + binary + " " + node_name + " " + media_name).lower()
        a["label"] = label
        a["icon"] = ICON_MAP(icon_key)
        out.append(a)

    def ICON_MAP(name):
        name = name.lower()
        icons = {
            "spotify": "󰓇", "firefox": "󰈹", "chrome": "󰊯", "chromium": "󰊯",
            "vlc": "󰕼", "mpv": "", "discord": "󰙯", "telegram": "",
            "teams": "󰊻", "zoom": "󰊻", "steam": "󰓓", "rhythmbox": "󰓃",
            "brave": "󰊯", "obs": "󰐕", "slack": "󰒱", "elisa": "󰝚",
            "clementine": "󰝚", "amarok": "󰓃", "audio-src": "󰎆"
        }
        for k, v in icons.items():
            if k in name:
                return v
        return "󰕾"

    print(json.dumps(out))
except Exception as e:
    with open("/home/reaan/reaan-dotfiles/qs-vol-error.log", "w") as f:
        f.write(str(e))
    print("[]")
PYEOF
        ;;

    set)
        SINK_ID="$2"
        VOL="$3"
        if [[ -z "$SINK_ID" || -z "$VOL" ]]; then
            echo "Usage: app-volume.sh set <id> <0-100>" >&2
            exit 1
        fi
        # Clamp 0-150 (allow boosting up to 150%)
        VOL=$(python3 -c "print(max(0, min(150, int('$VOL'))))" 2>/dev/null || echo "$VOL")
        pactl set-sink-input-volume "$SINK_ID" "${VOL}%"
        ;;

    mute)
        pactl set-sink-input-mute "$2" 1
        ;;

    unmute)
        pactl set-sink-input-mute "$2" 0
        ;;

    toggle-mute)
        pactl set-sink-input-mute "$2" toggle
        ;;
esac
