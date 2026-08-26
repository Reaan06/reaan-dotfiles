#!/bin/bash

terminal_session_state_file() {
    printf '%s/reaan/terminal-dots.conf\n' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

terminal_session_read_state() {
    local state_file state

    state_file="$(terminal_session_state_file)"
    if [[ ! -r "$state_file" ]]; then
        printf 'none\n'
        return 0
    fi

    state="$(awk '
        NR == 1 { first = $0 }
        NR > 1 { invalid = 1 }
        END {
            if (NR == 1 && !invalid) print first
            else print "none"
        }
    ' "$state_file" 2>/dev/null)" || state=none
    case "$state" in
        none|herdr|tmux) printf '%s\n' "$state" ;;
        *) printf 'none\n' ;;
    esac
}

terminal_session_guarded() {
    [[ $- == *i* && -t 0 && -t 1 ]] || return 1
    [[ -z "${TMUX:-}" && -z "${ZELLIJ:-}" && -z "${HERDR_ENV:-}" ]] || return 1
}

terminal_session_launch() {
    local state runtime

    terminal_session_guarded || return 0
    state="$(terminal_session_read_state)"
    case "$state" in
        none) return 0 ;;
        herdr)
            runtime="$HOME/.local/bin/herdr"
            if [[ ! -x "$runtime" ]]; then
                printf 'Terminal session unavailable: Herdr is not executable.\n' >&2
                return 1
            fi
            "$runtime"
            ;;
        tmux)
            runtime="$(command -v tmux 2>/dev/null || true)"
            if [[ -z "$runtime" || ! -x "$runtime" ]]; then
                printf 'Terminal session unavailable: TMUX is not installed.\n' >&2
                return 1
            fi
            "$runtime"
            ;;
        *)
            return 0
            ;;
    esac
}

terminal_session_launch
