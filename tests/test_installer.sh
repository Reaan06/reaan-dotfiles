#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/terminal-dots-installer.XXXXXX")"
BEFORE="$(git -C "$ROOT" status --porcelain=v1)"
trap 'rm -rf "$TMP"; [[ "$(git -C "$ROOT" status --porcelain=v1)" == "$BEFORE" ]] || { printf "FAIL: test changed the worktree\n" >&2; exit 1; }' EXIT

test_fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_file_content() { printf '%s' "$2" | cmp -s - "$1" || test_fail "unexpected content in $1"; }
assert_file_contains() { grep -Fq -- "$2" "$1" || test_fail "missing expected content in $1: $2"; }
assert_state() { [[ -f "$XDG_CONFIG_HOME/reaan/terminal-dots.conf" ]] || test_fail 'terminal state is missing'; assert_file_content "$XDG_CONFIG_HOME/reaan/terminal-dots.conf" "$1"$'\n'; }

test_repository_boundary() {
    [[ -f "$ROOT/install.sh" ]] || test_fail 'install.sh is missing'
    [[ -x "$ROOT/install.sh" ]] || test_fail 'install.sh is not executable'
    [[ ! -e "$ROOT/install-arch.sh" ]] || test_fail 'old installer name remains executable or runnable'
    [[ ! -x "$ROOT/README.md" ]] || test_fail 'README.md is executable'
    [[ ! -x "$ROOT/openspec/config.yaml" ]] || test_fail 'configuration artifact is executable'
    grep -Fq 'DOTFILES_DIR="$SCRIPT_DIR"' "$ROOT/install.sh" || test_fail 'installer lost script-relative root'
    grep -Fq 'local src="$DOTFILES_DIR/$1"' "$ROOT/install.sh" || test_fail 'deployment is not script-relative'
}

test_final_provenance_and_boundaries() {
    local herdr_config="$ROOT/dot_config/herdr/config.toml"

    [[ -f "$herdr_config" ]] || test_fail 'vendored Herdr config is missing'
    [[ ! -x "$herdr_config" ]] || test_fail 'vendored Herdr config is executable'
    [[ "$(stat -c '%a' "$herdr_config")" == 644 ]] || test_fail 'vendored Herdr config mode is not 0644'
    [[ "$(git -C "$ROOT" hash-object "$herdr_config")" == b9f15f533a08e4464bacc59194110ed0527346fc ]] || \
        test_fail 'vendored Herdr config does not match the pinned upstream blob'

    [[ "$(stat -c '%a' "$ROOT/install.sh")" == 755 ]] || test_fail 'install.sh mode is not 0755'
    [[ -x "$ROOT/dot_config/scripts/terminal-session.sh" ]] || test_fail 'terminal session launcher is not executable'
    [[ "$(stat -c '%a' "$ROOT/dot_config/scripts/terminal-session.sh")" == 755 ]] || \
        test_fail 'terminal session launcher mode is not 0755'

    bash -n "$ROOT/install.sh" "$ROOT/tests/test_installer.sh" "$ROOT/dot_config/scripts/terminal-session.sh" || \
        test_fail 'Bash syntax check failed'
    zsh -n "$ROOT/dot_zshrc" "$ROOT/dot_config/scripts/terminal-session.sh" || \
        test_fail 'Zsh syntax check failed'

    assert_file_contains "$ROOT/dot_config/kitty/kitty.conf" 'shell zsh'
    grep -Fqx '$terminal = kitty' "$ROOT/dot_config/hypr/hyprland.conf" || \
        test_fail 'Hyprland terminal boundary changed from Kitty'
    [[ ! -x "$ROOT/README.md" ]] || test_fail 'README.md is executable'

    assert_file_contains "$ROOT/README.md" '## Optional Terminal DOTS'
    assert_file_contains "$ROOT/README.md" './install.sh'
    assert_file_contains "$ROOT/README.md" 'disabled by default'
    assert_file_contains "$ROOT/README.md" 'Herdr or TMUX'
    assert_file_contains "$ROOT/README.md" 'Kitty remains the terminal emulator'
    assert_file_contains "$ROOT/README.md" 'terminal-dots.conf'
    assert_file_contains "$ROOT/README.md" 'idempotent'
    assert_file_contains "$ROOT/README.md" 'uninstalls packages or deletes user configuration'
    assert_file_contains "$ROOT/README.md" 'Rollback'
    assert_file_contains "$ROOT/README.md" '6b02894b71dc223105091729ebd673ea64e03fb0'
    assert_file_contains "$ROOT/README.md" 'b9f15f533a08e4464bacc59194110ed0527346fc'
    assert_file_contains "$ROOT/README.md" 'fail-closed'
    assert_file_contains "$ROOT/README.md" 'https://herdr.dev/install.sh'
    assert_file_contains "$ROOT/README.md" 'latest.json'
    assert_file_contains "$ROOT/README.md" 'SHA-256'
    assert_file_contains "$ROOT/README.md" 'remote-shell trust boundary'
    assert_file_contains "$ROOT/README.md" 'download-then-execute'
    assert_file_contains "$ROOT/README.md" 'curl | sh'
    assert_file_contains "$ROOT/README.md" 'partial streamed execution'
}

setup_fixture() {
    rm -rf "$TMP/home" "$TMP/config" "$TMP/vendor"
    mkdir -p "$TMP/bin" "$TMP/home" "$TMP/config" "$TMP/vendor/dot_config/herdr"
    export HOME="$TMP/home"
    export XDG_CONFIG_HOME="$TMP/config"
    export PATH="$TMP/bin:/usr/bin:/bin"
    export YAY_LOG="$TMP/yay.log"
    export CURL_LOG="$TMP/curl.log"
    export TERMINAL_TEST_EVENTS="$TMP/events.log"
    : > "$YAY_LOG"
    : > "$CURL_LOG"
    : > "$TERMINAL_TEST_EVENTS"
    source "$ROOT/install.sh"
}

setup_herdr_official_fixture() {
    export HERDR_TEST_ORDER="$TMP/herdr-order.log"
    export HERDR_TEST_TEMP_PATH="$TMP/herdr-temp.path"
    export HERDR_TEST_MODE="$TMP/herdr-temp.mode"
    export HERDR_TEST_SCRIPT_PATH="$TMP/herdr-script.path"
    export HERDR_TEST_SCRIPT_MODE="$TMP/herdr-script.mode"
    export HERDR_TEST_INSTALL_DIR="$TMP/herdr-install-dir"
    export HERDR_TEST_CURL_RESULT=success
    export HERDR_TEST_SCRIPT_BEHAVIOR=success
    rm -f "$HERDR_TEST_TEMP_PATH" "$HERDR_TEST_MODE" "$HERDR_TEST_SCRIPT_PATH" \
        "$HERDR_TEST_SCRIPT_MODE" "$HERDR_TEST_INSTALL_DIR"
    : > "$HERDR_TEST_ORDER"

    cat > "$TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

args=("$@")
output=''
while (($#)); do
    case "$1" in
        --output)
            output="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

[[ -n "$output" ]] || exit 64
printf '%s\0' "${args[@]}" > "${CURL_LOG:?}"
printf '%s\n' "$output" > "${HERDR_TEST_TEMP_PATH:?}"
printf '%s\n' "$(stat -c '%a' "$output")" > "${HERDR_TEST_MODE:?}"
[[ "$(<"${HERDR_TEST_MODE:?}")" == 700 ]] || exit 65
printf 'curl\n' >> "${HERDR_TEST_ORDER:?}"

if [[ "${HERDR_TEST_CURL_RESULT:?}" == failure ]]; then
    exit 23
fi

cat > "$output" <<'HERDR_SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

printf 'script\n' >> "${HERDR_TEST_ORDER:?}"
printf '%s\n' "$0" > "${HERDR_TEST_SCRIPT_PATH:?}"
printf '%s\n' "$(stat -c '%a' "$0")" > "${HERDR_TEST_SCRIPT_MODE:?}"
printf '%s\n' "${HERDR_INSTALL_DIR:?}" > "${HERDR_TEST_INSTALL_DIR:?}"

case "${HERDR_TEST_SCRIPT_BEHAVIOR:?}" in
    success)
        [[ "$HERDR_INSTALL_DIR" == "$HOME/.local/bin" ]] || exit 67
        mkdir -p "$HERDR_INSTALL_DIR"
        cat > "$HERDR_INSTALL_DIR/herdr" <<'HERDR_BINARY'
#!/bin/sh
exit 0
HERDR_BINARY
        chmod 0755 "$HERDR_INSTALL_DIR/herdr"
        ;;
    script-failure)
        exit 23
        ;;
    missing-binary)
        ;;
    *)
        exit 68
        ;;
esac
HERDR_SCRIPT
EOF
    chmod 0755 "$TMP/bin/curl"
}

assert_official_curl_contract() {
    local temporary
    local -a curl_args=()

    mapfile -d '' -t curl_args < "$CURL_LOG"
    [[ "${#curl_args[@]}" -eq 7 ]] || test_fail "unexpected curl argument count: ${#curl_args[@]}"
    [[ "${curl_args[0]}" == '--fail' ]] || test_fail 'curl lost --fail'
    [[ "${curl_args[1]}" == '--location' ]] || test_fail 'curl lost --location'
    [[ "${curl_args[2]}" == '--silent' ]] || test_fail 'curl lost --silent'
    [[ "${curl_args[3]}" == '--show-error' ]] || test_fail 'curl lost --show-error'
    [[ "${curl_args[4]}" == '--output' ]] || test_fail 'curl lost --output'
    temporary="${curl_args[5]}"
    [[ "$temporary" == "$HOME/.local/bin/.herdr-download."* ]] || \
        test_fail 'Herdr temporary file was not beside the target binary'
    [[ "${curl_args[6]}" == 'https://herdr.dev/install.sh' ]] || \
        test_fail 'curl used the wrong official Herdr endpoint'
    [[ "$(<"$HERDR_TEST_MODE")" == 700 ]] || test_fail 'temporary download was not mode 0700'
    [[ "$(<"$HERDR_TEST_SCRIPT_MODE")" == 700 ]] || test_fail 'downloaded script was not executed mode 0700'
    [[ "$(<"$HERDR_TEST_INSTALL_DIR")" == "$HOME/.local/bin" ]] || \
        test_fail 'official script received the wrong install directory'
}

assert_official_temp_removed() {
    local temporary="$(<"$HERDR_TEST_TEMP_PATH")"
    [[ ! -e "$temporary" ]] || test_fail 'Herdr temporary script was left behind'
}

test_decline_and_prompt_defaults() {
    setup_fixture

    [[ "$(normalize_terminal_dots_answer '  Y  ')" == enabled ]] || test_fail 'terminal DOTS answer normalization lost whitespace handling'
    [[ "$(normalize_terminal_runtime_answer $'\tTMUX\t')" == tmux ]] || test_fail 'runtime answer normalization lost whitespace handling'

    install_herdr_runtime() { printf 'herdr\n' >> "$TERMINAL_TEST_EVENTS"; return 99; }
    install_tmux_runtime() { printf 'tmux\n' >> "$TERMINAL_TEST_EVENTS"; return 99; }

    printf '\n' | configure_terminal_dots > "$TMP/decline.out"
    assert_state none
    [[ ! -s "$TERMINAL_TEST_EVENTS" ]] || test_fail 'declining terminal DOTS activated a runtime'
    ! grep -Fq 'runtime' "$TMP/decline.out" || test_fail 'decline asked the runtime question'

    install_herdr_runtime() { printf 'herdr\n' >> "$TERMINAL_TEST_EVENTS"; return 0; }
    printf 'yes\n\n' | configure_terminal_dots > "$TMP/herdr-default.out"
    assert_state herdr
    assert_file_content "$TERMINAL_TEST_EVENTS" $'herdr\n'

    install_tmux_runtime() { printf 'tmux\n' >> "$TERMINAL_TEST_EVENTS"; return 0; }
    : > "$TERMINAL_TEST_EVENTS"
    printf 'maybe\n y \nunknown\n tmux \n' | configure_terminal_dots > "$TMP/tmux.out" 2>&1
    assert_state tmux
    assert_file_content "$TERMINAL_TEST_EVENTS" $'tmux\n'
    grep -Fq 'inválida' "$TMP/tmux.out" || test_fail 'invalid prompt answer was not reported'
}

test_state_safety_and_config_preservation() {
    setup_fixture

    mkdir -p "$XDG_CONFIG_HOME/reaan"
    printf 'herdr\n' > "$XDG_CONFIG_HOME/reaan/terminal-dots.conf"
    cat > "$TMP/bin/mv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\0' "$@" >> "${TERMINAL_TEST_MV_LOG:?}"
/usr/bin/mv "$@"
EOF
    chmod +x "$TMP/bin/mv"
    export TERMINAL_TEST_MV_LOG="$TMP/mv.log"
    : > "$TERMINAL_TEST_MV_LOG"

    write_terminal_state tmux
    assert_state tmux
    [[ "$(stat -c '%a' "$XDG_CONFIG_HOME/reaan/terminal-dots.conf")" == 600 ]] || test_fail 'state file is not mode 0600'
    mapfile -d '' -t mv_args < "$TERMINAL_TEST_MV_LOG"
    [[ "${#mv_args[@]}" -eq 3 ]] || test_fail 'state replacement did not use mv source and destination'
    [[ "$(dirname -- "${mv_args[1]}")" == "$(dirname -- "${mv_args[2]}")" ]] || test_fail 'state replacement crossed directories'
    compgen -G "$XDG_CONFIG_HOME/reaan/.terminal-dots.conf.*" >/dev/null && test_fail 'state temporary file was left behind'

    printf 'herdr\ntmux\n' > "$XDG_CONFIG_HOME/reaan/terminal-dots.conf"
    [[ "$(read_terminal_state)" == none ]] || test_fail 'multiline state was accepted'
    printf 'unsupported\n' > "$XDG_CONFIG_HOME/reaan/terminal-dots.conf"
    [[ "$(read_terminal_state)" == none ]] || test_fail 'unsupported state was accepted'
    rm -f "$XDG_CONFIG_HOME/reaan/terminal-dots.conf"
    [[ "$(read_terminal_state)" == none ]] || test_fail 'missing state was not disabled'

    printf 'vendored\n' > "$TMP/vendor/dot_config/herdr/config.toml"
    mkdir -p "$XDG_CONFIG_HOME/herdr"
    printf 'user-owned\n' > "$XDG_CONFIG_HOME/herdr/config.toml"
    DOTFILES_DIR="$TMP/vendor"
    preserve_herdr_config
    assert_file_content "$XDG_CONFIG_HOME/herdr/config.toml" $'user-owned\n'

    mkdir -p "$HOME/.local/bin"
    printf '#!/bin/sh\n' > "$HOME/.local/bin/herdr"
    chmod 0755 "$HOME/.local/bin/herdr"
    printf 'yes\n\n' | configure_terminal_dots >/dev/null
    assert_state herdr
    assert_file_content "$XDG_CONFIG_HOME/herdr/config.toml" $'user-owned\n'
    install_tmux_runtime() { return 0; }
    printf 'yes\ntmux\n' | configure_terminal_dots >/dev/null
    assert_state tmux
    [[ "$(wc -l < "$XDG_CONFIG_HOME/reaan/terminal-dots.conf")" -eq 1 ]] || test_fail 'rerun produced duplicate state lines'
    assert_file_content "$XDG_CONFIG_HOME/herdr/config.toml" $'user-owned\n'
}

test_opt_out_preserves_prior_installation() {
    setup_fixture
    printf 'fixture-herdr-config\n' > "$TMP/vendor/dot_config/herdr/config.toml"
    DOTFILES_DIR="$TMP/vendor"
    install_herdr_runtime() {
        mkdir -p "$(dirname -- "$(terminal_herdr_binary)")"
        printf 'installed-herdr-binary\n' > "$(terminal_herdr_binary)"
        chmod 0755 "$(terminal_herdr_binary)"
        printf 'herdr-install\n' >> "$TERMINAL_TEST_EVENTS"
    }

    if ! printf 'yes\nherdr\n' | configure_terminal_dots >/dev/null; then
        test_fail 'official Herdr installation was not accepted'
    fi
    assert_state herdr
    assert_file_content "$HOME/.local/bin/herdr" $'installed-herdr-binary\n'
    assert_file_content "$XDG_CONFIG_HOME/herdr/config.toml" $'fixture-herdr-config\n'
    : > "$TERMINAL_TEST_EVENTS"
    : > "$YAY_LOG"

    printf '\n' | configure_terminal_dots >/dev/null
    assert_state none
    [[ -x "$HOME/.local/bin/herdr" ]] || test_fail 'decline removed the installed Herdr runtime'
    assert_file_content "$HOME/.local/bin/herdr" $'installed-herdr-binary\n'
    assert_file_content "$XDG_CONFIG_HOME/herdr/config.toml" $'fixture-herdr-config\n'
    [[ ! -s "$YAY_LOG" ]] || test_fail 'decline attempted package-manager changes'
    [[ ! -s "$TERMINAL_TEST_EVENTS" ]] || test_fail 'decline started a runtime'

    setup_fixture
    mkdir -p "$TMP/tmux-install-bin"
    for command_name in mkdir chmod mktemp mv rm; do
        ln -sf "/usr/bin/$command_name" "$TMP/tmux-install-bin/$command_name"
    done
    export TMUX_TEST_COMMAND="$TMP/tmux-install-bin/tmux"
    cat > "$TMP/tmux-install-bin/yay" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "${YAY_LOG:?}"
printf '#!/bin/sh\n' > "${TMUX_TEST_COMMAND:?}"
/usr/bin/chmod 0755 "$TMUX_TEST_COMMAND"
EOF
    chmod 0755 "$TMP/tmux-install-bin/yay"
    mkdir -p "$XDG_CONFIG_HOME/tmux"
    printf 'prior-tmux-config\n' > "$XDG_CONFIG_HOME/tmux/tmux.conf"

    original_path="$PATH"
    PATH="$TMP/tmux-install-bin"
    printf 'yes\ntmux\n' | configure_terminal_dots >/dev/null
    PATH="$original_path"
    assert_state tmux
    assert_file_content "$TMUX_TEST_COMMAND" $'#!/bin/sh\n'
    : > "$TERMINAL_TEST_EVENTS"
    : > "$YAY_LOG"

    PATH="$TMP/tmux-install-bin"
    printf 'no\n' | configure_terminal_dots >/dev/null
    PATH="$original_path"
    assert_state none
    [[ -x "$TMUX_TEST_COMMAND" ]] || test_fail 'decline removed the installed TMUX runtime'
    assert_file_content "$TMUX_TEST_COMMAND" $'#!/bin/sh\n'
    assert_file_content "$XDG_CONFIG_HOME/tmux/tmux.conf" $'prior-tmux-config\n'
    [[ ! -s "$YAY_LOG" ]] || test_fail 'decline attempted TMUX package changes'
    [[ ! -s "$TERMINAL_TEST_EVENTS" ]] || test_fail 'decline started TMUX'
}

test_none_prewrite_and_failure_reset() {
    setup_fixture
    mkdir -p "$XDG_CONFIG_HOME/reaan"
    printf 'herdr\n' > "$XDG_CONFIG_HOME/reaan/terminal-dots.conf"

    mkdir -p "$TMP/no-tmux-bin"
    for command_name in mkdir chmod mktemp mv rm; do
        ln -sf "/usr/bin/$command_name" "$TMP/no-tmux-bin/$command_name"
    done
    cat > "$TMP/no-tmux-bin/yay" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "${YAY_LOG:?}"
IFS= read -r state < "${XDG_CONFIG_HOME:?}/reaan/terminal-dots.conf"
[[ "$state" == none ]] || exit 41
exit 23
EOF
    chmod +x "$TMP/no-tmux-bin/yay"
    install_herdr_runtime() { printf 'herdr-fallback\n' >> "$TERMINAL_TEST_EVENTS"; return 99; }
    original_path="$PATH"
    PATH="$TMP/no-tmux-bin"
    if printf 'yes\ntmux\n' | configure_terminal_dots > "$TMP/tmux-failure.out"; then
        PATH="$original_path"
        test_fail 'TMUX installation failure was accepted'
    fi
    PATH="$original_path"
    assert_state none
    ! grep -Fq -- ' -R ' "$YAY_LOG" || test_fail 'TMUX failure attempted an uninstall'
    [[ "$(wc -l < "$YAY_LOG")" -eq 1 ]] || test_fail 'TMUX installation was not attempted exactly once'
    [[ ! -e "$TMP/no-tmux-bin/tmux" ]] || test_fail 'failed TMUX installation left an activated command'
    [[ ! -s "$TERMINAL_TEST_EVENTS" ]] || test_fail 'TMUX failure fell back to Herdr'

    setup_fixture
    setup_herdr_official_fixture
    HERDR_TEST_CURL_RESULT=failure
    install_tmux_runtime() { printf 'tmux-fallback\n' >> "$TERMINAL_TEST_EVENTS"; return 99; }
    if printf 'yes\n\n' | configure_terminal_dots > "$TMP/herdr-download-failure.out" 2>&1; then
        test_fail 'official Herdr download failure was accepted'
    fi
    assert_state none
    [[ ! -e "$HOME/.local/bin/herdr" ]] || test_fail 'Herdr binary activated after download failure'
    [[ ! -e "$XDG_CONFIG_HOME/herdr/config.toml" ]] || test_fail 'Herdr config was created after download failure'
    [[ -s "$CURL_LOG" ]] || test_fail 'official Herdr download was not attempted'
    assert_official_temp_removed
    [[ ! -s "$YAY_LOG" ]] || test_fail 'official Herdr failure fell back to TMUX'
    [[ ! -s "$TERMINAL_TEST_EVENTS" ]] || test_fail 'official Herdr failure started a runtime'
}

test_tmux_install_success() {
    setup_fixture
    mkdir -p "$TMP/tmux-success-bin"
    for command_name in mkdir chmod mktemp mv rm; do
        ln -sf "/usr/bin/$command_name" "$TMP/tmux-success-bin/$command_name"
    done
    cat > "$TMP/tmux-success-bin/yay" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "${YAY_LOG:?}"
printf '#!/bin/sh\n' > "${TMUX_TEST_COMMAND:?}"
/usr/bin/chmod 0755 "$TMUX_TEST_COMMAND"
EOF
    chmod +x "$TMP/tmux-success-bin/yay"
    export TMUX_TEST_COMMAND="$TMP/tmux-success-bin/tmux"
    original_path="$PATH"
    PATH="$TMP/tmux-success-bin"
    printf 'yes\ntmux\n' | configure_terminal_dots >/dev/null
    PATH="$original_path"
    assert_state tmux
    [[ -x "$TMUX_TEST_COMMAND" ]] || test_fail 'successful TMUX installation did not expose tmux'
    assert_file_content "$YAY_LOG" $'-S --needed --noconfirm tmux\n'
}

test_herdr_official_success() {
    setup_fixture
    setup_herdr_official_fixture
    printf 'fixture-herdr-config\n' > "$TMP/vendor/dot_config/herdr/config.toml"
    DOTFILES_DIR="$TMP/vendor"

    if ! printf 'yes\nherdr\n' | configure_terminal_dots >/dev/null; then
        test_fail 'official Herdr installation was not accepted'
    fi
    assert_state herdr
    assert_file_content "$XDG_CONFIG_HOME/herdr/config.toml" $'fixture-herdr-config\n'
    assert_official_curl_contract
    assert_file_content "$HERDR_TEST_ORDER" $'curl\nscript\n'
    assert_official_temp_removed
    [[ -x "$HOME/.local/bin/herdr" ]] || test_fail 'official installer did not create executable Herdr'
}

test_herdr_official_failures() {
    local behavior

    for behavior in curl script missing; do
        setup_fixture
        setup_herdr_official_fixture
        mkdir -p "$XDG_CONFIG_HOME/herdr"
        printf 'user-owned-herdr-config\n' > "$XDG_CONFIG_HOME/herdr/config.toml"
        printf 'vendored-herdr-config\n' > "$TMP/vendor/dot_config/herdr/config.toml"
        DOTFILES_DIR="$TMP/vendor"
        install_tmux_runtime() {
            printf 'tmux-fallback\n' >> "$TERMINAL_TEST_EVENTS"
            return 99
        }

        case "$behavior" in
            curl)
                HERDR_TEST_CURL_RESULT=failure
                ;;
            script)
                HERDR_TEST_SCRIPT_BEHAVIOR=script-failure
                ;;
            missing)
                HERDR_TEST_SCRIPT_BEHAVIOR=missing-binary
                ;;
        esac

        if printf 'yes\nherdr\n' | configure_terminal_dots > "$TMP/herdr-$behavior-failure.out" 2>&1; then
            test_fail "Herdr $behavior failure was accepted"
        fi
        assert_state none
        [[ ! -e "$HOME/.local/bin/herdr" ]] || \
            test_fail "Herdr binary activated after $behavior failure"
        assert_file_content "$XDG_CONFIG_HOME/herdr/config.toml" $'user-owned-herdr-config\n'
        assert_official_temp_removed
        [[ ! -s "$TERMINAL_TEST_EVENTS" ]] || \
            test_fail "Herdr $behavior failure fell back to TMUX"
        [[ ! -s "$YAY_LOG" ]] || test_fail "Herdr $behavior failure invoked yay"

        case "$behavior" in
            curl)
                assert_file_content "$HERDR_TEST_ORDER" $'curl\n'
                [[ ! -e "$HERDR_TEST_SCRIPT_PATH" ]] || test_fail 'curl failure executed the downloaded script'
                ;;
            script|missing)
                assert_file_content "$HERDR_TEST_ORDER" $'curl\nscript\n'
                assert_official_curl_contract
                ;;
        esac
    done
}

test_herdr_existing_binary_idempotence() {
    local original_content

    setup_fixture
    setup_herdr_official_fixture
    HERDR_TEST_CURL_RESULT=failure
    mkdir -p "$HOME/.local/bin"
    printf '#!/bin/sh\nexisting-herdr\n' > "$HOME/.local/bin/herdr"
    chmod 0755 "$HOME/.local/bin/herdr"
    original_content="$(<"$HOME/.local/bin/herdr")"

    if ! printf 'yes\nherdr\n' | configure_terminal_dots >/dev/null; then
        test_fail 'existing Herdr executable was not reused'
    fi
    assert_state herdr
    [[ "$(<"$HOME/.local/bin/herdr")" == "$original_content" ]] || \
        test_fail 'existing Herdr executable content changed'
    [[ ! -s "$CURL_LOG" ]] || test_fail 'existing Herdr executable still invoked curl'
    [[ ! -s "$HERDR_TEST_ORDER" ]] || test_fail 'existing Herdr executable still invoked the official script'
    [[ ! -e "$HERDR_TEST_TEMP_PATH" ]] || test_fail 'idempotent Herdr run created a temporary path'
}

test_documentation_like_execution_boundary() {
    local documentation_root="$TMP/documentation-fixtures"
    local forbidden_marker="$TMP/forbidden-document-execution.log"
    local documentation_path
    local executed_path

    setup_fixture
    setup_herdr_official_fixture
    mkdir -p "$documentation_root/dot_config/herdr"
    printf 'fixture-herdr-config\n' > "$documentation_root/dot_config/herdr/config.toml"
    for documentation_path in README.md spec.md config.yaml; do
        cat > "$documentation_root/$documentation_path" <<EOF
#!/usr/bin/env bash
printf '%s\n' '$documentation_path' >> '$forbidden_marker'
EOF
        chmod 0755 "$documentation_root/$documentation_path"
    done
    DOTFILES_DIR="$documentation_root"

    if ! printf 'yes\nherdr\n' | configure_terminal_dots >/dev/null; then
        test_fail 'documentation boundary fixture was not accepted'
    fi
    executed_path="$(<"$HERDR_TEST_SCRIPT_PATH")"
    [[ "$executed_path" == "$HOME/.local/bin/.herdr-download."* ]] || \
        test_fail 'installer executed a path outside the private downloaded script'
    [[ ! -e "$forbidden_marker" ]] || test_fail 'documentation-like file was executed'
    [[ "$(dirname -- "$executed_path")" == "$HOME/.local/bin" ]] || \
        test_fail 'downloaded execution crossed the target directory boundary'
    [[ ! -x "$ROOT/openspec/changes/herdr-official-installer/specs/installer-terminal-selection/spec.md" ]] || \
        test_fail 'delta spec became executable'
    assert_official_temp_removed
}

setup_terminal_session_fixture() {
    export TERMINAL_SESSION_HOME="$TMP/terminal-home"
    export TERMINAL_SESSION_CONFIG="$TMP/terminal-config"
    export TERMINAL_SESSION_BIN="$TMP/terminal-bin"
    export TERMINAL_SESSION_EVENTS="$TMP/terminal-events.log"
    export TERMINAL_SESSION_LAUNCHER="$TERMINAL_SESSION_HOME/.config/scripts/terminal-session.sh"
    rm -rf "$TERMINAL_SESSION_HOME" "$TERMINAL_SESSION_CONFIG" "$TERMINAL_SESSION_BIN"
    mkdir -p "$TERMINAL_SESSION_HOME/.config/scripts" "$TERMINAL_SESSION_HOME/.local/bin" \
        "$TERMINAL_SESSION_CONFIG/reaan" "$TERMINAL_SESSION_BIN"
    : > "$TERMINAL_SESSION_EVENTS"
    unset TMUX ZELLIJ HERDR_ENV TERMINAL_SESSION_FAIL_RUNTIME

    cat > "$TERMINAL_SESSION_HOME/.local/bin/herdr" <<'EOF'
#!/bin/bash
printf 'herdr\n' >> "${TERMINAL_SESSION_EVENTS:?}"
if [[ "${TERMINAL_SESSION_FAIL_RUNTIME:-}" == herdr ]]; then
    exit 23
fi
EOF
    cat > "$TERMINAL_SESSION_BIN/tmux" <<'EOF'
#!/bin/bash
printf 'tmux\n' >> "${TERMINAL_SESSION_EVENTS:?}"
if [[ "${TERMINAL_SESSION_FAIL_RUNTIME:-}" == tmux ]]; then
    exit 29
fi
EOF
    chmod 0755 "$TERMINAL_SESSION_HOME/.local/bin/herdr" "$TERMINAL_SESSION_BIN/tmux"

    [[ -f "$ROOT/dot_config/scripts/terminal-session.sh" ]] || \
        test_fail 'terminal-session.sh is missing'
    cp "$ROOT/dot_config/scripts/terminal-session.sh" "$TERMINAL_SESSION_LAUNCHER"
    chmod 0755 "$TERMINAL_SESSION_LAUNCHER"
}

write_terminal_session_state() {
    printf '%s' "$1" > "$TERMINAL_SESSION_CONFIG/reaan/terminal-dots.conf"
}

terminal_session_path() {
    printf '%s:%s:/usr/bin:/bin\n' "$TERMINAL_SESSION_HOME/.local/bin" "$TERMINAL_SESSION_BIN"
}

run_terminal_launcher_tty() {
    env HOME="$TERMINAL_SESSION_HOME" \
        XDG_CONFIG_HOME="$TERMINAL_SESSION_CONFIG" \
        PATH="$(terminal_session_path)" \
        TERMINAL_SESSION_LAUNCHER="$TERMINAL_SESSION_LAUNCHER" \
        RUN_TERMINAL_LAUNCHER_MODE=zsh-interactive \
        script -qefc "$TMP/run-terminal-launcher" /dev/null >/dev/null 2>&1
}

run_terminal_launcher_non_tty() {
    env HOME="$TERMINAL_SESSION_HOME" \
        XDG_CONFIG_HOME="$TERMINAL_SESSION_CONFIG" \
        PATH="$(terminal_session_path)" \
        TERMINAL_SESSION_LAUNCHER="$TERMINAL_SESSION_LAUNCHER" \
        RUN_TERMINAL_LAUNCHER_MODE=zsh-interactive \
        "$TERMINAL_SESSION_LAUNCHER" </dev/null >/dev/null 2>"$TMP/terminal-launcher.err"
}

run_terminal_launcher_noninteractive_tty() {
    env HOME="$TERMINAL_SESSION_HOME" \
        XDG_CONFIG_HOME="$TERMINAL_SESSION_CONFIG" \
        PATH="$(terminal_session_path)" \
        TERMINAL_SESSION_LAUNCHER="$TERMINAL_SESSION_LAUNCHER" \
        RUN_TERMINAL_LAUNCHER_MODE=bash-noninteractive \
        script -qefc "$TMP/run-terminal-launcher" /dev/null >/dev/null 2>&1
}

assert_terminal_events() {
    assert_file_content "$TERMINAL_SESSION_EVENTS" "$1"
}

test_terminal_launcher_contracts() {
    setup_terminal_session_fixture
    cat > "$TMP/run-terminal-launcher" <<'EOF'
#!/bin/bash
case "${RUN_TERMINAL_LAUNCHER_MODE:?}" in
    zsh-interactive) exec /usr/bin/zsh -f -i -c 'source "$1"' launcher "$TERMINAL_SESSION_LAUNCHER" ;;
    bash-noninteractive) exec /bin/bash "$TERMINAL_SESSION_LAUNCHER" ;;
    *) exit 64 ;;
esac
EOF
    chmod 0755 "$TMP/run-terminal-launcher"

    write_terminal_session_state herdr
    run_terminal_launcher_tty || test_fail 'Herdr did not start in a guarded TTY'
    assert_terminal_events $'herdr\n'

    : > "$TERMINAL_SESSION_EVENTS"
    write_terminal_session_state tmux
    run_terminal_launcher_tty || test_fail 'TMUX did not start in a guarded TTY'
    assert_terminal_events $'tmux\n'

    for invalid_state in none unsupported $'herdr\ntmux\n'; do
        : > "$TERMINAL_SESSION_EVENTS"
        write_terminal_session_state "$invalid_state"
        run_terminal_launcher_tty || test_fail "invalid state failed the shell: $invalid_state"
        assert_terminal_events ''
    done

    : > "$TERMINAL_SESSION_EVENTS"
    rm -f "$TERMINAL_SESSION_CONFIG/reaan/terminal-dots.conf"
    run_terminal_launcher_tty || test_fail 'missing state failed the shell'
    assert_terminal_events ''

    : > "$TERMINAL_SESSION_EVENTS"
    write_terminal_session_state herdr
    rm -f "$TERMINAL_SESSION_HOME/.local/bin/herdr"
    run_terminal_launcher_tty || true
    assert_terminal_events ''

    : > "$TERMINAL_SESSION_EVENTS"
    write_terminal_session_state herdr
    cat > "$TERMINAL_SESSION_HOME/.local/bin/herdr" <<'EOF'
#!/bin/bash
printf 'herdr\n' >> "${TERMINAL_SESSION_EVENTS:?}"
exit 23
EOF
    chmod 0755 "$TERMINAL_SESSION_HOME/.local/bin/herdr"
    run_terminal_launcher_tty || true
    assert_terminal_events $'herdr\n'

    for guard in TMUX ZELLIJ HERDR_ENV; do
        : > "$TERMINAL_SESSION_EVENTS"
        write_terminal_session_state tmux
        export "$guard=nested-session"
        run_terminal_launcher_tty || test_fail "$guard guard failed the shell"
        assert_terminal_events ''
        unset "$guard"
    done

    : > "$TERMINAL_SESSION_EVENTS"
    write_terminal_session_state tmux
    run_terminal_launcher_non_tty || test_fail 'non-TTY launcher failed the shell'
    assert_terminal_events ''

    : > "$TERMINAL_SESSION_EVENTS"
    write_terminal_session_state herdr
    run_terminal_launcher_noninteractive_tty || test_fail 'noninteractive TTY launcher failed the shell'
    assert_terminal_events ''
}

test_zsh_has_no_terminal_session_hook() {
    for forbidden_reference in terminal-session.sh terminal_session_launcher terminal_session_launch; do
        ! grep -Fq -- "$forbidden_reference" "$ROOT/dot_zshrc" || \
            test_fail "dot_zshrc references removed terminal session hook: $forbidden_reference"
    done
}

test_repository_boundary
test_herdr_official_success
test_herdr_official_failures
test_herdr_existing_binary_idempotence
test_documentation_like_execution_boundary
test_final_provenance_and_boundaries
test_decline_and_prompt_defaults
test_state_safety_and_config_preservation
test_opt_out_preserves_prior_installation
test_none_prewrite_and_failure_reset
test_tmux_install_success
test_terminal_launcher_contracts
test_zsh_has_no_terminal_session_hook
printf 'PASS: installer and terminal session contracts (13 scenario groups)\n'
