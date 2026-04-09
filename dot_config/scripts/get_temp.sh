#!/bin/bash
sensors 2>/dev/null | grep -E "Package id 0|Core 0|temp1" | head -1 | awk '{print $4}' | sed 's/+//;s/°C//' || echo "N/A"
