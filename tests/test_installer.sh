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
assert_shell_state() { assert_content "$XDG_CONFIG_HOME/reaan/terminal-shell.conf" "$1"$'\n'; }

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
if [[ "${GENTLEMAN_TEST_FAIL:-}" == 1 ]]; then
    [[ -f "$HOME/.config/herdr/config.toml" ]] && printf 'mutated\n' > "$HOME/.config/herdr/config.toml"
    exit 23
fi
mkdir -p "$HOME/.gentleman-markers"
printf '%s\n' "$3" > "$HOME/.gentleman-markers/shell"
printf '%s\n' "$4" > "$HOME/.gentleman-markers/wm"
case "$3" in
    --shell=fish) mkdir -p "$HOME/.config/fish"; : > "$HOME/.config/fish/config.fish" ;;
    --shell=zsh) : > "$HOME/.zshrc" ;;
    --shell=nushell) mkdir -p "$HOME/.config/nushell"; : > "$HOME/.config/nushell/config.nu" ;;
esac
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
    grep -Fq 'Opción (1-2, No por defecto)' "$ROOT/install.sh" || test_fail 'Terminal DOTS prompt is not numbered'
    grep -Fq 'Opción (1-3, Zsh por defecto)' "$ROOT/install.sh" || test_fail 'shell prompt is not numbered'
    grep -Fq 'Opción (1-4, Herdr por defecto)' "$ROOT/install.sh" || test_fail 'WM prompt is not numbered'
}

test_normalization_and_decline() {
    setup
    [[ "$(normalize_terminal_dots_answer '')" == none ]] || test_fail 'Terminal DOTS default lost'
    [[ "$(normalize_terminal_dots_answer 1)" == enabled ]] || test_fail 'Terminal DOTS yes normalization failed'
    [[ "$(normalize_terminal_dots_answer 2)" == none ]] || test_fail 'Terminal DOTS no normalization failed'
    [[ "$(normalize_terminal_dots_answer yes)" == enabled ]] || test_fail 'Terminal DOTS alias lost'
    [[ "$(normalize_terminal_shell_answer '')" == zsh ]] || test_fail 'Zsh default lost'
    [[ "$(normalize_terminal_shell_answer 1)" == fish ]] || test_fail 'Fish numeric normalization failed'
    [[ "$(normalize_terminal_shell_answer 3)" == nushell ]] || test_fail 'Nushell numeric normalization failed'
    [[ "$(normalize_terminal_shell_answer fish)" == fish ]] || test_fail 'Fish alias lost'
    [[ "$(normalize_terminal_runtime_answer '')" == herdr ]] || test_fail 'Herdr default lost'
    [[ "$(normalize_terminal_runtime_answer 1)" == herdr ]] || test_fail 'Herdr numeric normalization failed'
    [[ "$(normalize_terminal_runtime_answer 3)" == zellij ]] || test_fail 'Zellij numeric normalization failed'
    [[ "$(normalize_terminal_runtime_answer zellij)" == zellij ]] || test_fail 'Zellij alias lost'
    ! normalize_terminal_dots_answer 3 || test_fail 'invalid Terminal DOTS choice accepted'
    ! normalize_terminal_shell_answer 4 || test_fail 'invalid shell choice accepted'
    ! normalize_terminal_runtime_answer 5 || test_fail 'invalid WM choice accepted'
    dots_prompt="$(printf '9\n' | prompt_terminal_dots 2>&1)"
    [[ "$dots_prompt" == *'1) Sí'* && "$dots_prompt" == *'2) No'* && "$dots_prompt" == *'1 y 2'* ]] || test_fail 'Terminal DOTS prompt contract changed'
    shell_prompt="$(printf '4\n' | prompt_terminal_shell 2>&1)"
    [[ "$shell_prompt" == *'1) Fish'* && "$shell_prompt" == *'2) Zsh'* && "$shell_prompt" == *'3) Nushell'* && "$shell_prompt" == *'between 1 and 3'* ]] || test_fail 'shell prompt contract changed'
    runtime_prompt="$(printf '5\n' | prompt_terminal_runtime 2>&1)"
    [[ "$runtime_prompt" == *'1) Herdr'* && "$runtime_prompt" == *'2) TMUX'* && "$runtime_prompt" == *'3) Zellij'* && "$runtime_prompt" == *'4) None'* && "$runtime_prompt" == *'between 1 and 4'* ]] || test_fail 'WM prompt contract changed'
    printf '\n' | configure_terminal_dots >/dev/null
    assert_state none
    assert_shell_state none
    [[ ! -s "$CURL_LOG" ]] || test_fail 'decline downloaded Gentleman.Dots'
}

test_state_and_config_boundaries() {
    setup
    write_terminal_state zellij
    write_terminal_shell_state fish
    assert_state zellij
    assert_shell_state fish
    [[ "$(stat -c '%a' "$XDG_CONFIG_HOME/reaan/terminal-dots.conf")" == 600 ]] || test_fail 'state mode is not private'
    [[ "$(stat -c '%a' "$XDG_CONFIG_HOME/reaan/terminal-shell.conf")" == 600 ]] || test_fail 'shell state mode is not private'
    printf 'zellij\ntmux\n' > "$XDG_CONFIG_HOME/reaan/terminal-dots.conf"
    [[ "$(read_terminal_state)" == none ]] || test_fail 'malformed state was accepted'
    printf 'invalid\n' > "$XDG_CONFIG_HOME/reaan/terminal-shell.conf"
    [[ "$(read_terminal_shell_state)" == none ]] || test_fail 'invalid shell state was accepted'
    printf 'fish\nzsh\n' > "$XDG_CONFIG_HOME/reaan/terminal-shell.conf"
    [[ "$(read_terminal_shell_state)" == none ]] || test_fail 'malformed shell state was accepted'
    mkdir -p "$TMP/vendor/dot_config/herdr" "$XDG_CONFIG_HOME/herdr"
    printf 'vendor\n' > "$TMP/vendor/dot_config/herdr/config.toml"
    printf 'user\n' > "$XDG_CONFIG_HOME/herdr/config.toml"
    DOTFILES_DIR="$TMP/vendor" preserve_herdr_config
    assert_content "$XDG_CONFIG_HOME/herdr/config.toml" $'user\n'
}

test_official_wrapper() {
    setup; setup_fake_curl
    printf '1\n1\n3\n' | configure_terminal_dots >/dev/null
    assert_state zellij
    assert_shell_state fish
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

test_special_file_safe_backup() {
    setup; setup_fake_curl
    mkdir -p "$HOME/.config/herdr"
    python3 - "$HOME/.config/herdr/herdr-client.sock" <<'PY'
import socket
import sys

server = socket.socket(socket.AF_UNIX)
server.bind(sys.argv[1])
PY
    output="$(printf '1\n1\n1\n' | configure_terminal_dots)"
    assert_state herdr
    assert_shell_state fish
    grep -Fq -- '--backup=false' "$INSTALLER_LOG" || test_fail 'special-file install did not disable upstream backup'
    ! grep -Fq -- '--backup=true' "$INSTALLER_LOG" || test_fail 'special-file install used upstream backup'
    mapfile -t backup_archives < <(compgen -G "$HOME/.gentleman-safe-backup-*/configs.tar.gz")
    backup_archive="${backup_archives[0]:-}"
    [[ -f "$backup_archive" ]] || test_fail 'safe backup archive was not created'
    tar -tzf "$backup_archive" | grep -Fqx '.config/herdr/' || test_fail 'managed config tree was not captured in safe backup'
    [[ "$output" == *'safe backup saved at:'* ]] || test_fail 'safe backup location was not printed'
    [[ -S "$HOME/.config/herdr/herdr-client.sock" ]] || test_fail 'socket was removed or mutated'
}

test_special_file_failure_restores_backup() {
    setup; setup_fake_curl; export GENTLEMAN_TEST_FAIL=1
    mkdir -p "$HOME/.config/herdr"
    printf 'original\n' > "$HOME/.config/herdr/config.toml"
    python3 - "$HOME/.config/herdr/herdr-client.sock" <<'PY'
import socket
import sys

server = socket.socket(socket.AF_UNIX)
server.bind(sys.argv[1])
PY
    output="$(printf '1\n1\n1\n' | configure_terminal_dots 2>&1)" && test_fail 'installer failure accepted'
    assert_state none
    assert_shell_state none
    assert_content "$HOME/.config/herdr/config.toml" $'original\n'
    [[ -S "$HOME/.config/herdr/herdr-client.sock" ]] || test_fail 'special entry was not preserved after restore'
    [[ "$output" == *'Safe config snapshot restored after Gentleman.Dots failure.'* ]] || test_fail 'restore outcome was not reported'
    [[ "$output" == *'terminal DOTS remain disabled'* ]] || test_fail 'failure was not reported as disabled'
}

test_kitty_shell_selection() {
    setup
    mkdir -p "$HOME/.config/kitty"
    printf 'font_size 12\nshell_integration enabled\nshell zsh\n' > "$HOME/.config/kitty/kitty.conf"
    configure_kitty_shell fish
    assert_content "$HOME/.config/kitty/kitty.conf" $'font_size 12\nshell_integration enabled\nshell fish\n'
    [[ "$(kitty_effective_shell)" == fish ]] || test_fail 'Kitty did not select Fish'

    printf 'font_size 12\nshell_integration enabled\n' > "$HOME/.config/kitty/kitty.conf"
    configure_kitty_shell nushell
    [[ "$(kitty_effective_shell)" == nu ]] || test_fail 'Kitty did not select Nushell'
    grep -Fqx 'shell nu' "$HOME/.config/kitty/kitty.conf" || test_fail 'Nushell directive missing'

    configure_kitty_shell zsh
    [[ "$(kitty_effective_shell)" == zsh ]] || test_fail 'Kitty did not select Zsh'
    grep -Fqx 'shell zsh' "$HOME/.config/kitty/kitty.conf" || test_fail 'Zsh directive missing'

    cat > "$TMP/bin/fish" <<'EOF'
#!/bin/bash
exit 0
EOF
    chmod 700 "$TMP/bin/fish"
    write_terminal_shell_state fish
    write_terminal_state none
    configure_kitty_shell fish
    output="$(all_ok=true; validate_terminal_selection)"
    [[ "$output" == *'Selected shell: fish (fish)'* && "$output" == *'config.fish'* ]] || test_fail 'dynamic shell validation lost Fish'
    [[ "$output" == *'Selected session: None'* && "$output" == *'Kitty effective shell matches selection: fish'* ]] || test_fail 'dynamic validation report incomplete'
}

test_failure_no_fallback() {
    setup; setup_fake_curl; export GENTLEMAN_TEST_FAIL=1
    if printf '1\n2\n1\n' | configure_terminal_dots >/dev/null 2>&1; then test_fail 'installer failure accepted'; fi
    assert_state none
    assert_shell_state none
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
test_special_file_safe_backup
test_special_file_failure_restores_backup
test_failure_no_fallback
test_kitty_shell_selection
test_launcher
printf 'PASS: official Gentleman.Dots and terminal session contracts\n'
