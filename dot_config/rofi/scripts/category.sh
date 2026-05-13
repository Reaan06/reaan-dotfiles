#!/usr/bin/env bash

# Rofi Category Filter Script
# Usage: category.sh "CategoryName"

CATEGORY=$1

if [ -z "$ROFI_RETOK" ]; then
    # List items
    # Search in /usr/share/applications and ~/.local/share/applications
    find /usr/share/applications ~/.local/share/applications -name "*.desktop" 2>/dev/null | xargs grep -l "Categories=.*$CATEGORY" 2>/dev/null | while read -r file; do
        name=$(grep "^Name=" "$file" | head -1 | cut -d'=' -f2)
        exec_cmd=$(grep "^Exec=" "$file" | head -1 | cut -d'=' -f2 | sed 's/%.//g')
        icon=$(grep "^Icon=" "$file" | head -1 | cut -d'=' -f2)
        
        # Output for rofi: name\0icon\x1ficonname\x1finfo\x1fcommand
        if [ -n "$name" ]; then
            echo -en "$name\0icon\x1f${icon:-system-run}\x1finfo\x1f$exec_cmd\n"
        fi
    done | sort -u
else
    # Execute selected item
    # ROFI_INFO contains the Exec command
    if [ -n "$ROFI_INFO" ]; then
        nohup $ROFI_INFO >/dev/null 2>&1 &
    fi
    exit 0
fi
