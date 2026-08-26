#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/quickshell-regressions.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

mkdir -p "$TMP/bin" "$TMP/runtime" "$TMP/xdg" "$TMP/home"
cat > "$TMP/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-} ${2:-}" in
    "monitors -j")
        printf '[{"name":"%s","focused":true}]\n' "${WS_MONITOR:-eDP-1}"
        ;;
    "activeworkspace -j")
        printf '{"id":%s,"monitor":"%s"}\n' "${WS_ID:-1}" "${WS_MONITOR:-eDP-1}"
        ;;
    dispatch*)
        printf '%s\n' "$*" >> "${WS_CAPTURE:?WS_CAPTURE must be set}"
        ;;
    *)
        printf 'unexpected hyprctl call: %s\n' "$*" >&2
        exit 1
        ;;
esac
EOF
chmod +x "$TMP/bin/hyprctl"

run_toggle_case() {
    local script="$1" state_file="$2"
    rm -f "$TMP/runtime/$state_file" "$TMP/xdg/$state_file"
    HOME="$TMP/home" QS_RUNTIME_DIR="$TMP/runtime" XDG_RUNTIME_DIR="$TMP/xdg" \
        PATH="$TMP/bin:/usr/bin:/bin" WS_MONITOR=eDP-1 \
        bash "$ROOT/dot_config/scripts/$script" toggle
    [[ "$(<"$TMP/runtime/$state_file")" == 'visible eDP-1' ]] || fail "$script did not use QS_RUNTIME_DIR"
    [[ ! -e "$TMP/xdg/$state_file" ]] || fail "$script wrote the XDG fallback instead"

    HOME="$TMP/home" QS_RUNTIME_DIR="$TMP/runtime" XDG_RUNTIME_DIR="$TMP/xdg" \
        PATH="$TMP/bin:/usr/bin:/bin" WS_MONITOR=eDP-1 \
        bash "$ROOT/dot_config/scripts/$script" toggle
    [[ "$(<"$TMP/runtime/$state_file")" == 'hidden eDP-1' ]] || fail "$script toggle behavior changed"
}

run_toggle_case dock-toggle.sh qs-dock-toggle
run_toggle_case audio-manager.sh qs-audio-manager
run_toggle_case super-f2-toggle.sh qs-super-f2
run_toggle_case bt-toggle.sh qs-bt-panel
run_toggle_case ai-usage-toggle.sh qs-ai-usage

run_ws_case() {
    local monitor="$1" active="$2" dispatcher="$3" target="$4" expected="$5"
    local capture="$TMP/wsaction.capture"
    : > "$capture"
    HOME="$TMP/home" WS_MONITOR="$monitor" WS_ID="$active" WS_CAPTURE="$capture" \
        PATH="$TMP/bin:/usr/bin:/bin" bash "$ROOT/dot_config/scripts/wsaction.sh" "$dispatcher" "$target"
    [[ "$(<"$capture")" == "$expected" ]] || fail "wsaction mapped $monitor $dispatcher $target incorrectly"
}

run_ws_case eDP-1 3 workspace 1 'dispatch focusworkspaceoncurrentmonitor 1'
run_ws_case HDMI-A-1 13 workspace 1 'dispatch focusworkspaceoncurrentmonitor 11'
run_ws_case HDMI-A-1 11 workspace next 'dispatch focusworkspaceoncurrentmonitor 12'
run_ws_case HDMI-A-1 11 workspace prev 'dispatch focusworkspaceoncurrentmonitor 17'
run_ws_case HDMI-A-1 13 movetoworkspace 1 'dispatch movetoworkspacesilent 11'

for script in dock-toggle.sh audio-manager.sh super-f2-toggle.sh bt-toggle.sh ai-usage-toggle.sh; do
    grep -Fq 'RUNTIME_PATHS_RUNTIME_DIR' "$ROOT/dot_config/scripts/$script" \
        || fail "$script does not use the shared runtime resolver"
done
grep -Fq 'FileView' "$ROOT/dot_config/quickshell/shell.qml" || fail 'shell does not use supported FileView polling'
! grep -Fq 'Quickshell.readFile' "$ROOT/dot_config/quickshell/shell.qml" || fail 'shell still uses unsupported readFile'
! grep -Fq 'Quickshell.readFile' "$ROOT/dot_config/quickshell/DockManager.qml" || fail 'dock still uses unsupported readFile'
! grep -Fq 'ExclusionMode.Exclusive' "$ROOT/dot_config/quickshell/shell.qml" || fail 'dock uses invalid exclusion enum'
grep -Fq 'exclusionMode: ExclusionMode.Normal' "$ROOT/dot_config/quickshell/shell.qml" || fail 'dock exclusion mode is not valid'
grep -Fq 'eDP-1) WS=1' "$ROOT/dot_config/scripts/init-workspaces.sh" || fail 'eDP-1 mapping is missing'
grep -Fq 'HDMI-A-1) WS=11' "$ROOT/dot_config/scripts/init-workspaces.sh" || fail 'HDMI-A-1 mapping is missing'

printf 'PASS: runtime paths, panel state, and monitor workspace regressions\n'
