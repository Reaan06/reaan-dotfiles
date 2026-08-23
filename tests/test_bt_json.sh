#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/bt-json.XXXXXX")"
BEFORE="$(git -C "$ROOT" status --porcelain=v1)"
trap 'rm -rf "$TMP"' EXIT

SCAN_FEED=""

bluetoothctl() {
    case "$*" in
        *"scan on"*)
            if [ -n "$SCAN_FEED" ]; then
                printf '%s' "$SCAN_FEED"
            else
                echo "Discovery started"
            fi
            ;;
        "devices")
            echo "Device AA:BB:CC:DD:EE:FF Test Device 1"
            echo "Device 11:22:33:44:55:66 AA-BB-CC-DD-EE-FF"
            echo "Device CC:DD:EE:FF:00:11 CC-DD-EE-FF-00-11"
            ;;
        "info AA:BB:CC:DD:EE:FF")
            echo "Device AA:BB:CC:DD:EE:FF"
            echo "    Name: Test Device 1"
            echo "    Alias: Mi Alias BT"
            echo "    Paired: yes"
            echo "    Trusted: yes"
            echo "    Icon: audio-card"
            echo "    Battery Percentage: 80"
            ;;
        "info 11:22:33:44:55:66")
            echo "Device 11:22:33:44:55:66"
            echo "    Name: 11-22-33-44-55-66"
            echo "    Alias: Real Speaker"
            echo "    Paired: no"
            echo "    Trusted: no"
            ;;
        "info CC:DD:EE:FF:00:11")
            echo "Device CC:DD:EE:FF:00:11"
            echo "    Alias: CC-DD-EE-FF-00-11"
            echo "    Paired: no"
            echo "    Trusted: no"
            ;;
        "devices Connected")
            echo "Device AA:BB:CC:DD:EE:FF AA-BB-CC-DD-EE-FF"
            ;;
        *)
            echo "Mock error: unknown command $*" >&2
            return 1
            ;;
    esac
}
export -f bluetoothctl

# Simula [CHG] Name durante el escaneo (caso Samsung TV / BLE tardío)
SCAN_FEED=$'[CHG] Device AA:BB:CC:DD:EE:FF Name: Mi Alias BT
[CHG] Device 11:22:33:44:55:66 Name: Real Speaker
[NEW] Device CC:DD:EE:FF:00:11 CC-DD-EE-FF-00-11
'
export SCAN_FEED

echo "Running scan test..."
OUTPUT_SCAN=$(bash "$ROOT/dot_config/scripts/bt-manager.sh" scan)
echo "Scan Output: $OUTPUT_SCAN"

echo "$OUTPUT_SCAN" | jq -e '. | type == "array"' > /dev/null || { echo "Scan output is not an array"; exit 1; }
ITEM1=$(echo "$OUTPUT_SCAN" | jq -r '.[0]')
echo "$ITEM1" | jq -e '.mac == "AA:BB:CC:DD:EE:FF"' > /dev/null || { echo "Item 1 mac mismatch"; exit 1; }
echo "$ITEM1" | jq -e '.name == "Mi Alias BT"' > /dev/null || { echo "Item 1 should prefer Alias / discovery Name"; exit 1; }
echo "$ITEM1" | jq -e '.paired == true' > /dev/null || { echo "Item 1 paired mismatch"; exit 1; }
echo "$ITEM1" | jq -e '.trusted == true' > /dev/null || { echo "Item 1 trusted mismatch"; exit 1; }
echo "$ITEM1" | jq -e '.icon == "audio-card"' > /dev/null || { echo "Item 1 icon mismatch"; exit 1; }

ITEM2=$(echo "$OUTPUT_SCAN" | jq -r '.[1]')
echo "$ITEM2" | jq -e '.mac == "11:22:33:44:55:66"' > /dev/null || { echo "Item 2 mac mismatch"; exit 1; }
echo "$ITEM2" | jq -e '.name == "Real Speaker"' > /dev/null || { echo "Item 2 should use Alias over MAC-like Name"; exit 1; }
echo "$ITEM2" | jq -e '.paired == false' > /dev/null || { echo "Item  2 paired mismatch"; exit 1; }
echo "$ITEM2" | jq -e '.trusted == false' > /dev/null || { echo "Item 2 trusted mismatch"; exit 1; }
echo "$ITEM2" | jq -e '.icon == "bluetooth"' > /dev/null || { echo "Item 2 icon mismatch (default expected)"; exit 1; }

ITEM3=$(echo "$OUTPUT_SCAN" | jq -r '.[2]')
echo "$ITEM3" | jq -e '.mac == "CC:DD:EE:FF:00:11"' > /dev/null || { echo "Item 3 mac mismatch"; exit 1; }
echo "$ITEM3" | jq -e '.name == "CC-DD-EE-FF-00-11"' > /dev/null || { echo "Item 3 should fall back to list MAC label, not generic placeholder"; exit 1; }
echo "$ITEM3" | jq -e '.name != "Dispositivo Bluetooth"' > /dev/null || { echo "Item 3 must not use generic placeholder"; exit 1; }

echo "Running info test..."
OUTPUT_INFO=$(bash "$ROOT/dot_config/scripts/bt-manager.sh" info)
echo "Info Output: $OUTPUT_INFO"

echo "$OUTPUT_INFO" | jq -e '.status == "connected"' > /dev/null || { echo "Info status mismatch"; exit 1; }
echo "$OUTPUT_INFO" | jq -e '.name == "Mi Alias BT"' > /dev/null || { echo "Info should prefer Alias over MAC-like list name"; exit 1; }
echo "$OUTPUT_INFO" | jq -e '.battery == "80"' > /dev/null || { echo "Info battery mismatch"; exit 1; }
echo "$OUTPUT_INFO" | jq -e '.icon == "audio-card"' > /dev/null || { echo "Info icon mismatch"; exit 1; }

[[ "$(git -C "$ROOT" status --porcelain=v1)" == "$BEFORE" ]] || { echo "Test changed the worktree" >&2; exit 1; }
echo "PASS: hermetic Bluetooth JSON boundary"
