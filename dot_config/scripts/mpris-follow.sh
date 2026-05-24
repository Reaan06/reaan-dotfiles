#!/bin/bash
# mpris-follow.sh — Super robust version with active switching logic
RTDIR="${XDG_RUNTIME_DIR:-/tmp}"
LOCK="$RTDIR/qs-mpris.lock"
OUT="$RTDIR/qs-mpris"

# Prevent multiple instances
if [ -f "$LOCK" ]; then
    OLD_PID=$(cat "$LOCK" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then exit 0; fi
fi
echo $$ > "$LOCK"

cleanup() { 
    # Kill all child processes (including the follow and the switcher)
    pkill -P $$ 2>/dev/null
    rm -f "$OUT" "$LOCK"
    exit 0 
}
trap cleanup EXIT INT TERM

# Format string using Unit Separator (\x1f) for atomic parsing
FORMAT='{{status}}\x1f{{title}}\x1f{{artist}}\x1f{{mpris:artUrl}}\x1f{{position}}\x1f{{mpris:length}}\x1f{{playerName}}'

# --- Active Switcher ---
# This background process monitors ALL players. 
# If a different player starts playing, we kill the main playerctl process
# to force it to refocus on the new "best" player.
(
    last_active=""
    while true; do
        # Listen for any player status change
        playerctl -a status --follow 2>/dev/null | while read -r status; do
            # When any player becomes 'Playing', we check if we should refocus
            if [ "$status" == "Playing" ]; then
                current_best=$(playerctl -l 2>/dev/null | head -1)
                if [ -n "$current_best" ] && [ "$current_best" != "$last_active" ]; then
                    last_active="$current_best"
                    # Kill the metadata follow process (it's a child of the main loop)
                    pkill -P $$ playerctl 2>/dev/null
                fi
            fi
        done
        sleep 2
    done
) &

# --- Main Follow Loop ---
while true; do
    # Wait for at least one player
    if ! playerctl status &>/dev/null; then
        echo "Stopped" > "$OUT"
        sleep 2
        continue
    fi

    # Start playerctl follow
    # It will be killed by the switcher if focus needs to change
    playerctl metadata --follow --format "$FORMAT" 2>/dev/null | while IFS=$'\x1f' read -r status title artist arturl pos_us len_us player; do
        if [ -n "$status" ]; then
            pos_us="${pos_us%%.*}"
            len_us="${len_us%%.*}"
            
            printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \
                "$status" \
                "$title" \
                "$artist" \
                "$arturl" \
                "$(( ${pos_us:-0} / 1000000 ))" \
                "$(( ${len_us:-0} / 1000000 ))" \
                "$player" > "$OUT"
        fi
    done
    
    echo "Stopped" > "$OUT"
    sleep 1
done
