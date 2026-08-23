#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/quickshell-graphical.XXXXXX")"
BEFORE="$(git -C "$ROOT" status --porcelain=v1)"
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

if ! command -v quickshell >/dev/null 2>&1 \
    || ! command -v Hyprland >/dev/null 2>&1 \
    || ! command -v hyprctl >/dev/null 2>&1 \
    || [[ -z "${WAYLAND_DISPLAY:-}" || -z "${XDG_RUNTIME_DIR:-}" ]] \
    || ! hyprctl monitors -j >/dev/null 2>&1; then
    [[ "$(git -C "$ROOT" status --porcelain=v1)" == "$BEFORE" ]] || fail 'test changed the worktree'
    printf 'UNVERIFIED: controlled Wayland/Hyprland/Quickshell runtime unavailable\n'
    exit 0
fi

mkdir -p "$TMP/config/quickshell/components" "$TMP/config/scripts" "$TMP/bin" "$TMP/home" "$TMP/runtime"
cp "$ROOT/dot_config/quickshell/components/RuntimePaths.qml" "$TMP/config/quickshell/components/"
cp "$ROOT/dot_config/scripts/network-manager.sh" "$TMP/config/scripts/"
cat > "$TMP/bin/nmcli" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP/bin/nmcli"

cat > "$TMP/config/quickshell/shell.qml" <<'EOF'
import Quickshell
import Quickshell.Io
import "components"

ShellRoot {
    RuntimePaths { id: runtimePaths }
    Process {
        id: marker
        command: ["touch", Quickshell.env("QS_GRAPHICAL_MARKER")]
    }
    Process {
        command: ["bash", runtimePaths.scriptsDir + "/network-manager.sh", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === '{"status":"disconnected"}') marker.running = true
            }
        }
        running: true
    }
}
EOF

set +e
HOME="$TMP/home" \
QS_CONFIG_HOME="$TMP/config" \
QS_RUNTIME_DIR="$TMP/runtime" \
QS_GRAPHICAL_MARKER="$TMP/marker" \
PATH="$TMP/bin:/usr/bin:/bin" \
timeout 4s quickshell --path "$TMP/config/quickshell" > "$TMP/quickshell.log" 2>&1
status=$?
set -e

[[ -f "$TMP/marker" ]] || fail "controlled graphical boundary did not produce its marker (exit $status)"
[[ "$(git -C "$ROOT" status --porcelain=v1)" == "$BEFORE" ]] || fail 'test changed the worktree'
printf 'PASS: controlled Quickshell Process argv boundary on %s\n' "$WAYLAND_DISPLAY"
