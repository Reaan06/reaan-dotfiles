#!/usr/bin/env bash
set -euo pipefail

usage() {
    printf 'Usage: ai-provider-auth.sh <openai|claude> <login|logout>\n' >&2
    exit 64
}

[[ $# -eq 2 ]] || usage
provider=$1
action=$2

case "$provider" in
    openai|claude) ;;
    *) usage ;;
esac
case "$action" in
    login|logout) ;;
    *) usage ;;
esac

if [[ "$provider" == "claude" ]]; then
    command -v claude >/dev/null 2>&1 || {
        printf 'Claude %s unavailable: claude command not found\n' "$action" >&2
        exit 127
    }

    if [[ "$action" == "login" ]]; then
        if command -v kitty >/dev/null 2>&1; then
            kitty --title 'Claude Login' -e claude auth login
            printf 'Opening Claude login...\n'
        else
            if claude auth login; then
                printf 'Claude login completed.\n'
            else
                printf 'Claude login failed: no terminal was available for interactive authentication\n' >&2
                exit 1
            fi
        fi
    else
        claude auth logout
        printf 'Claude logged out.\n'
    fi
    exit 0
fi

if [[ "$action" == "login" ]]; then
    printf 'OpenAI login unavailable: no local OpenAI CLI login is available.\n' >&2
    exit 69
fi

if command -v codex >/dev/null 2>&1; then
    codex logout
    printf 'OpenAI logged out with codex.\n'
    exit 0
fi

home=${HOME:-.}
auth_paths=()
if [[ -n ${OPENAI_HOME:-} ]]; then
    auth_paths+=("$OPENAI_HOME/auth.json")
fi
auth_paths+=("$home/.openai/auth.json" "$home/.codex/auth.json")

for auth_path in "${auth_paths[@]}"; do
    if [[ -f "$auth_path" ]]; then
        rm -- "$auth_path"
        printf 'OpenAI credentials removed: %s\n' "$auth_path"
        exit 0
    fi
done

printf 'OpenAI logout: no local credentials found.\n'
