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
HOME="$TMP/home"
XDG_DATA_HOME="$TMP/data"
DB="$XDG_DATA_HOME/opencode/opencode.db"
export HOME XDG_DATA_HOME
mkdir -p "$HOME" "$(dirname -- "$DB")"
assert_json_document() {
    local output="$1"
    jq -e -s 'if length == 1 and (.[0] | type) == "object" then true else false end' <<<"$output" >/dev/null \
        || fail 'adapter did not emit exactly one JSON object'
}
collect() {
    local period="$1" output
    : > "$TMP/stderr"
    output="$(python3 "$SCRIPT" --period "$period" 2>"$TMP/stderr")" \
        || fail "adapter failed for period $period: $(<"$TMP/stderr")"
    [[ ! -s "$TMP/stderr" ]] || fail "adapter wrote unexpected stderr: $(<"$TMP/stderr")"
    assert_json_document "$output"
    printf '%s' "$output"
}
assert_status() {
    local period="$1" expected="$2" output
    output="$(collect "$period")"
    jq -e --arg expected "$expected" --arg period "$period" \
        '.status == $expected and .period == $period and (.totals == null)' <<<"$output" >/dev/null \
        || fail "expected $expected status with null totals"
}
clear_db() {
    rm -f "$DB" "$DB-wal" "$DB-shm"
}
create_valid_db() {
    clear_db
    python3 - "$DB" <<'PY'
import sqlite3
import sys
from datetime import datetime, timedelta, timezone

database = sys.argv[1]
now = datetime.now(timezone.utc)
day_start = datetime(now.year, now.month, now.day, tzinfo=timezone.utc)
with sqlite3.connect(database) as connection:
    connection.execute(
        """
        CREATE TABLE session (
            id TEXT PRIMARY KEY,
            time_created INTEGER NOT NULL,
            cost REAL NOT NULL,
            tokens_input INTEGER NOT NULL,
            tokens_output INTEGER NOT NULL,
            tokens_reasoning INTEGER NOT NULL,
            tokens_cache_read INTEGER NOT NULL,
            tokens_cache_write INTEGER NOT NULL,
            provider_id TEXT,
            model_id TEXT,
            prompt TEXT,
            raw_message TEXT,
            secret_marker TEXT
        )
        """
    )
    current = int(now.timestamp() * 1000)
    before_day = int((day_start - timedelta(milliseconds=1)).timestamp() * 1000)
    connection.executemany(
        """
        INSERT INTO session VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (
                "current-one", current, 1.25, 10, 20, 3, 4, 5,
                "openai", "gpt-fixture", "do not expose this prompt", "raw message", "fixture-secret",
            ),
            (
                "current-two", current - 1000, 0.75, 5, 6, 1, 2, 3,
                "openai", None, "another prompt", "another raw message", "another-secret",
            ),
            (
                "outside-day", before_day, 99, 900, 900, 900, 900, 900,
                "provider", "model", "outside prompt", "outside message", "outside-secret",
            ),
        ],
    )
PY
}
create_schema_error_db() {
    clear_db
    python3 - "$DB" <<'PY'
import sqlite3
import sys

with sqlite3.connect(sys.argv[1]) as connection:
    connection.execute("CREATE TABLE session (time_created INTEGER, cost REAL)")
PY
}
run_qml_static_cases() {
    local qml="$ROOT/dot_config/quickshell" runtime
    runtime="$qml/components/RuntimePaths.qml"
    grep -Fq 'AI Usage' "$qml/StatusBar.qml" || fail 'top bar does not label AI Usage'
    grep -Fq 'toggleAiUsage' "$qml/StatusBar.qml" || fail 'top bar does not toggle the monitor popup'
    grep -Fq 'aiUsageAnchor' "$qml/StatusBar.qml" || fail 'top bar does not publish an AI Usage anchor'
    grep -Fq 'ai_usage.py' "$qml/shell.qml" || fail 'shell does not launch the adapter'
    grep -Fq 'command: ["python3", runtimePaths.scriptsDir + "/ai_usage.py", "--period", aiUsagePeriod]' "$qml/shell.qml" \
        || fail 'adapter arguments are not period-only'
    ! grep -Fq -- '--db' "$qml/shell.qml" || fail 'QML exposes a database-path argument'
    grep -Fq 'if (aiUsageProcess.running) return' "$qml/shell.qml" \
        || fail 'AI Usage refreshes can overlap'
    grep -Fq 'lastKnownGood' "$qml/shell.qml" || fail 'AI Usage does not retain last-known-good data'
    grep -Fq 'if (status === "ok") lastKnownGood = data' "$qml/shell.qml" \
        || fail 'failed AI Usage refreshes overwrite the good snapshot'
    ! grep -Fq 'lastKnownGood = null' "$qml/shell.qml" || fail 'AI Usage clears retained totals on failure'
    grep -Fq 'aiUsageMonitor' "$qml/shell.qml" || fail 'AI Usage has no monitor identity'
    grep -Fq 'screen.name === aiUsageMonitor' "$qml/shell.qml" || fail 'AI Usage popup is not same-monitor scoped'
    grep -Fq 'qs-ai-usage' "$qml/shell.qml" || fail 'shell does not read the Super F4 AI Usage state'
    grep -Fq 'lastKnownGoodProviders' "$qml/shell.qml" || fail 'AI Usage does not retain providers independently'
    grep -Fq 'PanelConnector' "$qml/AiUsageView.qml" || fail 'AI Usage view has no panel connector'
    for status in ok missing stale locked malformed schema-error; do
        grep -Fq "\"$status\"" "$qml/shell.qml" || fail "missing exact AI Usage status: $status"
    done
    grep -Fq 'ChatGPT/Codex' "$qml/AiUsageView.qml" || fail 'AI Usage view does not label ChatGPT/Codex'
    grep -Fq 'Claude' "$qml/AiUsageView.qml" || fail 'AI Usage view does not label Claude'
    grep -Fq 'OpenCode' "$qml/AiUsageView.qml" || fail 'AI Usage view does not label OpenCode'
    grep -Fq 'scriptsDir' "$runtime" || fail 'RuntimePaths does not expose scriptsDir'
    ! grep -Eq 'XDG_DATA_HOME|opencode|database|\.db' "$runtime" \
        || fail 'RuntimePaths owns OpenCode data resolution'
    ! grep -Eq 'network|credential|password|secret|prompt|message|https?://' "$qml/AiUsageView.qml" \
        || fail 'AI Usage view contains a forbidden privacy boundary'
}

run_runner_static_cases() {
    grep -Fq 'command: "bash tests/test_quickshell_exec.sh && bash tests/test_bt_json.sh && bash tests/test_wifi_scan.sh && bash tests/test_wallpaper_flow.sh && bash tests/test_ai_usage.sh"' \
        "$ROOT/openspec/config.yaml" || fail 'configured runner does not append the AI Usage test'
}

run_provider_cases() {
    PYTHONDONTWRITEBYTECODE=1 HOME="$HOME" CODEX_HOME="$TMP/codex" CLAUDE_CONFIG_DIR="$TMP/claude" \
        SCRIPT="$SCRIPT" TMP="$TMP" python3 - <<'PY'
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
codex_dir = Path(os.environ["CODEX_HOME"])
claude_dir = Path(os.environ["CLAUDE_CONFIG_DIR"])
codex_dir.mkdir(parents=True)
claude_dir.mkdir(parents=True)
codex_secret = "codex-fixture-secret"
claude_secret = "claude-fixture-secret"
now = datetime(2026, 8, 22, 12, 0, tzinfo=timezone.utc)
future = now + timedelta(hours=2)
future_ms = int(future.timestamp() * 1000)
codex_auth = codex_dir / "auth.json"
claude_auth = claude_dir / ".credentials.json"
codex_auth.write_text(json.dumps({"tokens": {"access_token": codex_secret, "account_id": "fixture-account"}}))
claude_auth.write_text(json.dumps({"claudeAiOauth": {"accessToken": claude_secret, "expiresAt": future_ms}}))

class Response:
    def __init__(self, body, status=200):
        self.body = body.encode()
        self.status = status
    def __enter__(self): return self
    def __exit__(self, *args): return False
    def read(self, limit): return self.body[:limit]
    def getcode(self): return self.status

codex_body = json.dumps({"rate_limit": {"primary_window": {"used_percent": 42, "reset_at": future_ms}, "secondary_window": {"used_percent": 17, "reset_at": future_ms}}})
claude_body = json.dumps({"five_hour": {"utilization": 31, "resets_at": future.isoformat().replace("+00:00", "Z")}, "seven_day": {"utilization": 12, "resets_at": future.isoformat().replace("+00:00", "Z")}})

def opener(request, timeout):
    assert timeout == collector.NETWORK_TIMEOUT_SECONDS
    authorization = request.get_header("Authorization")
    assert authorization in ("Bearer " + codex_secret, "Bearer " + claude_secret)
    if "chatgpt.com" in request.full_url:
        return Response(codex_body)
    return Response(claude_body)

collector.urllib.request.urlopen = opener
chatgpt = collector.codex_usage(now)
claude = collector.claude_usage(now)
assert chatgpt["status"] == "ok" and chatgpt["windows"][0]["utilization"] == 42
assert claude["status"] == "ok" and claude["windows"][0]["utilization"] == 31
serialized = json.dumps({"chatgpt": chatgpt, "claude": claude})
assert codex_secret not in serialized and claude_secret not in serialized

def offline(request, timeout):
    if "chatgpt.com" in request.full_url:
        return Response(codex_body)
    raise urllib.error.URLError("offline fixture")

collector.urllib.request.urlopen = offline
assert collector.codex_usage(now)["status"] == "ok"
assert collector.claude_usage(now)["status"] == "offline"

def malformed(request, timeout):
    if "chatgpt.com" in request.full_url:
        return Response("[]")
    raise urllib.error.HTTPError(request.full_url, 429, "rate limited fixture", {}, None)

collector.urllib.request.urlopen = malformed
assert collector.codex_usage(now)["status"] == "malformed"
assert collector.claude_usage(now)["status"] == "rate-limited"

codex_auth.unlink()
claude_auth.unlink()
collector.shutil.which = lambda command: None
missing_codex = collector.codex_usage(now)
missing_claude = collector.claude_usage(now)
assert missing_codex["status"] == "missing" and missing_codex["cli_status"] == "unavailable"
assert missing_claude["status"] == "missing" and missing_claude["cli_status"] == "unavailable"

codex_auth.write_text(json.dumps({"tokens": {}}))
claude_auth.write_text(json.dumps({"claudeAiOauth": {"accessToken": claude_secret, "expiresAt": 1}}))
assert collector.codex_usage(now)["status"] == "auth"
assert collector.claude_usage(now)["status"] == "expired"
print("PASS: provider isolation, mocked network statuses, and credential non-leakage")
PY
}

run_toggle_cases() {
    local bin="$TMP/toggle-bin"
    mkdir -p "$bin" "$TMP/runtime"
    cat > "$bin/hyprctl" <<'EOF'
#!/bin/bash
printf '[{"name":"HDMI-A-1","focused":true}]\n'
EOF
    chmod +x "$bin/hyprctl"
    XDG_RUNTIME_DIR="$TMP/runtime" PATH="$bin:/usr/bin:/bin" \
        "$ROOT/dot_config/scripts/ai-usage-toggle.sh" toggle
    [[ "$(<"$TMP/runtime/qs-ai-usage")" == 'visible HDMI-A-1' ]] || fail 'Super F4 did not write the visible state'
    XDG_RUNTIME_DIR="$TMP/runtime" PATH="$bin:/usr/bin:/bin" \
        "$ROOT/dot_config/scripts/ai-usage-toggle.sh" toggle
    [[ "$(<"$TMP/runtime/qs-ai-usage")" == 'hidden HDMI-A-1' ]] || fail 'Super F4 did not toggle the hidden state'
    XDG_RUNTIME_DIR="$TMP/runtime" PATH="$bin:/usr/bin:/bin" \
        "$ROOT/dot_config/scripts/ai-usage-toggle.sh" show DP-1
    [[ "$(<"$TMP/runtime/qs-ai-usage")" == 'visible DP-1' ]] || fail 'explicit monitor selection was ignored'
    XDG_RUNTIME_DIR="$TMP/runtime" PATH="$bin:/usr/bin:/bin" \
        "$ROOT/dot_config/scripts/ai-usage-toggle.sh" toggle HDMI-A-1
    [[ "$(<"$TMP/runtime/qs-ai-usage")" == 'visible HDMI-A-1' ]] || fail 'toggle did not move the popup to the requested monitor'
    grep -Fq 'bind = Super, F4, exec, ~/.config/scripts/ai-usage-toggle.sh toggle' "$ROOT/dot_config/hypr/keybinds.conf" \
        || fail 'Super F4 binding is missing'
    grep -Fq 'bindn = , F4, exec, ~/.config/scripts/fn-guard.sh mic_toggle' "$ROOT/dot_config/hypr/keybinds.conf" \
        || fail 'plain F4 microphone fallback was hijacked'
}

create_valid_db
CHECKSUM_BEFORE="$(sha256sum "$DB")"
DAY_OUTPUT="$(collect day)"
jq -e '
    .status == "ok" and .period == "day" and
    (.version == 1) and
    (.providers | length == 3) and
    ([.providers[].label] | sort) == ["ChatGPT/Codex", "Claude", "OpenCode"] and
    ([.providers[].id] | sort) == ["chatgpt", "claude", "opencode"] and
    (.generated_at | endswith("Z")) and
    (.source_age_seconds | type == "number") and
    (.totals | type == "object") and
    .totals.cost == 2 and
    .totals.input_tokens == 15 and
    .totals.output_tokens == 26 and
    .totals.reasoning_tokens == 4 and
    .totals.cache_tokens == 14 and
    ((.breakdown // []) | all(.provider != "" and .model != "")) and
    (tostring | contains("fixture-secret") | not) and
    (tostring | contains("raw message") | not) and
    (tostring | contains("do not expose") | not)
' <<<"$DAY_OUTPUT" >/dev/null || fail 'valid fixture aggregation or privacy boundary failed'
CHECKSUM_AFTER="$(sha256sum "$DB")"
[[ "$CHECKSUM_BEFORE" == "$CHECKSUM_AFTER" ]] || fail 'read-only collection changed the SQLite source'

DEFAULT_DB="$HOME/.local/share/opencode/opencode.db"
mkdir -p "$(dirname -- "$DEFAULT_DB")"
cp "$DB" "$DEFAULT_DB"
unset XDG_DATA_HOME
DEFAULT_OUTPUT="$(collect day)"
export XDG_DATA_HOME="$TMP/data"
jq -e '.status == "ok" and .totals.cost == 2' <<<"$DEFAULT_OUTPUT" >/dev/null \
    || fail 'adapter did not resolve the default XDG data directory'

for period in week month; do
    PERIOD_OUTPUT="$(collect "$period")"
    jq -e --arg period "$period" \
        '.status == "ok" and .period == $period and (.totals.cost | type == "number") and .totals.cost >= 2' \
        <<<"$PERIOD_OUTPUT" >/dev/null || fail "period aggregation failed for $period"
done

clear_db
assert_status day missing

create_valid_db
touch -d '2 days ago' "$DB"
assert_status day stale

create_valid_db
LOCK_MARKER="$TMP/locked"
python3 - "$DB" "$LOCK_MARKER" <<'PY' &
import sqlite3
import sys
import time
from pathlib import Path

connection = sqlite3.connect(sys.argv[1], timeout=0)
connection.execute("BEGIN EXCLUSIVE")
Path(sys.argv[2]).write_text("locked", encoding="utf-8")
time.sleep(5)
PY
LOCK_PID=$!
for _ in {1..50}; do
    [[ -f "$LOCK_MARKER" ]] && break
    sleep 0.02
done
[[ -f "$LOCK_MARKER" ]] || fail 'locked fixture did not acquire its exclusive lock'
assert_status day locked
kill "$LOCK_PID" 2>/dev/null || true
wait "$LOCK_PID" 2>/dev/null || true

clear_db
printf 'not a sqlite database\n' > "$DB"
assert_status day malformed

create_schema_error_db
assert_status day schema-error

create_valid_db
run_qml_static_cases
run_runner_static_cases
run_provider_cases
run_toggle_cases
grep -Fq 'sqlite3' "$SCRIPT" || fail 'adapter does not use Python sqlite3'
grep -Fq 'mode=ro' "$SCRIPT" || fail 'adapter is not explicitly read-only'
grep -Fq 'query_only' "$SCRIPT" || fail 'adapter does not enable SQLite query_only'
grep -Fq 'urllib.request.urlopen' "$SCRIPT" || fail 'collector does not own the network boundary'
grep -Fq 'https://chatgpt.com/backend-api/wham/usage' "$SCRIPT" || fail 'Codex endpoint is not explicit'
grep -Fq 'https://api.anthropic.com/api/oauth/usage' "$SCRIPT" || fail 'Claude endpoint is not explicit'
! grep -Eq 'subprocess|socket|requests' "$SCRIPT" \
    || fail 'collector contains an unexpected shell or third-party boundary'
! grep -Eq 'print\([^)]*(token|credential)' "$SCRIPT" \
    || fail 'collector prints credential material'
! grep -Fq -- '--db' "$SCRIPT" || fail 'adapter exposes a database-path argument'

APP_TRACKER_HASH="$(git -C "$ROOT" hash-object dot_config/scripts/app_tracker.py)"
APP_USAGE_VIEW_HASH="$(git -C "$ROOT" hash-object dot_config/quickshell/AppUsageView.qml)"
[[ "$(git -C "$ROOT" hash-object dot_config/scripts/app_tracker.py)" == "$APP_TRACKER_HASH" ]] \
    || fail 'application tracker changed during the fixture run'
[[ "$(git -C "$ROOT" hash-object dot_config/quickshell/AppUsageView.qml)" == "$APP_USAGE_VIEW_HASH" ]] \
    || fail 'application usage view changed during the fixture run'
[[ "$(git -C "$ROOT" status --porcelain=v1)" == "$BEFORE" ]] || fail 'test changed the worktree'
printf 'PASS: AI Usage providers, OpenCode aggregation, privacy, and Super F4 state\n'
