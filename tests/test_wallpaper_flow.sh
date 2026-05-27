#!/bin/bash

echo "Testing Wallpaper Redesign..."

# 1. Verify Bridge
echo "Testing bridge list..."
RESULT=$(python3 dot_config/scripts/wallpaper_bridge.py list)
if echo "$RESULT" | grep -q '\['; then
    echo "✅ Bridge list works."
else
    echo "❌ Bridge list failed."
    exit 1
fi

# 2. Check toggle script
echo "Testing toggle script..."
TOGGLE_FILE="${XDG_RUNTIME_DIR:-/tmp}/qs-wallpaper-picker"
./dot_config/scripts/wallpaper-toggle.sh
if [ "$(cat "$TOGGLE_FILE" | cut -d' ' -f1)" == "visible" ]; then
    echo "✅ Toggle script works (visible)."
    ./dot_config/scripts/wallpaper-toggle.sh
    if [ "$(cat "$TOGGLE_FILE" | cut -d' ' -f1)" == "hidden" ]; then
        echo "✅ Toggle script works (hidden)."
    fi
else
    echo "❌ Toggle script failed."
    exit 1
fi

echo "All tests passed."
