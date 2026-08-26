#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/terminal-dots-test.XXXXXX")"
BEFORE="$(git -C "$ROOT" status --porcelain=v1)"
trap 'rm -rf "$TMP"; [[ "$(git -C "$ROOT" status --porcelain=v1)" == "$BEFORE" ]] || { printf "FAIL: test changed the worktree\n" >&2; exit 1; }' EXIT

test_fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_file() { [[ -f "$1" ]] || test_fail "missing file: $1"; }
assert_content() { printf '%s' "$2" | cmp -s - "$1" || test_fail "unexpected content: $1"; }
assert_state() { assert_content "$XDG_CONFIG_HOME/reaan/terminal-dots.conf" "$1"$'\n'; }

setup() {
    rm -rf "$TMP/home" "$TMP/config" "$TMP/bin"
    mkdir -p "$TMP/home" "$TMP/config" "$TMP/bin"
    export HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/config" PATH="$TMP/bin:/usr/bin:/bin"
    export CURL_LOG="$TMP/curl.log" INSTALLER_LOG="$TMP/installer.log" CURL_MODE="$TMP/curl.mode"
    : > "$CURL_LOG"; : > "$INSTALLER_LOG"
    source "$ROOT/install.sh"
}

setup_fake_curl() {
    cat > "$TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\0' "$@" > "${CURL_LOG:?}"
output=''
while (($#)); do
    case "$1" in --output) output="$2"; shift 2 ;; *) shift ;; esac
done
[[ -n "$output" ]] || exit 64
cat > "$output" <<'INSTALLER'
#!/usr/bin/env bash
set -euo pipefail
printf 'pwd=%s\n' "$PWD" >> "${INSTALLER_LOG:?}"
printf 'args=' >> "${INSTALLER_LOG:?}"
printf '%s\0' "$@" >> "${INSTALLER_LOG:?}"
printf '\n' >> "${INSTALLER_LOG:?}"
[[ "${GENTLEMAN_TEST_FAIL:-}" != 1 ]] || exit 23
mkdir -p "$HOME/.gentleman-markers"
printf '%s\n' "$3" > "$HOME/.gentleman-markers/shell"
printf '%s\n' "$4" > "$HOME/.gentleman-markers/wm"
INSTALLER
chmod 700 "$output"
stat -c '%a' "$output" > "${CURL_MODE:?}"
EOF
    chmod 700 "$TMP/bin/curl"
}

test_boundaries() {
    [[ -x "$ROOT/install.sh" ]] || test_fail 'install.sh is not executable'
    [[ ! -e "$ROOT/install-arch.sh" ]] || test_fail 'old installer remains'
    ! grep -Fq 'shell zsh' "$ROOT/dot_config/kitty/kitty.conf" || test_fail 'Kitty still forces Zsh'
    grep -Fqx '$terminal = kitty' "$ROOT/dot_config/hypr/hyprland.conf" || test_fail 'Kitty Hyprland binding changed'
    ! grep -Fq 'dot_zshrc' "$ROOT/install.sh" || test_fail 'installer deploys dot_zshrc'
    ! grep -Fq 'oh-my-zsh\|powerlevel10k\|chsh' "$ROOT/install.sh" || test_fail 'obsolete Zsh block remains'
}

test_normalization_and_decline() {
    setup
    [[ "$(normalize_terminal_shell_answer '')" == zsh ]] || test_fail 'Zsh default lost'
    [[ "$(normalize_terminal_shell_answer fish)" == fish ]] || test_fail 'Fish normalization failed'
    [[ "$(normalize_terminal_shell_answer nushell)" == nushell ]] || test_fail 'Nushell normalization failed'
    [[ "$(normalize_terminal_runtime_answer zellij)" == zellij ]] || test_fail 'Zellij normalization failed'
    ! normalize_terminal_shell_answer invalid || test_fail 'invalid shell accepted'
    ! normalize_terminal_runtime_answer invalid || test_fail 'invalid WM accepted'
    printf '\n' | configure_terminal_dots >/dev/null
    assert_state none
    [[ ! -s "$CURL_LOG" ]] || test_fail 'decline downloaded Gentleman.Dots'
}

test_state_and_config_boundaries() {
    setup
    write_terminal_state zellij
    assert_state zellij
    [[ "$(stat -c '%a' "$XDG_CONFIG_HOME/reaan/terminal-dots.conf")" == 600 ]] || test_fail 'state mode is not private'
    printf 'zellij\ntmux\n' > "$XDG_CONFIG_HOME/reaan/terminal-dots.conf"
    [[ "$(read_terminal_state)" == none ]] || test_fail 'malformed state was accepted'
    mkdir -p "$TMP/vendor/dot_config/herdr" "$XDG_CONFIG_HOME/herdr"
    printf 'vendor\n' > "$TMP/vendor/dot_config/herdr/config.toml"
    printf 'user\n' > "$XDG_CONFIG_HOME/herdr/config.toml"
    DOTFILES_DIR="$TMP/vendor" preserve_herdr_config
    assert_content "$XDG_CONFIG_HOME/herdr/config.toml" $'user\n'
}

test_official_wrapper() {
    setup; setup_fake_curl
    printf 'yes\nfish\nzellij\n' | configure_terminal_dots >/dev/null
    assert_state zellij
    assert_content "$HOME/.gentleman-markers/shell" '--shell=fish'$'\n'
    assert_content "$HOME/.gentleman-markers/wm" '--wm=zellij'$'\n'
    mapfile -d '' -t args < "$CURL_LOG"
    [[ "${args[6]}" == https://github.com/Gentleman-Programming/Gentleman.Dots/releases/latest/download/gentleman-installer-linux-amd64 ]] || test_fail 'wrong official URL'
    [[ "${args[4]}" == --output && "$(<"$CURL_MODE")" == 700 ]] || test_fail 'download was not private'
    grep -Fq -- '--non-interactive' "$INSTALLER_LOG" || test_fail 'missing non-interactive flag'
    grep -Fq -- '--terminal=kitty' "$INSTALLER_LOG" || test_fail 'missing Kitty flag'
    grep -Fq -- '--shell=fish' "$INSTALLER_LOG" || test_fail 'missing shell flag'
    grep -Fq -- '--wm=zellij' "$INSTALLER_LOG" || test_fail 'missing WM flag'
    grep -Fq -- '--backup=true' "$INSTALLER_LOG" || test_fail 'missing backup flag'
    workdir="$(sed -n 's/^pwd=//p' "$INSTALLER_LOG")"
    [[ "$workdir" == /tmp/gentleman-dots.* ]] || test_fail 'installer did not use private workdir'
    [[ ! -e "$workdir" ]] || test_fail 'private workdir was not cleaned'
}

test_failure_no_fallback() {
    setup; setup_fake_curl; export GENTLEMAN_TEST_FAIL=1
    if printf 'yes\nzsh\nherdr\n' | configure_terminal_dots >/dev/null 2>&1; then test_fail 'installer failure accepted'; fi
    assert_state none
    [[ ! -e "$HOME/.gentleman-markers/wm" ]] || test_fail 'failed install left activation markers'
    grep -Fq -- '--wm=herdr' "$INSTALLER_LOG" || test_fail 'selected WM was not passed'
    ! grep -Fq tmux "$INSTALLER_LOG" || test_fail 'failure fell back to TMUX'
    workdir="$(sed -n 's/^pwd=//p' "$INSTALLER_LOG")"
    [[ ! -e "$workdir" ]] || test_fail 'failure left private workdir'
}

test_launcher() {
    local launcher="$TMP/launcher-home/.config/scripts/terminal-session.sh"
    mkdir -p "$(dirname "$launcher")" "$TMP/launcher-home/.local/bin" "$TMP/launcher-config/reaan" "$TMP/launcher-bin"
    cp "$ROOT/dot_config/scripts/terminal-session.sh" "$launcher"; chmod 700 "$launcher"
    cat > "$TMP/launcher-bin/zellij" <<'EOF'
#!/bin/bash
printf 'zellij\n' >> "${EVENTS:?}"
EOF
    chmod 700 "$TMP/launcher-bin/zellij"
    printf 'zellij\n' > "$TMP/launcher-config/reaan/terminal-dots.conf"
    : > "$TMP/events"
    env HOME="$TMP/launcher-home" XDG_CONFIG_HOME="$TMP/launcher-config" PATH="$TMP/launcher-bin:/usr/bin:/bin" EVENTS="$TMP/events" TERM=xterm script -qefc "/bin/bash -i -c 'source $launcher; terminal_session_guarded() { :; }; terminal_session_launch'" "$TMP/typescript" >/dev/null 2>&1
    assert_content "$TMP/events" 'zellij'$'\n'
}

test_boundaries
test_normalization_and_decline
test_state_and_config_boundaries
test_official_wrapper
test_failure_no_fallback
test_launcher
printf 'PASS: official Gentleman.Dots and terminal session contracts\n'
