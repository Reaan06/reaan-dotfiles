# Design: Add AI Usage to the Top Bar

## Technical Approach

Add a labeled `AI Usage` pill, monitor-aware popup, and read-only Python boundary. QML owns presentation, period selection, polling, and retention; `ai_usage.py` owns XDG resolution, SQLite aggregation, and JSON. OpenCode remains the source; Super F2 and application tracking remain untouched.

## Architecture Decisions

| Decision | Choice | Alternatives rejected | Rationale |
|---|---|---|---|
| Popup | Dedicated `PanelWindow` in `shell.qml`, using the anchor registry and `PanelConnector`. | Super F2 tab; inline dropdown. | Same-monitor behavior without dashboard redesign. |
| Process | One QML `Process` passes only `--period <day|week|month>` after the script path. | Per-monitor processes; `sh -c`; daemon; `--db`. | Avoids overlap and shell interpolation; Python owns the database. |
| XDG boundary | Adapter resolves `XDG_DATA_HOME`, defaulting to `$HOME/.local/share`, and derives the fixed OpenCode database beneath it. `RuntimePaths` resolves only `scriptsDir`. | QML `dataHome`/`opencodeDbPath`; QML database resolution. | One authoritative hermetic path boundary; QML receives no database path. |
| SQLite | Inspect allowlisted `session` columns with `PRAGMA table_info`; aggregate session rows once, never messages. | SQLite CLI; message summation. | Prevents double counting and schema coupling. |
| Project identity | Both stores use `reaan-dotfiles-quickshell`, mapped to `/home/reaan/reaandots`. | New `reaandots` project. | Preserves the initialized identity. |

## Data Flow

```text
StatusBar → shellRoot.toggleAiUsage(screen.name)
          → Process [python3, runtimePaths.scriptsDir/ai_usage.py, --period, period]
          → ai_usage.py JSON → shellRoot snapshot/status → AiUsageView
```

The popup toggles on the selected monitor and never displays failed data as zero. Failed refreshes retain totals and age; polling refuses overlap.

## File Changes

| File | Action | Description |
|---|---|---|
| `dot_config/quickshell/StatusBar.qml` | Modify | Pill, summary, anchor, toggle, refresh. |
| `dot_config/quickshell/shell.qml` | Modify | Popup state, process/timer, parsing, retention. |
| `dot_config/quickshell/AiUsageView.qml` | Create | Totals, detail, age/status, retry. |
| `dot_config/quickshell/components/RuntimePaths.qml` | Modify | Only `scriptsDir`; no data/database properties. |
| `dot_config/scripts/ai_usage.py` | Create | Read-only SQLite adapter and internal XDG lookup. |
| `tests/test_ai_usage.sh` | Create | Hermetic fixture, privacy, failure, boundary, regression tests. |
| `openspec/config.yaml` | Modify | Append the strict Bash test. |

There are no changes to `app_tracker.py`, `AppUsageView.qml`, or the `app_usage.json` contract; these exclusions remain explicit.

## Interfaces / Contracts

The adapter emits compact JSON with `status`, UTC `generated_at`, `period`, `source_age_seconds`, and `totals`. `period` is `day`, `week`, or `month`; `totals` is null unless `ok`, then has numeric `cost`, `input_tokens`, `output_tokens`, `reasoning_tokens`, and `cache_tokens`. Breakdown uses safe provider/model metadata only. Errors are fixed codes, never paths, exceptions, prompts, or database values. Statuses are exactly `ok`, `missing`, `stale`, `locked`, `malformed`, and `schema-error`.

Required columns are `time_created`, `cost`, `tokens_input`, `tokens_output`, `tokens_reasoning`, and `tokens_cache_read`; optional `tokens_cache_write` is summed. Rows use `period_start <= time_created < period_end`; incomplete provider/model detail is omitted. Absent maps to `missing`, age over 24 hours to `stale`, busy/locked to `locked`, invalid SQLite/counters to `malformed`, missing columns to `schema-error`, otherwise `ok`. Python opens its resolved database read-only with `query_only`; QML passes no database path.

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Fixture/unit | Aggregation, boundaries, JSON shape, metadata, all six statuses. | Temporary HOME/XDG fixtures; exact status/nullability, checksum, one JSON document. |
| Process/privacy | Read-only behavior, no shell source, network, cache, credentials, or database-path argv. | Static checks and isolated doubles; argv is exactly `python3 script --period value`, with no `--db`. |
| Regression | Application-time tracking is unchanged. | Preserve known `app_usage.json` byte-for-byte/hash-identical before/after; static-fail on `app_tracker`, `app_usage.json`, `CACHE_FILE`, or tracker reads. |
| QML | Monitor toggle, anchor, retention/retry, no overlap. | Static checks always; graphical test under the existing availability gate. |

The hermetic entry is exactly `bash tests/test_ai_usage.sh`. It uses `set -euo pipefail`, checks `python3`, `jq`, `git`, and `mktemp` with `command -v`, and emits nonzero `FAIL:` for any missing command. Every adapter call must have the expected exit code, exactly one parseable JSON stdout document, documented fields/status, and no unexpected output. Missing commands and unexpected results are hard failures, never skips. The configured runner appends `&& bash tests/test_ai_usage.sh` after its four commands; graphical behavior remains “required when available.”

## Threat Matrix

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A — fixed paths are never classified as executable input. | None. | None. |
| Git repository selection | N/A — runtime never selects repositories; `git` is test-only evidence. | None. | None. |
| Commit state | N/A — no commit operation. | None. | None. |
| Push state | N/A — no push/ref resolution. | None. | None. |
| PR commands | N/A — no PR automation. | None. | None. |

## Migration / Rollout

No migration required. The feature is local/read-only; rollback removes only the listed feature files and runner entry.

## Open Questions

None.
