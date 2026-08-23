#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/wifi-scan.XXXXXX")"
BEFORE="$(git -C "$ROOT" status --porcelain=v1)"
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
expect_fail() { local expected="$1"; shift; if "$@" > "$TMP/out" 2> "$TMP/err"; then fail "expected failure: $*"; fi; [[ "$(<"$TMP/err")" == "$expected" ]] || fail "unexpected failure: $*"; }
SCRIPT="$ROOT/dot_config/scripts/network-manager.sh"
BIN="$TMP/bin"
mkdir -p "$BIN"

cat > "$BIN/nmcli" <<'EOF'
#!/usr/bin/env bash
case " $* " in
    *' NAME connection show '*) printf '%s\n' 'Known Network' ;;
    *' device wifi list '*)
        printf '%s\n' \
            '92:WPA2:5180:36:540 Mbit/s:yes:Known Network' \
            '47:WPA3:2412:1:130 Mbit/s:no:Other Network'
        ;;
    *) printf 'unexpected nmcli invocation\n' >&2; exit 9 ;;
esac
EOF
chmod +x "$BIN/nmcli"

OUTPUT="$(PATH="$BIN:/usr/bin:/bin" bash "$SCRIPT" scan)"
jq -e '
    type == "array"
    and length == 2
    and .[0] == {ssid: "Known Network", signal: 92, security: "WPA2", band: "5 GHz", chan: "36", rate: "540 Mbit/s", known: true}
    and .[1] == {ssid: "Other Network", signal: 47, security: "WPA3", band: "2.4 GHz", chan: "1", rate: "130 Mbit/s", known: false}
' <<<"$OUTPUT" >/dev/null || fail 'scan JSON contract changed'

cat > "$BIN/nmcli" <<'EOF'
#!/usr/bin/env bash
case " $* " in
    *' NAME connection show '*) exit 0 ;;
    *) exit 9 ;;
esac
EOF
chmod +x "$BIN/nmcli"
expect_fail 'Error: Unable to scan Wi-Fi networks.' env PATH="$BIN:/usr/bin:/bin" bash "$SCRIPT" scan

[[ "$(git -C "$ROOT" status --porcelain=v1)" == "$BEFORE" ]] || fail 'test changed the worktree'
printf 'PASS: hermetic Wi-Fi scan boundary\n'
