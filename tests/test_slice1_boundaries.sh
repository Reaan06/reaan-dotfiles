#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"; TMP="$(mktemp -d "${TMPDIR:-/tmp}/slice1-paths.XXXXXX")"; BEFORE="$(git -C "$ROOT" status --porcelain=v1)"
trap 'rm -rf "$TMP"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
expect_fail() { local want="$1"; shift; if "$@" >"$TMP/out" 2>"$TMP/err"; then fail "expected failure: $*"; fi; [[ "$(<"$TMP/err")" == "$want" && ! -s "$TMP/out" ]] || fail "unexpected failure result: $*"; }
assert_argv() {
    local file="$1" expected index=0
    shift
    local -a actual=()
    mapfile -d '' -t actual < "$file"
    [[ "${#actual[@]}" -eq "$#" ]] || fail "unexpected argument count in $file"
    for expected in "$@"; do
        [[ "${actual[$index]}" == "$expected" ]] || fail "unexpected argument $index in $file"
        ((index += 1))
    done
}
assert_absent() { local file="$1" needle="$2"; ! grep -Fq -- "$needle" "$file" || fail "secret leaked to $file"; }
wait_for_file() {
    local file="$1"
    for _ in {1..50}; do
        [[ -s "$file" ]] && return 0
        sleep 0.02
    done
    fail "timed out waiting for $file"
}
run_network_cases() {
    local scripts="$TMP/relocated/dot_config/scripts" bin="$TMP/bin" args="$TMP/argv" stdin="$TMP/stdin" curl_log="$TMP/curl-argv" curl_config="$TMP/curl-config"
    local marker="$TMP/ssid-side-effect" secret='wifi-fixture-secret' token='github-fixture-token'
    local ssid="Cafe; \$(touch $marker)"$'\n'"network"
    mkdir -p "$scripts" "$bin" "$TMP/config" "$TMP/runtime"
    cp "$ROOT/dot_config/scripts/"{network-manager.sh,get-wifi-pass.sh,github-fetch.sh} "$scripts/" || fail 'missing process network production files'
    export HOME="$TMP/home" QS_CONFIG_HOME="$TMP/config" QS_RUNTIME_DIR="$TMP/runtime" QS_WALLPAPER_ROOT="$TMP/wallpapers"

    cat > "$bin/nmcli" <<'EOF'
#!/usr/bin/env bash
printf '%s\0' "$@" > "$SLICE1_ARGS"
cat > "$SLICE1_STDIN"
if [[ "${SLICE1_NMCLI_FAIL:-0}" == 1 ]]; then exit 9; fi
printf 'nmcli-connected\n'
EOF
    cat > "$bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\0' "$@" > "$SLICE1_ARGS"
cat > "$SLICE1_STDIN"
printf 'fixture-wifi-password\n'
EOF
    cat > "$bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '%q\n' "$@" >> "$SLICE1_CURL_ARGS"
for ((index = 1; index <= $#; index += 1)); do
    if [[ "${!index}" == '--config' ]]; then
        next=$((index + 1))
        cat "${!next}" >> "$SLICE1_CURL_CONFIG"
    fi
done
case " $* " in
    *'api.github.com/graphql'*) printf '%s\n' '{"data":{"user":{"login":"octo","repositories":{"nodes":[]},"contributionsCollection":{"contributionCalendar":{"totalContributions":0,"weeks":[],"colors":[]},"commitContributionsByRepository":[]}}}}' ;;
    *'/events'*) printf '%s\n' '[]' ;;
    *'/notifications'*) printf '%s\n' '[]' ;;
    *'/repos'*) printf '%s\n' '[]' ;;
    *) printf '%s\n' '{"login":"octo","public_repos":0,"followers":0,"following":0}' ;;
esac
EOF
    chmod +x "$bin"/*

    printf '%s\n' "$secret" | env PATH="$bin:/usr/bin:/bin" SLICE1_ARGS="$args" SLICE1_STDIN="$stdin" bash "$scripts/network-manager.sh" connect "$ssid" > "$TMP/connect.out"
    [[ "$(<"$TMP/connect.out")" == 'nmcli-connected' ]] || fail 'network connect output changed'
    assert_argv "$args" --ask device wifi connect "$ssid"
    [[ "$(<"$stdin")" == "$secret" ]] || fail 'network password was not delivered through stdin'
    assert_absent "$args" "$secret"
    [[ ! -e "$marker" ]] || fail 'SSID separator executed a command'

    : > "$args"; : > "$stdin"
    env PATH="$bin:/usr/bin:/bin" SLICE1_ARGS="$args" SLICE1_STDIN="$stdin" bash "$scripts/network-manager.sh" connect 'Open network' > "$TMP/open.out"
    [[ "$(<"$TMP/open.out")" == 'nmcli-connected' ]] || fail 'open network output changed'
    assert_argv "$args" device wifi connect 'Open network'
    [[ ! -s "$stdin" ]] || fail 'open network unexpectedly received a credential'

    if printf '%s\n' "$secret" | env PATH="$bin:/usr/bin:/bin" SLICE1_ARGS="$args" SLICE1_STDIN="$stdin" SLICE1_NMCLI_FAIL=1 bash "$scripts/network-manager.sh" connect 'failing network' > "$TMP/out" 2> "$TMP/err"; then
        fail 'network-manager accepted a failing dependency'
    fi
    [[ "$(<"$TMP/err")" == 'Error: Unable to connect to Wi-Fi network.' ]] || fail 'network-manager failure is not fail-closed'

    printf '%s\n' "$secret" | env PATH="$bin:/usr/bin:/bin" SLICE1_ARGS="$args" SLICE1_STDIN="$stdin" bash "$scripts/get-wifi-pass.sh" "$ssid" > "$TMP/wifi-password.out"
    [[ "$(<"$TMP/wifi-password.out")" == 'fixture-wifi-password' ]] || fail 'wifi password output changed'
    assert_argv "$args" -S nmcli -s -g 802-11-wireless-security.psk connection show "$ssid" --show-secrets
    [[ "$(<"$stdin")" == "$secret" ]] || fail 'sudo password was not delivered through stdin'
    assert_absent "$args" "$secret"
    grep -Fq 'PASS=$2' "$scripts/get-wifi-pass.sh" && fail 'wifi password remains argv-sourced'

    : > "$curl_log"; : > "$curl_config"
    printf '%s\n' "$token" | env PATH="$bin:/usr/bin:/bin" SLICE1_CURL_ARGS="$curl_log" SLICE1_CURL_CONFIG="$curl_config" bash "$scripts/github-fetch.sh" octo > "$TMP/github-token.out"
    jq -e '.api == "graphql_v4" and .has_token == true and .profile.login == "octo"' "$TMP/github-token.out" >/dev/null || fail 'github token output changed'
    assert_absent "$curl_log" "$token"
    grep -Fq -- "$token" "$curl_config" || fail 'github token did not reach the protected curl config'
    grep -Fq 'TOKEN="$2"' "$scripts/github-fetch.sh" && fail 'github token remains argv-sourced'

    env PATH="$bin:/usr/bin:/bin" SLICE1_CURL_ARGS="$curl_log" SLICE1_CURL_CONFIG="$curl_config" bash "$scripts/github-fetch.sh" octo < /dev/null > "$TMP/github-public.out"
    jq -e '.api == "rest_v3" and .has_token == false and .profile.login == "octo"' "$TMP/github-public.out" >/dev/null || fail 'github public output changed'
}
run_app_cases() {
    local scripts="$TMP/relocated/dot_config/scripts" bin="$TMP/bin" capture="$TMP/app-argv" marker="$TMP/app-side-effect"
    local token='github-fixture-token' app_class="Class; \$(touch $marker)"$'\n'"item"
    mkdir -p "$scripts" "$bin" "$TMP/config" "$TMP/data/applications"
    cp "$ROOT/dot_config/scripts/"{app-launch.py,github-config.py,pin_app.py,hide_app.py} "$scripts/" || fail 'missing process app production files'
    export HOME="$TMP/home" QS_CONFIG_HOME="$TMP/config" QS_RUNTIME_DIR="$TMP/runtime" XDG_DATA_HOME="$TMP/data"

    cat > "$bin/literal-app" <<'EOF'
#!/usr/bin/env bash
printf '%s\0' "$@" > "$APP_LAUNCH_CAPTURE"
EOF
    cat > "$TMP/data/applications/fallback-app.desktop" <<'EOF'
[Desktop Entry]
Name=fallback-app
Exec=literal-app --from-desktop %U
EOF
    chmod +x "$bin/literal-app"

    APP_LAUNCH_CAPTURE="$capture" PATH="$bin:/usr/bin:/bin" python3 "$scripts/app-launch.py" "literal-app --label 'semi; \$(touch $marker)'"
    wait_for_file "$capture"
    assert_argv "$capture" --label "semi; \$(touch $marker)"
    [[ ! -e "$marker" ]] || fail 'desktop command separator executed a command'

    : > "$capture"
    APP_LAUNCH_CAPTURE="$capture" PATH="$bin:/usr/bin:/bin" python3 "$scripts/app-launch.py" fallback-app
    wait_for_file "$capture"
    assert_argv "$capture" --from-desktop
    expect_fail 'Error: application command is required.' python3 "$scripts/app-launch.py" ''

    printf '%s\n' "$token" | python3 "$scripts/github-config.py" save octo
    [[ "$(stat -c '%a' "$QS_CONFIG_HOME/quickshell/.github-config")" == 600 ]] || fail 'github config permissions are not private'
    python3 "$scripts/github-config.py" load > "$TMP/github-config.json"
    jq -e --arg token "$token" '.username == "octo" and .token == $token' "$TMP/github-config.json" >/dev/null || fail 'github config load changed'
    python3 "$scripts/github-config.py" delete
    [[ ! -e "$QS_CONFIG_HOME/quickshell/.github-config" ]] || fail 'github config delete failed'

    python3 "$scripts/pin_app.py" "$app_class" > "$TMP/pin.out"
    jq -e --arg app "$app_class" '. == [$app]' "$QS_CONFIG_HOME/scripts/pinned_apps.json" >/dev/null || fail 'pin state did not preserve literal app class'
    python3 "$scripts/hide_app.py" "$app_class"
    jq -e --arg app "$app_class" '. == [$app]' "$QS_CONFIG_HOME/scripts/hidden_apps.json" >/dev/null || fail 'hide state did not preserve literal app class'
    [[ ! -e "$marker" ]] || fail 'app class separator executed a command'
    expect_fail 'Usage: python3 pin_app.py <AppClass>' python3 "$scripts/pin_app.py"
    expect_fail 'Usage: python3 hide_app.py <AppClass>' python3 "$scripts/hide_app.py"
}
run_qml_cases() {
    local qml
    for qml in WifiGraph.qml GitHubManager.qml GitHubLinkingView.qml AuraLauncher.qml DockManager.qml DockItem.qml WallpaperPicker.qml shell.qml; do
        grep -Fq 'import "components"' "$ROOT/dot_config/quickshell/$qml" || fail "$qml does not import RuntimePaths"
        grep -Fq 'RuntimePaths { id: runtimePaths }' "$ROOT/dot_config/quickshell/$qml" || \
            grep -Fq 'property var runtimePaths: RuntimePaths {}' "$ROOT/dot_config/quickshell/$qml" || \
            fail "$qml does not instantiate RuntimePaths"
        ! grep -Fq '["sh", "-c"' "$ROOT/dot_config/quickshell/$qml" || fail "$qml still uses shell source"
        ! grep -Fq "['sh', '-c'" "$ROOT/dot_config/quickshell/$qml" || fail "$qml still uses shell source"
    done
    grep -Fq 'stdinEnabled' "$ROOT/dot_config/quickshell/WifiGraph.qml" || fail 'WifiGraph does not enable stdin for credentials'
    grep -Fq '.write(' "$ROOT/dot_config/quickshell/WifiGraph.qml" || fail 'WifiGraph does not write credentials to stdin'
    grep -Fq 'stdinEnabled' "$ROOT/dot_config/quickshell/GitHubManager.qml" || fail 'GitHubManager does not enable stdin for credentials'
    grep -Fq '.write(' "$ROOT/dot_config/quickshell/GitHubManager.qml" || fail 'GitHubManager does not write credentials to stdin'
    grep -Fq 'runtimePaths.runtimeDir' "$ROOT/dot_config/quickshell/DockManager.qml" || fail 'DockManager does not use the runtime adapter'
    grep -Fq 'runtimePaths.runtimeDir' "$ROOT/dot_config/quickshell/shell.qml" || fail 'shell.qml does not use the runtime adapter'
    WALLPAPER_QML="$ROOT/dot_config/quickshell/WallpaperPicker.qml"
    grep -Fq 'runtimePaths.scriptsDir' "$WALLPAPER_QML" || fail 'WallpaperPicker does not use the scripts adapter'
    grep -Fq 'command: ["zenity", "--file-selection"' "$WALLPAPER_QML" || fail 'WallpaperPicker does not use direct zenity argv'
    grep -Fq 'stdout: StdioCollector' "$WALLPAPER_QML" || fail 'WallpaperPicker does not collect chooser stdout'
    grep -Fq 'runtimePaths.wallpaperRoot' "$WALLPAPER_QML" || fail 'WallpaperPicker does not enforce the wallpaper root'
    grep -Fq 'relativePath' "$WALLPAPER_QML" || fail 'WallpaperPicker does not convert approved selections to relative paths'
    grep -Fq 'command: ["tee", runtimePaths.runtimeDir + "/qs-wallpaper-picker"]' "$WALLPAPER_QML" || fail 'WallpaperPicker does not use direct runtime-state argv'
    grep -Fq 'stdinEnabled: true' "$WALLPAPER_QML" || fail 'WallpaperPicker does not enable runtime-state stdin'
    grep -Fq 'hideProc.write("hidden\n")' "$WALLPAPER_QML" || fail 'WallpaperPicker does not write runtime state through stdin'
}
run_process_cases() {
    run_network_cases
    run_app_cases
    run_qml_cases
}
run_runner_cases() {
    local test_file
    for test_file in test_quickshell_exec.sh test_bt_json.sh test_wifi_scan.sh test_wallpaper_flow.sh; do
        grep -Fq 'set -euo pipefail' "$ROOT/tests/$test_file" || fail "$test_file is not strict"
        grep -Fq 'BEFORE=' "$ROOT/tests/$test_file" || fail "$test_file does not snapshot the worktree"
        grep -Fq 'trap ' "$ROOT/tests/$test_file" || fail "$test_file does not clean up temporary files"
    done
    ! grep -Fq '/home/reaan/reaan-dotfiles' "$ROOT/tests/test_quickshell_exec.sh" || fail 'quickshell runner keeps a historical absolute path'
    ! grep -Fq './dot_config/scripts' "$ROOT/tests/test_wifi_scan.sh" || fail 'wifi runner keeps a relative source path'
    ! grep -Fq './dot_config/scripts' "$ROOT/tests/test_wallpaper_flow.sh" || fail 'wallpaper runner keeps a relative source path'
    grep -Fq 'strict_tdd: true' "$ROOT/openspec/config.yaml" || fail 'strict TDD is disabled'
    grep -Fq 'graphical:' "$ROOT/openspec/config.yaml" || fail 'graphical runtime gate is not configured'
    [[ -f "$ROOT/tests/test_graphical_runtime.sh" ]] || fail 'controlled graphical harness is missing'
}
case "${1:-paths}" in
    paths) ;;
    network) run_network_cases ;;
    apps) run_app_cases ;;
    qml) run_qml_cases ;;
    process) run_process_cases ;;
    runner) run_runner_cases ;;
    *) printf 'Usage: %s [paths|network|apps|qml|process|runner]\n' "$0" >&2; exit 64 ;;
esac
if [[ "${1:-paths}" != paths ]]; then
    [[ "$(git -C "$ROOT" status --porcelain=v1)" == "$BEFORE" ]] || fail 'test changed the worktree'
    printf 'PASS: safe process boundary\n'
    exit 0
fi
S="$TMP/relocated/dot_config/scripts"; mkdir -p "$S" "$TMP/config" "$TMP/runtime" "$TMP/wallpapers"
cp "$ROOT/dot_config/scripts/"{runtime-paths.sh,runtime_paths.py,wallpaper_bridge.py,apply-wallpaper.sh} "$S/" || fail 'missing portable path production files'
cp "$ROOT/tests/fixtures/wallpaper/valid.png" "$TMP/wallpapers/valid.png"
export HOME="$TMP/home" QS_CONFIG_HOME="$TMP/config" QS_RUNTIME_DIR="$TMP/runtime" QS_WALLPAPER_ROOT="$TMP/wallpapers"
[[ "$(bash "$S/runtime-paths.sh" config)" == "$QS_CONFIG_HOME" ]] || fail 'shell config root'
[[ "$(bash "$S/runtime-paths.sh" runtime)" == "$QS_RUNTIME_DIR" ]] || fail 'shell runtime root'
[[ "$(python3 "$S/runtime_paths.py" wallpaper_root)" == "$QS_WALLPAPER_ROOT" ]] || fail 'python wallpaper root'
[[ "$(env -u QS_WALLPAPER_ROOT HOME="$HOME" XDG_PICTURES_DIR="$TMP/pictures" bash "$S/runtime-paths.sh" wallpaper)" == "$TMP/pictures/wallpapers" ]] || fail 'XDG fallback'
for text in 'Quickshell.env("QS_CONFIG_HOME")' 'Quickshell.env("QS_RUNTIME_DIR")' 'Quickshell.env("QS_WALLPAPER_ROOT")'; do grep -Fq -- "$text" "$ROOT/dot_config/quickshell/components/RuntimePaths.qml" || fail "missing QML root: $text"; done
grep -Fq 'RuntimePaths 1.0 RuntimePaths.qml' "$ROOT/dot_config/quickshell/components/qmldir" || fail 'missing QML export'
grep -Fq 'onClicked: applySelected(modelData.relativePath)' "$ROOT/dot_config/quickshell/WallpaperPicker.qml" || fail 'absolute wallpaper selection'
LIST="$(python3 "$S/wallpaper_bridge.py" list)"; [[ "$LIST" == *'"relativePath": "valid.png"'* ]] || fail 'approved wallpaper list'
mkdir "$QS_WALLPAPER_ROOT/incoming"; cp "$QS_WALLPAPER_ROOT/valid.png" "$QS_WALLPAPER_ROOT/incoming/upload.png"
[[ "$(python3 "$S/wallpaper_bridge.py" upload incoming/upload.png)" == *'"success": true'* ]] || fail 'approved upload'
mkdir "$TMP/outside"; cp "$QS_WALLPAPER_ROOT/valid.png" "$TMP/outside/outside.png"; ln -s "$TMP/outside/outside.png" "$QS_WALLPAPER_ROOT/outside.png"
expect_fail 'Error: Wallpaper path traversal is not allowed.' python3 "$S/wallpaper_bridge.py" upload ../outside/outside.png
expect_fail 'Error: Wallpaper path must be relative to the approved root.' python3 "$S/wallpaper_bridge.py" upload "$TMP/outside/outside.png"
expect_fail 'Error: Wallpaper path resolves outside the approved root.' python3 "$S/wallpaper_bridge.py" upload outside.png
expect_fail 'Error: Wallpaper path resolves outside the approved root.' python3 "$S/wallpaper_bridge.py" list; rm "$QS_WALLPAPER_ROOT/outside.png"
BIN="$TMP/bin"; CAPTURE="$TMP/swaybg-args"; mkdir "$BIN"; : > "$CAPTURE"
printf '%s\n' '#!/bin/sh' 'printf "%s\n" "[{\"name\":\"T\",\"focused\":true}]"' > "$BIN/hyprctl"
printf '%s\n' '#!/bin/sh' 'cat >/dev/null' 'printf "%s\n" T' > "$BIN/jq"
printf '%s\n' '#!/bin/sh' 'printf "%s\n" "$*" >> "$SLICE1_CAPTURE"' > "$BIN/swaybg"
printf '%s\n' '#!/bin/sh' 'printf "%s\n" header "0,0: #123456"' > "$BIN/magick"
chmod +x "$BIN"/*; ln -s /bin/true "$BIN/notify-send"
apply() { PATH="$BIN:/usr/bin:/bin" SLICE1_CAPTURE="$CAPTURE" bash "$S/apply-wallpaper.sh" "$@"; }
apply valid.png >/dev/null; grep -Fq -- "-i $QS_WALLPAPER_ROOT/valid.png" "$CAPTURE" || fail 'approved apply'
ln -s "$TMP/outside/outside.png" "$QS_WALLPAPER_ROOT/outside.png"
expect_fail 'Error: Wallpaper path traversal is not allowed.' apply ../outside/outside.png
expect_fail 'Error: Wallpaper path must be relative to the approved root.' apply "$TMP/outside/outside.png"
expect_fail 'Error: Wallpaper path resolves outside the approved root.' apply outside.png
NO="$TMP/no-hyprctl"; mkdir "$NO"; ln -s "$(command -v realpath)" "$NO/realpath"
expect_fail 'Error: Required command unavailable: hyprctl' env PATH="$NO" /bin/bash "$S/apply-wallpaper.sh" valid.png
printf '%s\n' '#!/bin/sh' 'exit 9' > "$BIN/hyprctl"; chmod +x "$BIN/hyprctl"
expect_fail 'Error: Unable to query monitors.' apply valid.png
[[ "$(git -C "$ROOT" status --porcelain=v1)" == "$BEFORE" ]] || fail 'test changed the worktree'
printf 'PASS: portable path and wallpaper confinement boundary\n'
