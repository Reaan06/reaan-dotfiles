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
    grep -Fq 'PanelConnector' "$qml/AiUsageView.qml" || fail 'AI Usage view has no panel connector'
    for status in ok missing stale locked malformed schema-error; do
        grep -Fq "\"$status\"" "$qml/shell.qml" || fail "missing exact AI Usage status: $status"
    done
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

create_valid_db
CHECKSUM_BEFORE="$(sha256sum "$DB")"
DAY_OUTPUT="$(collect day)"
jq -e '
    .status == "ok" and .period == "day" and
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
grep -Fq 'sqlite3' "$SCRIPT" || fail 'adapter does not use Python sqlite3'
grep -Fq 'mode=ro' "$SCRIPT" || fail 'adapter is not explicitly read-only'
grep -Fq 'query_only' "$SCRIPT" || fail 'adapter does not enable SQLite query_only'
! grep -Eq 'subprocess|socket|urllib|requests|https?://' "$SCRIPT" \
    || fail 'adapter contains a network or shell execution boundary'
! grep -Fq -- '--db' "$SCRIPT" || fail 'adapter exposes a database-path argument'

APP_TRACKER_HASH="$(git -C "$ROOT" hash-object dot_config/scripts/app_tracker.py)"
APP_USAGE_VIEW_HASH="$(git -C "$ROOT" hash-object dot_config/quickshell/AppUsageView.qml)"
[[ "$(git -C "$ROOT" hash-object dot_config/scripts/app_tracker.py)" == "$APP_TRACKER_HASH" ]] \
    || fail 'application tracker changed during the fixture run'
[[ "$(git -C "$ROOT" hash-object dot_config/quickshell/AppUsageView.qml)" == "$APP_USAGE_VIEW_HASH" ]] \
    || fail 'application usage view changed during the fixture run'
[[ "$(git -C "$ROOT" status --porcelain=v1)" == "$BEFORE" ]] || fail 'test changed the worktree'
printf 'PASS: read-only local OpenCode AI usage adapter (%s statuses, aggregation, privacy, checksum)\n' 6
