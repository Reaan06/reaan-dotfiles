#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/wallpaper-flow.XXXXXX")"
BEFORE="$(git -C "$ROOT" status --porcelain=v1)"
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
expect_fail() { local expected="$1"; shift; if "$@" > "$TMP/out" 2> "$TMP/err"; then fail "expected failure: $*"; fi; [[ "$(<"$TMP/err")" == "$expected" ]] || fail "unexpected failure: $*"; }
SCRIPTS="$ROOT/dot_config/scripts"
BIN="$TMP/bin"
mkdir -p "$BIN" "$TMP/wallpapers" "$TMP/runtime" "$TMP/config"
[[ -x "$SCRIPTS/apply-wallpaper.sh" ]] || fail 'wallpaper apply script is not executable'
cp "$ROOT/tests/fixtures/wallpaper/valid.png" "$TMP/wallpapers/valid.png"

cat > "$BIN/hyprctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '[{"name":"TEST-1","focused":true}]'
EOF
cat > "$BIN/jq" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' 'TEST-1'
EOF
chmod +x "$BIN"/*

export HOME="$TMP/home" QS_CONFIG_HOME="$TMP/config" QS_RUNTIME_DIR="$TMP/runtime" XDG_RUNTIME_DIR="$TMP/runtime" QS_WALLPAPER_ROOT="$TMP/wallpapers" PYTHONDONTWRITEBYTECODE=1
LIST="$(python3 "$SCRIPTS/wallpaper_bridge.py" list)"
jq -e 'length == 1 and .[0].relativePath == "valid.png"' <<<"$LIST" >/dev/null || fail 'wallpaper bridge did not list the approved fixture'

PATH="$BIN:/usr/bin:/bin" bash "$SCRIPTS/wallpaper-toggle.sh"
[[ "$(<"$QS_RUNTIME_DIR/qs-wallpaper-picker")" == 'visible TEST-1' ]] || fail 'wallpaper toggle did not become visible'
PATH="$BIN:/usr/bin:/bin" bash "$SCRIPTS/wallpaper-toggle.sh"
[[ "$(<"$QS_RUNTIME_DIR/qs-wallpaper-picker")" == 'hidden TEST-1' ]] || fail 'wallpaper toggle did not become hidden'

NO_BIN="$TMP/no-bin"
mkdir -p "$NO_BIN"
expect_fail 'Error: Required command unavailable: hyprctl' /usr/bin/env PATH="$NO_BIN" /bin/bash "$SCRIPTS/wallpaper-toggle.sh"

[[ "$(git -C "$ROOT" status --porcelain=v1)" == "$BEFORE" ]] || fail 'test changed the worktree'
printf 'PASS: hermetic wallpaper flow\n'
