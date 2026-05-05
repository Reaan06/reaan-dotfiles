#!/bin/bash
# app-volume.sh — Per-Application Audio Volume Controller via PipeWire/PulseAudio

ACTION="$1"

case "$ACTION" in
    list)
        # Output JSON array of current sink-input streams
        python3 - << 'PYEOF'
import subprocess, json, re, os, sys

def get_icon(name):
    name = name.lower()
    icons = {
        "spotify": "󰓇", "firefox": "󰈹", "chrome": "󰊯", "chromium": "󰊯",
        "vlc": "󰕼", "mpv": "󰕼", "discord": "󰙯", "vesktop": "󰙯", "telegram": "󰙯",
        "teams": "󰊻", "zoom": "󰊻", "steam": "󰓓", "rhythmbox": "󰓃",
        "brave": "󰊯", "obs": "󰐕", "slack": "󰒱", "elisa": "󰝚",
        "clementine": "󰝚", "amarok": "󰓃", "audio-src": "󰎆",
        "chrome-": "󰊯", "edge": "󰊯", "music": "󰎆"
    }
    for k, v in icons.items():
        if k in name: return v
    return "󰕾"

try:
    # 1. Get Client info to map properties
    client_result = subprocess.run(
        ["pactl", "list", "clients"],
        env={"LC_ALL": "C", **os.environ},
        capture_output=True, text=True
    )
    
    client_map = {}
    if client_result.returncode == 0:
        c_blocks = re.split(r"Client #", client_result.stdout)
        for cb in c_blocks:
            if not cb.strip(): continue
            c_lines = cb.strip().split("\n")
            try:
                c_id = c_lines[0].split()[0]
                c_props = {
                    "name": re.search(r'application\.name = "(.*?)"', cb),
                    "binary": re.search(r'application\.process\.binary = "(.*?)"', cb),
                    "icon": re.search(r'application\.icon_name = "(.*?)"', cb)
                }
                client_map[c_id] = {
                    "name": c_props["name"].group(1) if c_props["name"] else "",
                    "binary": c_props["binary"].group(1) if c_props["binary"] else "",
                    "icon": c_props["icon"].group(1) if c_props["icon"] else ""
                }
            except: continue

    # 2. Get Sink Inputs
    result = subprocess.run(
        ["pactl", "list", "sink-inputs"],
        env={"LC_ALL": "C", **os.environ},
        capture_output=True, text=True
    )
    
    if result.returncode != 0:
        print("[]")
        sys.exit(0)

    blocks = re.split(r"Sink Input #", result.stdout)
    out = []

    for block in blocks:
        if not block.strip(): continue
        
        lines = block.strip().split("\n")
        try:
            input_id = int(lines[0].split()[0])
        except: continue
        
        # Basic fields
        app = {"id": input_id, "muted": ("Mute: yes" in block), "volume": 100}
        vol_match = re.search(r"Volume:.*?(\d+)%", block)
        if vol_match: app["volume"] = int(vol_match.group(1))
        
        # Client ID association
        client_id_match = re.search(r"Client: (\d+)", block)
        client_info = {}
        if client_id_match:
            client_info = client_map.get(client_id_match.group(1), {})

        # Properties from Sink Input
        si_name = re.search(r'application\.name = "(.*?)"', block)
        si_binary = re.search(r'application\.process\.binary = "(.*?)"', block)
        si_media = re.search(r'media\.name = "(.*?)"', block)
        si_node = re.search(r'node\.name = "(.*?)"', block)
        si_icon = re.search(r'application\.icon_name = "(.*?)"', block)

        # Merge Info (Sink Input properties override Client properties)
        name = (si_name.group(1) if si_name else "") or client_info.get("name", "")
        binary = (si_binary.group(1) if si_binary else "") or client_info.get("binary", "")
        media = (si_media.group(1) if si_media else "")
        node = (si_node.group(1) if si_node else "")
        icon_name = (si_icon.group(1) if si_icon else "") or client_info.get("icon", "")

        # Filtering
        if any(x in (node + media).lower() for x in ["effect_output", "equalizer", "easyeffects"]):
            continue
            
        # Labeling
        label = name
        if not label or label.lower() in ["playback", "audio-src", "chromium", "unknown"]:
            label = media or binary or node or icon_name or "Audio App"
            
        if "google chrome" in label.lower() and media and media != "Playback":
            label = media
            
        if label.lower() == "audio-src": label = "System Audio"
        if label.lower() == "playback" and name: label = name
        
        icon_key = (name + " " + binary + " " + node + " " + media + " " + icon_name).lower()
        
        # Icon name priority
        sys_icon = icon_name or binary or name
        if "spotify" in icon_key: sys_icon = "spotify"
        if "chrome" in icon_key: sys_icon = "google-chrome"
        if "firefox" in icon_key: sys_icon = "firefox"
        if "discord" in icon_key: sys_icon = "discord"
        if "vesktop" in icon_key: sys_icon = "vesktop"

        out.append({
            "id": app["id"],
            "muted": app["muted"],
            "volume": app["volume"],
            "label": label,
            "icon": get_icon(icon_key),
            "icon_name": sys_icon
        })

    print(json.dumps(out))
except Exception:
    print("[]")
PYEOF
        ;;

    set)
        SINK_ID="$2"
        VOL="$3"
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
    *)
        echo "Usage: $0 {list|set|mute|unmute|toggle-mute}"
        exit 1
        ;;
esac
