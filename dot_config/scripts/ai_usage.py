#!/usr/bin/env python3
"""Collect read-only AI usage data for the Quickshell panel."""

import base64
import json
import math
import os
import shutil
import sqlite3
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

PERIODS = ("day", "week", "month")
STALE_AFTER_SECONDS = 24 * 60 * 60
NETWORK_TIMEOUT_SECONDS = 8
REQUIRED_COLUMNS = (
    "time_created",
    "cost",
    "tokens_input",
    "tokens_output",
    "tokens_reasoning",
    "tokens_cache_read",
)
OPTIONAL_COLUMNS = ("tokens_cache_write", "provider_id", "model_id", "provider", "model")


class SchemaError(Exception):
    """The source does not expose the stable session counters."""


class InvalidCounter(Exception):
    """A source counter is not a finite, non-negative number."""


def home_directory():
    return Path(os.environ.get("HOME") or Path.home())


def database_path():
    data_home = Path(os.environ.get("XDG_DATA_HOME") or home_directory() / ".local/share")
    return data_home / "opencode" / "opencode.db"


def utc_now():
    return datetime.now(timezone.utc)


def period_bounds(period, now):
    start = now.astimezone(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    if period == "week":
        start -= timedelta(days=start.weekday())
    elif period == "month":
        start = start.replace(day=1)
    return start.timestamp(), (start + (timedelta(days=1) if period == "day" else
                                        timedelta(days=7) if period == "week" else
                                        _days_in_month(start))).timestamp()


def _days_in_month(start):
    if start.month == 12:
        following = start.replace(year=start.year + 1, month=1, day=1)
    else:
        following = start.replace(month=start.month + 1, day=1)
    return following - start


def source_age(path, now):
    try:
        return max(0, int(now.timestamp() - path.stat().st_mtime))
    except FileNotFoundError:
        return None


def snapshot(status, period, generated_at, age, totals=None, error=None, breakdown=None):
    result = {
        "status": status,
        "generated_at": generated_at.isoformat(timespec="seconds").replace("+00:00", "Z"),
        "period": period,
        "source_age_seconds": age,
        "totals": totals if status == "ok" else None,
    }
    if breakdown:
        result["breakdown"] = breakdown
    if error:
        result["error"] = error
    return result


def provider_card(provider_id, label, status, generated_at, error=None, **values):
    card = {
        "id": provider_id,
        "label": label,
        "status": status,
        "generated_at": generated_at.isoformat(timespec="seconds").replace("+00:00", "Z"),
        "error": error or "",
    }
    card.update(values)
    return card


def finite_number(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise InvalidCounter
    number = float(value)
    if not math.isfinite(number) or number < 0:
        raise InvalidCounter
    return number


def bounded_percent(value):
    number = finite_number(value)
    if number > 100:
        raise InvalidCounter
    return round(number, 1)


def timestamp_seconds(value):
    number = finite_number(value)
    return number / 1000 if number > 100_000_000_000 else number


def safe_metadata(value):
    if isinstance(value, str) and value and len(value) <= 128 and all(
        character.isalnum() or character in "._:/@+-" for character in value
    ):
        return value
    return None


def uri_for(path):
    return f"{path.resolve().as_uri()}?mode=ro"


def read_session(path, period, now):
    age = source_age(path, now)
    if age is None:
        return snapshot("missing", period, now, None, error="source-missing")
    if age > STALE_AFTER_SECONDS:
        return snapshot("stale", period, now, age, error="source-stale")

    start, end = period_bounds(period, now)
    totals = {
        "cost": 0.0,
        "input_tokens": 0.0,
        "output_tokens": 0.0,
        "reasoning_tokens": 0.0,
        "cache_tokens": 0.0,
    }
    groups = {}

    try:
        with sqlite3.connect(uri_for(path), uri=True, timeout=0) as connection:
            connection.row_factory = sqlite3.Row
            connection.execute("PRAGMA query_only = ON")
            schema = connection.execute("PRAGMA table_info('session')").fetchall()
            columns = {row[1] for row in schema}
            if not set(REQUIRED_COLUMNS).issubset(columns):
                raise SchemaError

            selected = list(REQUIRED_COLUMNS)
            selected.extend(column for column in OPTIONAL_COLUMNS if column in columns)
            rows = connection.execute("SELECT " + ", ".join(selected) + " FROM session").fetchall()
            for row in rows:
                created = timestamp_seconds(row["time_created"])
                values = {
                    "cost": finite_number(row["cost"]),
                    "input_tokens": finite_number(row["tokens_input"]),
                    "output_tokens": finite_number(row["tokens_output"]),
                    "reasoning_tokens": finite_number(row["tokens_reasoning"]),
                    "cache_tokens": finite_number(row["tokens_cache_read"]),
                }
                if "tokens_cache_write" in selected:
                    values["cache_tokens"] += finite_number(row["tokens_cache_write"])
                if not start <= created < end:
                    continue

                for key, value in values.items():
                    totals[key] += value

                provider_column = "provider_id" if "provider_id" in selected else "provider"
                model_column = "model_id" if "model_id" in selected else "model"
                provider = safe_metadata(row[provider_column]) if provider_column in selected else None
                model = safe_metadata(row[model_column]) if model_column in selected else None
                if provider and model:
                    group_key = (provider, model)
                    if group_key not in groups:
                        groups[group_key] = {key: 0.0 for key in totals}
                    for key, value in values.items():
                        groups[group_key][key] += value
    except SchemaError:
        return snapshot("schema-error", period, now, age, error="required-columns-missing")
    except sqlite3.OperationalError as error:
        if "locked" in str(error).lower() or "busy" in str(error).lower():
            return snapshot("locked", period, now, age, error="source-locked")
        return snapshot("malformed", period, now, age, error="source-malformed")
    except (sqlite3.DatabaseError, InvalidCounter, OSError, ValueError):
        return snapshot("malformed", period, now, age, error="source-malformed")

    breakdown = []
    for (provider, model), values in sorted(groups.items()):
        breakdown.append({"provider": provider, "model": model, **values})
    return snapshot("ok", period, now, age, totals=totals, breakdown=breakdown)


def _credential_path(environment_name, default_name, filename):
    configured = os.environ.get(environment_name)
    return Path(configured) / filename if configured else home_directory() / default_name / filename


def _cli_status(command):
    return "available" if shutil.which(command) else "unavailable"


def _read_json(path):
    try:
        with path.open(encoding="utf-8") as handle:
            value = json.load(handle)
        return value if isinstance(value, dict) else None
    except (OSError, ValueError, TypeError):
        return None


def _jwt_expired(token, now):
    try:
        payload = token.split(".", 2)[1]
        payload += "=" * (-len(payload) % 4)
        claims = json.loads(base64.urlsafe_b64decode(payload).decode("utf-8"))
        expiry = claims.get("exp")
        return isinstance(expiry, (int, float)) and expiry <= now.timestamp()
    except (IndexError, ValueError, TypeError, UnicodeDecodeError, json.JSONDecodeError):
        return False


def _reset_seconds(value, now):
    if value in (None, ""):
        return None
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        timestamp = timestamp_seconds(value)
    elif isinstance(value, str):
        try:
            timestamp = datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()
        except ValueError as error:
            raise InvalidCounter from error
    else:
        raise InvalidCounter
    return max(0, int(timestamp - now.timestamp()))


def _request_json(url, token, headers):
    request_headers = dict(headers)
    request_headers["Authorization"] = "Bearer " + token
    request = urllib.request.Request(url, headers=request_headers)
    try:
        with urllib.request.urlopen(request, timeout=NETWORK_TIMEOUT_SECONDS) as response:
            status = getattr(response, "status", None)
            if status is None:
                status = response.getcode()
            body = response.read(1024 * 1024)
    except urllib.error.HTTPError as error:
        if error.code == 429:
            return "rate-limited", None
        if error.code in (401, 403):
            return "auth", None
        if error.code == 408 or error.code >= 500:
            return "offline", None
        return "malformed", None
    except (urllib.error.URLError, TimeoutError, OSError):
        return "offline", None

    if status == 429:
        return "rate-limited", None
    if status in (401, 403):
        return "auth", None
    if status != 200:
        return "offline" if status >= 500 else "malformed", None
    try:
        value = json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, ValueError):
        return "malformed", None
    return "ok", value if isinstance(value, dict) else None


def _quota_window(label, value, now):
    if not isinstance(value, dict):
        raise InvalidCounter
    utilization = bounded_percent(value.get("used_percent", value.get("utilization")))
    reset_at = value.get("reset_at", value.get("resets_at"))
    reset_in_seconds = _reset_seconds(reset_at, now)
    return {
        "label": label,
        "utilization": utilization,
        "reset_at": reset_at if isinstance(reset_at, (int, float, str)) else None,
        "reset_in_seconds": reset_in_seconds,
    }


def codex_usage(now):
    path = _credential_path("CODEX_HOME", ".codex", "auth.json")
    if not path.is_file():
        return provider_card("chatgpt", "ChatGPT/Codex", "missing", now, "credentials-missing",
                             windows=[], cli_status=_cli_status("codex"))
    credentials = _read_json(path)
    tokens = credentials.get("tokens") if credentials else None
    token = tokens.get("access_token") if isinstance(tokens, dict) else None
    if not isinstance(token, str) or not token:
        return provider_card("chatgpt", "ChatGPT/Codex", "auth", now, "access-token-missing",
                             windows=[], cli_status=_cli_status("codex"))
    if _jwt_expired(token, now):
        return provider_card("chatgpt", "ChatGPT/Codex", "expired", now, "access-token-expired",
                             windows=[], cli_status=_cli_status("codex"))

    headers = {"Accept": "application/json", "User-Agent": "codex-cli"}
    if isinstance(tokens, dict) and isinstance(tokens.get("account_id"), str) and tokens["account_id"]:
        headers["chatgpt-account-id"] = tokens["account_id"]
    status, response = _request_json("https://chatgpt.com/backend-api/wham/usage", token, headers)
    if status != "ok":
        return provider_card("chatgpt", "ChatGPT/Codex", status, now, "usage-" + status,
                             windows=[], cli_status=_cli_status("codex"))
    try:
        rate_limit = response.get("rate_limit")
        primary = rate_limit.get("primary_window") if isinstance(rate_limit, dict) else None
        windows = [_quota_window("primary", primary, now)]
        secondary = rate_limit.get("secondary_window")
        if isinstance(secondary, dict):
            windows.append(_quota_window("secondary", secondary, now))
        return provider_card("chatgpt", "ChatGPT/Codex", "ok", now, windows=windows,
                             cli_status=_cli_status("codex"))
    except (AttributeError, InvalidCounter, TypeError):
        return provider_card("chatgpt", "ChatGPT/Codex", "malformed", now, "usage-response-malformed",
                             windows=[], cli_status=_cli_status("codex"))


def claude_usage(now):
    path = _credential_path("CLAUDE_CONFIG_DIR", ".claude", ".credentials.json")
    if not path.is_file():
        return provider_card("claude", "Claude", "missing", now, "credentials-missing",
                             windows=[], cli_status=_cli_status("claude"))
    credentials = _read_json(path)
    oauth = credentials.get("claudeAiOauth") if credentials else None
    token = oauth.get("accessToken") if isinstance(oauth, dict) else None
    if not isinstance(token, str) or not token:
        return provider_card("claude", "Claude", "auth", now, "access-token-missing",
                             windows=[], cli_status=_cli_status("claude"))
    expires_at = oauth.get("expiresAt") if isinstance(oauth, dict) else None
    if expires_at is not None:
        try:
            if timestamp_seconds(expires_at) <= now.timestamp():
                return provider_card("claude", "Claude", "expired", now, "access-token-expired",
                                     windows=[], cli_status=_cli_status("claude"))
        except InvalidCounter:
            return provider_card("claude", "Claude", "auth", now, "credential-expiry-invalid",
                                 windows=[], cli_status=_cli_status("claude"))

    headers = {
        "Accept": "application/json",
        "anthropic-beta": "oauth-2025-04-20",
        "anthropic-version": "2023-06-01",
        "User-Agent": "claude-cli/1.0",
    }
    status, response = _request_json("https://api.anthropic.com/api/oauth/usage", token, headers)
    if status != "ok":
        return provider_card("claude", "Claude", status, now, "usage-" + status,
                             windows=[], cli_status=_cli_status("claude"))
    try:
        windows = []
        for key, label in (("five_hour", "5h"), ("seven_day", "weekly")):
            if key in response:
                windows.append(_quota_window(label, response[key], now))
        if not windows:
            raise InvalidCounter
        return provider_card("claude", "Claude", "ok", now, windows=windows,
                             cli_status=_cli_status("claude"))
    except (InvalidCounter, TypeError, AttributeError):
        return provider_card("claude", "Claude", "malformed", now, "usage-response-malformed",
                             windows=[], cli_status=_cli_status("claude"))


def parse_period(argv):
    if len(argv) == 2 and argv[0] == "--period" and argv[1] in PERIODS:
        return argv[1]
    return None


def main(argv=None):
    period = parse_period(sys.argv[1:] if argv is None else argv)
    if period is None:
        print("Usage: ai_usage.py --period <day|week|month>", file=sys.stderr)
        return 64

    now = utc_now()
    opencode = read_session(database_path(), period, now)
    opencode_card = provider_card(
        "opencode", "OpenCode", opencode["status"], now, opencode.get("error", ""),
        period=period,
        source_age_seconds=opencode.get("source_age_seconds"),
        usage=opencode.get("totals"),
        breakdown=opencode.get("breakdown", []),
        cli_status="not-applicable",
    )
    result = dict(opencode)
    result.update({
        "version": 1,
        "providers": [codex_usage(now), claude_usage(now), opencode_card],
    })
    print(json.dumps(result, separators=(",", ":"), allow_nan=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
