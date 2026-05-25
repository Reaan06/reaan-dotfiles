#!/bin/bash
# tests/test_bt_json.sh — Test for bt-manager.sh JSON output

# Mock bluetoothctl
bluetoothctl() {
    case "$*" in
        "show")
            echo "Discovering: yes"
            ;;
        "devices")
            echo "Device AA:BB:CC:DD:EE:FF Test Device 1"
            echo "Device 11:22:33:44:55:66 Test Device 2"
            ;;
        "info AA:BB:CC:DD:EE:FF")
            echo "Device AA:BB:CC:DD:EE:FF"
            echo "    Name: Test Device 1"
            echo "    Paired: yes"
            echo "    Trusted: yes"
            echo "    Icon: audio-card"
            echo "    Battery Percentage: 80"
            ;;
        "info 11:22:33:44:55:66")
            echo "Device 11:22:33:44:55:66"
            echo "    Name: Test Device 2"
            echo "    Paired: no"
            echo "    Trusted: no"
            # No Icon
            ;;
        "devices Connected")
            echo "Device AA:BB:CC:DD:EE:FF Test Device 1"
            ;;
        *)
            echo "Mock error: unknown command $*" >&2
            return 1
            ;;
    esac
}
export -f bluetoothctl

# Run the script and capture output
# We need to source or run the script in a way that uses our mock
# Since the script is a file, we might need to overwrite its PATH or use a wrapper.
# A simpler way is to use a temporary script that includes our mock.

cat <<EOF > bt_manager_test_wrapper.sh
$(cat dot_config/scripts/bt-manager.sh)
EOF

echo "Running scan test..."
OUTPUT_SCAN=$(bash bt_manager_test_wrapper.sh scan)
echo "Scan Output: $OUTPUT_SCAN"

# Validate scan output
echo "$OUTPUT_SCAN" | jq -e '. | type == "array"' > /dev/null || { echo "Scan output is not an array"; exit 1; }
ITEM1=$(echo "$OUTPUT_SCAN" | jq -r '.[0]')
echo "$ITEM1" | jq -e '.mac == "AA:BB:CC:DD:EE:FF"' > /dev/null || { echo "Item 1 mac mismatch"; exit 1; }
echo "$ITEM1" | jq -e '.paired == true' > /dev/null || { echo "Item 1 paired mismatch"; exit 1; }
echo "$ITEM1" | jq -e '.trusted == true' > /dev/null || { echo "Item 1 trusted mismatch"; exit 1; }
echo "$ITEM1" | jq -e '.icon == "audio-card"' > /dev/null || { echo "Item 1 icon mismatch"; exit 1; }

ITEM2=$(echo "$OUTPUT_SCAN" | jq -r '.[1]')
echo "$ITEM2" | jq -e '.mac == "11:22:33:44:55:66"' > /dev/null || { echo "Item 2 mac mismatch"; exit 1; }
echo "$ITEM2" | jq -e '.paired == false' > /dev/null || { echo "Item 2 paired mismatch"; exit 1; }
echo "$ITEM2" | jq -e '.trusted == false' > /dev/null || { echo "Item 2 trusted mismatch"; exit 1; }
echo "$ITEM2" | jq -e '.icon == "bluetooth"' > /dev/null || { echo "Item 2 icon mismatch (default expected)"; exit 1; }

echo "Running info test..."
OUTPUT_INFO=$(bash bt_manager_test_wrapper.sh info)
echo "Info Output: $OUTPUT_INFO"

# Validate info output
echo "$OUTPUT_INFO" | jq -e '.status == "connected"' > /dev/null || { echo "Info status mismatch"; exit 1; }
echo "$OUTPUT_INFO" | jq -e '.battery == "80"' > /dev/null || { echo "Info battery mismatch"; exit 1; }
echo "$OUTPUT_INFO" | jq -e '.icon == "audio-card"' > /dev/null || { echo "Info icon mismatch"; exit 1; }

rm bt_manager_test_wrapper.sh
echo "All tests passed!"
