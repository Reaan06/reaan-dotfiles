#!/usr/bin/env python3
"""Read-only local OpenCode session usage adapter."""

import json
import math
import os
import re
import sqlite3
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
PERIODS = ("day", "week", "month")
REQUIRED_COLUMNS = (
    "time_created",
    "cost",
    "tokens_input",
    "tokens_output",
    "tokens_reasoning",
    "tokens_cache_read",
)
OPTIONAL_COLUMNS = ("tokens_cache_write", "provider_id", "model_id", "provider", "model")
STALE_AFTER_SECONDS = 24 * 60 * 60
SAFE_METADATA = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:/@+\-]{0,127}$")
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


def finite_number(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise InvalidCounter
    number = float(value)
    if not math.isfinite(number) or number < 0:
        raise InvalidCounter
    return number


def timestamp_seconds(value):
    number = finite_number(value)
    return number / 1000 if number > 100_000_000_000 else number


def safe_metadata(value):
    if isinstance(value, str) and SAFE_METADATA.fullmatch(value):
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
            rows = connection.execute(
                "SELECT " + ", ".join(selected) + " FROM session"
            ).fetchall()
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


def parse_period(argv):
    if len(argv) == 2 and argv[0] == "--period" and argv[1] in PERIODS:
        return argv[1]
    return None


def main(argv=None):
    period = parse_period(sys.argv[1:] if argv is None else argv)
    if period is None:
        print("Usage: ai_usage.py --period <day|week|month>", file=sys.stderr)
        return 64
    print(json.dumps(read_session(database_path(), period, utc_now()), separators=(",", ":"), allow_nan=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
