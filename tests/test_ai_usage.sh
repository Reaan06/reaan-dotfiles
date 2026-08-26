#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ai-usage.XXXXXX")"
BEFORE="$(git -C "$ROOT" status --porcelain=v1)"
trap 'rm -rf "$TMP"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

for command_name in python3 jq git mktemp; do
    command -v "$command_name" >/dev/null 2>&1 || fail "required command unavailable: $command_name"
done

SCRIPT="$ROOT/dot_config/scripts/ai_usage.py"
AUTH_SCRIPT="$ROOT/dot_config/scripts/ai-provider-auth.sh"
QML="$ROOT/dot_config/quickshell"
HOME="$TMP/home"
XDG_DATA_HOME="$TMP/data"
DB="$XDG_DATA_HOME/opencode/opencode.db"
export HOME XDG_DATA_HOME PYTHONDONTWRITEBYTECODE=1
mkdir -p "$HOME" "$(dirname -- "$DB")"

collect() {
    local period="$1" output
    output="$(python3 "$SCRIPT" --period "$period")" || fail "collector failed for $period"
    jq -e -s 'length == 1 and (.[0] | type) == "object"' <<<"$output" >/dev/null \
        || fail 'collector did not emit one JSON object'
    printf '%s' "$output"
}

clear_db() { rm -f "$DB" "$DB-wal" "$DB-shm"; }

create_valid_db() {
    clear_db
    python3 - "$DB" <<'PY'
import sqlite3
import sys
from datetime import datetime, timezone

now = int(datetime.now(timezone.utc).timestamp() * 1000)
with sqlite3.connect(sys.argv[1]) as connection:
    connection.execute("""
        CREATE TABLE session (
            id TEXT PRIMARY KEY, time_created INTEGER, cost REAL,
            tokens_input INTEGER, tokens_output INTEGER, tokens_reasoning INTEGER,
            tokens_cache_read INTEGER, tokens_cache_write INTEGER,
            provider_id TEXT, model_id TEXT, prompt TEXT, raw_message TEXT,
            secret_marker TEXT
        )
    """)
    connection.execute(
        "INSERT INTO session VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        ("fixture", now, 2, 15, 26, 4, 14, 0, "openai", "gpt-fixture", "prompt", "raw", "secret"),
    )
PY
}

run_provider_cases() {
    HOME="$HOME" OPENAI_HOME="$TMP/openai" CLAUDE_CONFIG_DIR="$TMP/claude" \
        SCRIPT="$SCRIPT" TMP="$TMP" python3 - <<'PY'
import base64
import importlib.util
import json
import os
import urllib.error
from datetime import datetime, timedelta, timezone
from pathlib import Path

spec = importlib.util.spec_from_file_location("ai_usage", os.environ["SCRIPT"])
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)

root = Path(os.environ["TMP"])
openai_dir = Path(os.environ["OPENAI_HOME"])
claude_dir = Path(os.environ["CLAUDE_CONFIG_DIR"])
openai_dir.mkdir(parents=True)
claude_dir.mkdir(parents=True)
openai_secret = "openai-fixture-secret"
claude_secret = "claude-fixture-secret"
now = datetime(2026, 8, 22, 12, 0, tzinfo=timezone.utc)
future = now + timedelta(hours=2)
future_ms = int(future.timestamp() * 1000)

def jwt(expiry):
    payload = base64.urlsafe_b64encode(json.dumps({"exp": expiry}).encode()).decode().rstrip("=")
    return "header." + payload + ".signature"

openai_auth = openai_dir / "auth.json"
claude_auth = claude_dir / ".credentials.json"
openai_token = jwt(future.timestamp())
openai_auth.write_text(json.dumps({"tokens": {"access_token": openai_token, "account_id": "fixture-account"}}))
claude_auth.write_text(json.dumps({"claudeAiOauth": {"accessToken": claude_secret, "expiresAt": future_ms}}))

class Response:
    def __init__(self, body, status=200):
        self.body = body.encode()
        self.status = status
        self.limit = None
    def __enter__(self): return self
    def __exit__(self, *args): return False
    def read(self, limit):
        self.limit = limit
        return self.body[:limit]
    def getcode(self): return self.status

openai_body = json.dumps({"rate_limit": {"primary_window": {"used_percent": 42, "reset_at": future_ms}, "secondary_window": {"used_percent": 17, "reset_at": future_ms}}})
claude_body = json.dumps({"five_hour": {"utilization": 31, "resets_at": future.isoformat().replace("+00:00", "Z")}, "seven_day": {"utilization": 12, "resets_at": future.isoformat().replace("+00:00", "Z")}})
requests = []

def opener(request, timeout):
    assert timeout == collector.NETWORK_TIMEOUT_SECONDS
    assert request.get_header("Authorization") in ("Bearer " + openai_token, "Bearer " + claude_secret)
    requests.append(request)
    if "chatgpt.com" in request.full_url:
        assert request.headers.get("Chatgpt-account-id") == "fixture-account"
        assert request.get_header("User-agent") == "openai-usage/1.0"
        return Response(openai_body)
    assert request.headers.get("Anthropic-beta") == "oauth-2025-04-20"
    return Response(claude_body)

collector.urllib.request.urlopen = opener
chatgpt = collector.openai_usage(now)
claude = collector.claude_usage(now)
assert chatgpt["status"] == "ok" and chatgpt["windows"][0]["utilization"] == 42
assert chatgpt["label"] == "ChatGPT / OpenAI" and "cli_status" not in chatgpt
assert claude["status"] == "ok" and claude["windows"][0]["utilization"] == 31
assert len(requests) == 2

serialized = json.dumps({"chatgpt": chatgpt, "claude": claude})
assert openai_token not in serialized and openai_secret not in serialized and claude_secret not in serialized

def bounded(request, timeout):
    response = Response(json.dumps({"rate_limit": {"primary_window": {"used_percent": 1}}}) + "x" * (1024 * 1024 + 1))
    result = collector._request_json(request.full_url, "fixture", {})
    assert response.limit is None
    return result

def assert_status(status, opener):
    collector.urllib.request.urlopen = opener
    assert collector.openai_usage(now)["status"] == status

def offline(request, timeout):
    raise urllib.error.URLError("offline fixture")

collector.urllib.request.urlopen = offline
assert collector.openai_usage(now)["status"] == "offline"
assert collector.claude_usage(now)["status"] == "offline"

def malformed(request, timeout):
    if "chatgpt.com" in request.full_url:
        return Response("[]")
    raise urllib.error.HTTPError(request.full_url, 429, "rate limited fixture", {}, None)

collector.urllib.request.urlopen = malformed
assert collector.openai_usage(now)["status"] == "malformed"
assert collector.claude_usage(now)["status"] == "rate-limited"

def response_with_limit(request, timeout):
    response = Response(openai_body)
    original_read = response.read
    def read(limit):
        assert limit == 1024 * 1024
        return original_read(limit)
    response.read = read
    return response

collector.urllib.request.urlopen = response_with_limit
assert collector.openai_usage(now)["status"] == "ok"

openai_auth.unlink()
claude_auth.unlink()
collector.shutil.which = lambda command: None
missing_openai = collector.openai_usage(now)
missing_claude = collector.claude_usage(now)
assert missing_openai["status"] == "missing" and "cli_status" not in missing_openai
assert missing_claude["status"] == "missing" and missing_claude["cli_status"] == "unavailable"

openai_auth.write_text(json.dumps({"tokens": {}}))
claude_auth.write_text(json.dumps({"claudeAiOauth": {"accessToken": claude_secret, "expiresAt": 1}}))
assert collector.openai_usage(now)["status"] == "auth"
assert collector.claude_usage(now)["status"] == "expired"

openai_auth.write_text(json.dumps({"tokens": {"access_token": jwt((now - timedelta(hours=1)).timestamp())}}))
assert collector.openai_usage(now)["status"] == "expired"
assert openai_token not in json.dumps(missing_openai) and claude_secret not in json.dumps(missing_claude)

del os.environ["OPENAI_HOME"]
preferred_auth = Path(os.environ["HOME"]) / ".openai" / "auth.json"
preferred_auth.parent.mkdir(parents=True)
preferred_auth.write_text(json.dumps({"tokens": {"access_token": openai_token}}))
assert collector.openai_usage(now)["status"] == "ok"
preferred_auth.unlink()
legacy_auth = Path(os.environ["HOME"]) / ".codex" / "auth.json"
legacy_auth.parent.mkdir(parents=True)
legacy_auth.write_text(json.dumps({"tokens": {"access_token": openai_token}}))
assert collector.openai_usage(now)["status"] == "ok"
print("PASS: direct provider HTTP, expiry/status handling, bounded responses, and credential non-leakage")
PY
}

run_opencode_cases() {
    local output before after
    create_valid_db
    before="$(sha256sum "$DB")"
    output="$(collect day)"
    jq -e '
        .status == "ok" and .totals.cost == 2 and
        .totals.input_tokens == 15 and .totals.output_tokens == 26 and
        ([.providers[].label] | sort) == ["ChatGPT / OpenAI", "Claude", "OpenCode"] and
        ([.providers[].id] | sort) == ["chatgpt", "claude", "opencode"] and
        (tostring | contains("secret") | not) and
        (tostring | contains("raw") | not) and (tostring | contains("prompt") | not)
    ' <<<"$output" >/dev/null || fail 'OpenCode aggregation or privacy boundary failed'
    after="$(sha256sum "$DB")"
    [[ "$before" == "$after" ]] || fail 'read-only collection changed the SQLite source'

    for period in week month; do
        output="$(collect "$period")"
        jq -e --arg period "$period" '.status == "ok" and .period == $period and .totals.cost == 2' <<<"$output" >/dev/null \
            || fail "period aggregation failed for $period"
    done

    clear_db
    output="$(collect day)"
    jq -e '.status == "missing" and .totals == null and (.providers[] | select(.id == "opencode") | .status) == "missing"' <<<"$output" >/dev/null \
        || fail 'missing OpenCode source status failed'

    create_valid_db
    touch -d '2 days ago' "$DB"
    output="$(collect day)"
    jq -e '.status == "stale" and .totals == null' <<<"$output" >/dev/null || fail 'stale OpenCode source status failed'

    create_valid_db
    printf 'not a sqlite database\n' > "$DB"
    output="$(collect day)"
    jq -e '.status == "malformed" and .totals == null' <<<"$output" >/dev/null || fail 'malformed OpenCode source status failed'
}

run_static_cases() {
    bash -n "$AUTH_SCRIPT" || fail 'provider auth script syntax failed'
    python3 - "$SCRIPT" <<'PY' || fail 'Python compilation failed'
import pathlib
import sys
compile(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"), sys.argv[1], "exec")
PY
    grep -Fq 'mode=ro' "$SCRIPT" || fail 'collector is not explicitly read-only'
    grep -Fq 'query_only' "$SCRIPT" || fail 'collector does not enable SQLite query_only'
    grep -Fq 'https://chatgpt.com/backend-api/wham/usage' "$SCRIPT" || fail 'ChatGPT / OpenAI endpoint is missing'
    grep -Fq 'https://api.anthropic.com/api/oauth/usage' "$SCRIPT" || fail 'Claude endpoint is missing'
    grep -Fq 'openai|claude' "$AUTH_SCRIPT" || fail 'provider validation is missing'
    grep -Fq 'login|logout' "$AUTH_SCRIPT" || fail 'action validation is missing'
    ! grep -Eiq 'eval|xdg-open|browser|bridge|WebKit|QtWebEngine|Chromium' "$AUTH_SCRIPT" \
        || fail 'provider auth script contains a forbidden execution boundary'
    ! grep -Eiq 'subprocess|socket|browser|bridge|WebKit|QtWebEngine|Chromium|xdg-open' "$SCRIPT" \
        || fail 'collector contains a forbidden browser or process boundary'
    ! grep -Eiq 'ai_usage_web_bridge|ai-provider-open|ai-provider-webview|WebKit|QtWebEngine|Chromium|xdg-open|web-only|extension' \
        "$QML/AiUsageView.qml" "$QML/shell.qml" || fail 'production QML retains experimental provider references'
    grep -Fq 'ChatGPT / OpenAI' "$QML/AiUsageView.qml" || fail 'ChatGPT / OpenAI card is missing'
    grep -Fq 'Claude' "$QML/AiUsageView.qml" || fail 'Claude card is missing'
    grep -Fq 'OpenCode' "$QML/AiUsageView.qml" || fail 'OpenCode card is missing'
    grep -Fq 'ai_usage.py' "$QML/shell.qml" || fail 'shell does not launch the direct collector'
    grep -Fq 'aiUsageRefreshQueued = true' "$QML/shell.qml" || fail 'busy AI Usage refreshes are not queued'
    grep -Fq 'aiUsageRequestPeriod' "$QML/shell.qml" || fail 'AI Usage request period is not captured'
    grep -Fq 'if (requestPeriod !== aiUsagePeriod)' "$QML/shell.qml" || fail 'old-period AI Usage responses are not discarded'
    grep -Fq 'aiUsageLastCompletedAt' "$QML/shell.qml" || fail 'AI Usage completion timestamp is missing'
    grep -Fq 'command: ["python3", runtimePaths.scriptsDir + "/ai_usage.py", "--period", aiUsageRequestPeriod]' "$QML/shell.qml" \
        || fail 'collector command does not use the captured request period'
    ! grep -Fq 'if (aiUsageProcess.running) return' "$QML/shell.qml" \
        || fail 'busy AI Usage refreshes are still silently dropped'
    grep -Fq 'onPeriodSelected' "$QML/shell.qml" || fail 'period selector is not wired'
    grep -Fq 'aiProviderAuthProcess' "$QML/shell.qml" || fail 'provider auth process is missing'
    grep -Fq '=== "chatgpt" ? "openai"' "$QML/shell.qml" || fail 'ChatGPT provider id is not mapped to OpenAI auth'
    grep -Fq 'onProviderAuthRequested' "$QML/shell.qml" || fail 'provider auth signal is not wired'
    grep -Fq 'providerAuthRequested' "$QML/AiUsageView.qml" || fail 'provider auth signal is missing'
    grep -Fq 'Opening...' "$QML/AiUsageView.qml" || fail 'login progress label is missing'
    grep -Fq 'Logging out...' "$QML/AiUsageView.qml" || fail 'logout progress label is missing'
    grep -Fq 'cached · ' "$QML/AiUsageView.qml" || fail 'cached provider data is not labeled'
    grep -Fq 'refreshMetaText' "$QML/AiUsageView.qml" || fail 'refresh completion metadata is not presented'
    grep -Fq 'cursorShape: Qt.PointingHandCursor' "$QML/AiUsageView.qml" || fail 'AI Usage controls lack pointer feedback'
    grep -Fq 'toggleAiUsage' "$QML/StatusBar.qml" || fail 'AI Usage toggle is missing'
}

run_auth_cases() {
    local bin="$TMP/auth-bin" no_codex_bin="$TMP/no-codex-bin"
    local direct_bin="$TMP/direct-bin"
    local auth_home="$TMP/auth-home" openai_home="$TMP/auth-openai"
    mkdir -p "$bin" "$no_codex_bin" "$direct_bin" "$auth_home/.openai" "$auth_home/.codex" "$openai_home"
    ln -s "$(command -v rm)" "$no_codex_bin/rm"
    ln -s "$(command -v env)" "$direct_bin/env"
    ln -s "$(command -v bash)" "$direct_bin/bash"

    if PATH="$no_codex_bin:/usr/bin:/bin" "$AUTH_SCRIPT" invalid logout >/dev/null 2>&1; then
        fail 'invalid provider was accepted'
    fi
    if PATH="$no_codex_bin:/usr/bin:/bin" "$AUTH_SCRIPT" claude invalid >/dev/null 2>&1; then
        fail 'invalid action was accepted'
    fi

    cat > "$bin/kitty" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" > "${AUTH_KITTY_CAPTURE:?AUTH_KITTY_CAPTURE must be set}"
EOF
    cat > "$bin/claude" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" > "${AUTH_CLAUDE_CAPTURE:?AUTH_CLAUDE_CAPTURE must be set}"
exit "${AUTH_CLAUDE_EXIT:-0}"
EOF
    cat > "$bin/codex" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" > "${AUTH_CODEX_CAPTURE:?AUTH_CODEX_CAPTURE must be set}"
EOF
    chmod +x "$bin/kitty" "$bin/claude" "$bin/codex"

    local kitty_capture="$TMP/kitty.args" claude_capture="$TMP/claude.args" codex_capture="$TMP/codex.args"
    local -a expected actual
    expected=(--title "Claude Login" -e claude auth login)
    AUTH_KITTY_CAPTURE="$kitty_capture" AUTH_CLAUDE_CAPTURE="$claude_capture" \
        PATH="$bin:/usr/bin:/bin" "$AUTH_SCRIPT" claude login >/dev/null
    mapfile -t actual < "$kitty_capture"
    [[ "${actual[*]}" == "${expected[*]}" ]] || fail 'Claude login did not use safe Kitty argv'

    AUTH_CLAUDE_CAPTURE="$claude_capture" PATH="$bin:/usr/bin:/bin" \
        "$AUTH_SCRIPT" claude logout >/dev/null
    mapfile -t actual < "$claude_capture"
    expected=(auth logout)
    [[ "${actual[*]}" == "${expected[*]}" ]] || fail 'Claude logout command is incorrect'

    ln -s "$bin/claude" "$direct_bin/claude"
    local direct_output
    if direct_output="$(AUTH_CLAUDE_CAPTURE="$claude_capture" AUTH_CLAUDE_EXIT=1 \
        PATH="$direct_bin" "$AUTH_SCRIPT" claude login 2>&1)"; then
        fail 'Claude direct login unexpectedly succeeded'
    fi
    [[ "$direct_output" == *'no terminal was available'* ]] || fail 'Claude direct-login failure was not clear'

    local login_output
    if login_output="$(PATH="$no_codex_bin:/usr/bin:/bin" "$AUTH_SCRIPT" openai login 2>&1)"; then
        fail 'OpenAI login unexpectedly succeeded'
    fi
    [[ "$login_output" == *'OpenAI login unavailable'* ]] || fail 'OpenAI login failure was not clear'

    AUTH_CODEX_CAPTURE="$codex_capture" PATH="$bin:/usr/bin:/bin" \
        "$AUTH_SCRIPT" openai logout >/dev/null
    mapfile -t actual < "$codex_capture"
    expected=(logout)
    [[ "${actual[*]}" == "${expected[*]}" ]] || fail 'OpenAI did not prefer codex logout'

    local prioritized="$openai_home/auth.json" preferred="$auth_home/.openai/auth.json" legacy="$auth_home/.codex/auth.json"
    printf 'fixture\n' > "$prioritized"
    printf 'fixture\n' > "$preferred"
    printf 'fixture\n' > "$legacy"
    printf 'keep\n' > "$openai_home/unrelated.txt"
    HOME="$auth_home" OPENAI_HOME="$openai_home" PATH="$no_codex_bin:/usr/bin:/bin" \
        "$AUTH_SCRIPT" openai logout >/dev/null
    [[ ! -e "$prioritized" && -e "$preferred" && -e "$legacy" ]] || fail 'OpenAI logout removed the wrong credential file'
    [[ -d "$openai_home" && -e "$openai_home/unrelated.txt" ]] || fail 'OpenAI logout removed unrelated data'

    rm -f "$preferred"
    HOME="$auth_home" PATH="$no_codex_bin:/usr/bin:/bin" "$AUTH_SCRIPT" openai logout >/dev/null
    [[ ! -e "$legacy" ]] || fail 'OpenAI logout did not prefer ~/.openai over legacy auth'
    mkdir -p "$auth_home/.codex"
    printf 'fixture\n' > "$legacy"
    HOME="$auth_home" PATH="$no_codex_bin:/usr/bin:/bin" "$AUTH_SCRIPT" openai logout >/dev/null
    [[ ! -e "$legacy" && -d "$auth_home/.codex" ]] || fail 'OpenAI legacy logout removed too much or failed'

    printf 'PASS: provider auth validation, safe command argv, and hermetic logout paths\n'
}

run_toggle_case() {
    local bin="$TMP/bin"
    mkdir -p "$bin" "$TMP/runtime"
    printf '#!/bin/bash\nprintf '\''[{"name":"HDMI-A-1","focused":true}]\\n'\''\n' > "$bin/hyprctl"
    chmod +x "$bin/hyprctl"
    XDG_RUNTIME_DIR="$TMP/runtime" PATH="$bin:/usr/bin:/bin" "$ROOT/dot_config/scripts/ai-usage-toggle.sh" toggle
    [[ "$(<"$TMP/runtime/qs-ai-usage")" == 'visible HDMI-A-1' ]] || fail 'Super F4 did not show AI Usage'
    XDG_RUNTIME_DIR="$TMP/runtime" PATH="$bin:/usr/bin:/bin" "$ROOT/dot_config/scripts/ai-usage-toggle.sh" toggle
    [[ "$(<"$TMP/runtime/qs-ai-usage")" == 'hidden HDMI-A-1' ]] || fail 'Super F4 did not hide AI Usage'
}

run_static_cases
run_auth_cases
run_provider_cases
run_opencode_cases
run_toggle_case
[[ "$(git -C "$ROOT" status --porcelain=v1)" == "$BEFORE" ]] || fail 'test changed the worktree'
printf 'PASS: direct AI Usage providers, OpenCode read-only aggregation, privacy, and Super F4 state\n'
