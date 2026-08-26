#!/bin/bash
# mpris-follow.sh — Normalized Polling Version
SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
[[ "$SCRIPT_DIR" == "${BASH_SOURCE[0]}" ]] && SCRIPT_DIR="."
source "$SCRIPT_DIR/runtime-paths.sh"
runtime_paths_load
RTDIR="$RUNTIME_PATHS_RUNTIME_DIR"
LOCK="$RTDIR/qs-mpris.lock"
OUT="$RTDIR/qs-mpris"
TMP="$RTDIR/qs-mpris.tmp"

if [ -f "$LOCK" ]; then
    OLD_PID=$(cat "$LOCK" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then exit 0; fi
fi
echo $$ > "$LOCK"

cleanup() { rm -f "$OUT" "$TMP" "$LOCK"; exit 0; }
trap cleanup EXIT INT TERM

while true; do
    PLAYERS=$(playerctl -l 2>/dev/null)
    BEST_PLAYER=""
    for p in $PLAYERS; do
        if [ "$(playerctl -p "$p" status 2>/dev/null)" == "Playing" ]; then
            BEST_PLAYER="$p"
            break
        fi
    done
    [ -z "$BEST_PLAYER" ] && BEST_PLAYER=$(echo "$PLAYERS" | head -1)

    if [ -n "$BEST_PLAYER" ]; then
        # Obtener datos raw
        # playerctl metadata position y length devuelven microsegundos
        playerctl -p "$BEST_PLAYER" metadata --format '{{status}}
{{title}}
{{artist}}
{{mpris:artUrl}}
{{position}}
{{mpris:length}}
{{playerName}}' > "$TMP.meta"
        
        mapfile -t lines < "$TMP.meta"
        
        # Convertir a segundos antes de escribir al archivo
        # 1,000,000 microsegundos = 1 segundo
        POS_S=$(( ${lines[4]%%.*} / 1000000 ))
        LEN_S=$(( ${lines[5]%%.*} / 1000000 ))
        
        printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \
            "${lines[0]}" "${lines[1]}" "${lines[2]}" "${lines[3]}" "$POS_S" "$LEN_S" "${lines[6]}" > "$OUT"
    else
        echo -e "Stopped\n\n\n\n0\n0\nNone" > "$OUT"
    fi
    sleep 0.8
done
