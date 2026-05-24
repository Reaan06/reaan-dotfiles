#!/bin/bash
# tests/test_wifi_scan.sh

SCRIPT="./dot_config/scripts/network-manager.sh"

echo "Running scan test..."
OUTPUT=$($SCRIPT scan)

echo "Output:"
echo "$OUTPUT"

# Check if output is valid JSON array
if ! echo "$OUTPUT" | jq -e 'if type == "array" then true else false end' > /dev/null; then
    echo "FAILED: Output is not a JSON array"
    exit 1
fi

# Check for new fields in the first item (if array is not empty)
if echo "$OUTPUT" | jq -e 'length > 0' > /dev/null; then
    MISSING_FIELDS=$(echo "$OUTPUT" | jq -r '.[0] | to_entries | map(select(.key | in({"ssid":1, "signal":1, "security":1, "band":1, "chan":1, "rate":1, "known":1}) | not)) | map(.key) | join(", ")')
    
    REQUIRED_FIELDS=("ssid" "signal" "security" "band" "chan" "rate" "known")
    for field in "${REQUIRED_FIELDS[@]}"; do
        if ! echo "$OUTPUT" | jq -e ".[0] | has(\"$field\")" > /dev/null; then
            echo "FAILED: Missing field '$field'"
            exit 1
        fi
    done
    echo "SUCCESS: All required fields present in scan output."
else
    echo "SKIP: No wifi networks found to test."
fi
