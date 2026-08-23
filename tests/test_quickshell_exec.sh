#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/quickshell-exec.XXXXXX")"
BEFORE="$(git -C "$ROOT" status --porcelain=v1)"
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
SCRIPTS="$ROOT/dot_config/scripts"
BIN="$TMP/bin"
mkdir -p "$BIN" "$TMP/home" "$TMP/runtime"

cat > "$BIN/nmcli" <<'EOF'
#!/usr/bin/env bash
if [[ " $* " == *' device wifi '* ]]; then
    exit 0
fi
exit 9
EOF
chmod +x "$BIN/nmcli"

INFO="$(PATH="$BIN:/usr/bin:/bin" bash "$SCRIPTS/network-manager.sh" info)"
jq -e '.status == "disconnected"' <<<"$INFO" >/dev/null || fail 'network info did not preserve its disconnected JSON contract'

NO_BIN="$TMP/no-bin"
mkdir -p "$NO_BIN"
if /usr/bin/env PATH="$NO_BIN" /bin/bash "$SCRIPTS/network-manager.sh" info > "$TMP/out" 2> "$TMP/err"; then
    fail 'network info accepted a missing nmcli dependency'
fi
[[ "$(<"$TMP/err")" == 'Error: Required command unavailable: nmcli' ]] || fail 'network info did not report the missing dependency'

legacy_path="$(printf '/home/%s/reaan-dotfiles' reaan)"
! grep -Fq "$legacy_path" "$SCRIPTS/network-manager.sh" || fail 'network script retains a historical path'
[[ "$(git -C "$ROOT" status --porcelain=v1)" == "$BEFORE" ]] || fail 'test changed the worktree'
printf 'PASS: portable Quickshell execution boundary\n'
