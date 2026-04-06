#!/bin/bash
# mpris-follow.sh — Real-time MPRIS metadata via playerctl
# Writes to /tmp/qs-mpris on every track/status change (event-driven).
# QML handles live position ticking locally — this only provides metadata.

RTDIR="${XDG_RUNTIME_DIR:-/tmp}"
LOCK="$RTDIR/qs-mpris.lock"
OUT="$RTDIR/qs-mpris"

# Single-instance guard: if lock file exists and that process is alive, exit
if [ -f "$LOCK" ]; then
    OLD_PID=$(cat "$LOCK" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        exit 0
    fi
fi
echo $$ > "$LOCK"

cleanup() { rm -f "$OUT" "$LOCK"; exit 0; }
trap cleanup EXIT INT TERM

# Main loop — restarts if playerctl exits (player closed, crashed, etc.)
while true; do
    # Wait for a player to appear
    while ! playerctl status &>/dev/null; do sleep 2; done

    # Follow metadata changes — fires instantly on track/status change
    playerctl metadata --follow --format '{{status}}
{{title}}
{{artist}}
{{mpris:artUrl}}
{{position}}
{{mpris:length}}' 2>/dev/null | while IFS= read -r line1; do
        IFS= read -r line2  # title
        IFS= read -r line3  # artist
        IFS= read -r line4  # artUrl
        IFS= read -r line5  # position (microseconds)
        IFS= read -r line6  # length (microseconds)
        POS_US="${line5%%.*}"
        LEN_US="${line6%%.*}"
        POS_SEC=$(( ${POS_US:-0} / 1000000 ))
        LEN_SEC=$(( ${LEN_US:-0} / 1000000 ))
        printf '%s\n%s\n%s\n%s\n%s\n%s\n' \
            "$line1" "$line2" "$line3" "$line4" "$POS_SEC" "$LEN_SEC" > "$OUT"
    done

    # playerctl exited — mark as stopped and retry
    echo "Stopped" > "$OUT"
    sleep 2
done
