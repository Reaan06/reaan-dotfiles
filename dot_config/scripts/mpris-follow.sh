#!/bin/bash
# mpris-follow.sh — Enhanced version with Player Name detection
RTDIR="${XDG_RUNTIME_DIR:-/tmp}"
LOCK="$RTDIR/qs-mpris.lock"
OUT="$RTDIR/qs-mpris"

if [ -f "$LOCK" ]; then
    OLD_PID=$(cat "$LOCK" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then exit 0; fi
fi
echo $$ > "$LOCK"

cleanup() { rm -f "$OUT" "$LOCK"; exit 0; }
trap cleanup EXIT INT TERM

while true; do
    while ! playerctl status &>/dev/null; do sleep 2; done

    # We now format: status, title, artist, artUrl, pos, len, playerName
    playerctl metadata --follow --format '{{status}}
{{title}}
{{artist}}
{{mpris:artUrl}}
{{position}}
{{mpris:length}}
{{playerName}}' 2>/dev/null | while IFS= read -r line1; do
        IFS= read -r line2; IFS= read -r line3; IFS= read -r line4
        IFS= read -r line5; IFS= read -r line6; IFS= read -r line7
        POS_US="${line5%%.*}"
        LEN_US="${line6%%.*}"
        printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \
            "$line1" "$line2" "$line3" "$line4" "$(( ${POS_US:-0} / 1000000 ))" "$(( ${LEN_US:-0} / 1000000 ))" "$line7" > "$OUT"
    done
    echo "Stopped" > "$OUT"
    sleep 2
done
