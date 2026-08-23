# Tasks: Add AI Usage to the Top Bar

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 700–780 authored lines |
| 800-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | One focused work unit: adapter/tests → QML integration → verification |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: feature-branch-chain
400-line budget risk: High
800-line budget risk: Low

Session uses the explicit 800-line budget; the generic 400-line guard is informational. Preserve unrelated worktree changes.

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Deliver local AI usage analytics and top-bar popup | PR 1 | `bash tests/test_ai_usage.sh` | `bash tests/test_graphical_runtime.sh` when its availability gate passes; otherwise N/A with its existing UNVERIFIED result | Revert only the seven listed feature files and runner entry; leave existing tracker/dashboard changes untouched |

## Phase 1: Adapter and Hermetic Tests

- [x] 1.1 **RED:** Create `tests/test_ai_usage.sh` with strict dependency checks, temporary XDG/HOME fixtures, aggregation/period/partial-metadata tests, all six statuses, JSON/null totals, checksum, privacy, argv, shell-source, and tracker-regression assertions (Reqs 2–6; relocated/schema, partial metadata, privacy, failure, deterministic scenarios).
- [x] 1.2 Implement `dot_config/scripts/ai_usage.py`: internal XDG/OpenCode path resolution, read-only `sqlite3`/`query_only`, allowlisted `session` columns, period aggregation without double counting, fixed statuses/errors, UTC JSON, and no prompts/messages/secrets/path leakage.
- [x] 1.3 **GREEN:** Run `bash tests/test_ai_usage.sh`; require one parseable JSON document per call, exact status/nullability, unchanged fixture checksum, and nonzero failures for missing commands or unexpected output.

## Phase 2: QML Path, State, and View Integration

- [x] 2.1 **RED:** Extend the test static checks for no `--db`, no shell interpolation/network/credentials, `RuntimePaths` exposing only `scriptsDir`, bounded non-overlapping refresh, last-known-good retention, exact statuses, and same-monitor toggle/anchor behavior (Reqs 1, 4, 5).
- [x] 2.2 Modify `dot_config/quickshell/components/RuntimePaths.qml` only as needed for `scriptsDir`; add `shell.qml` monitor popup state, one `Process` with `--period`, JSON parsing, retention, retry, and bounded polling using `PanelConnector` anchoring.
- [x] 2.3 Create `dot_config/quickshell/AiUsageView.qml` for period totals/categories, optional safe breakdown, age/status/loading/error/retry states; modify `dot_config/quickshell/StatusBar.qml` with labeled `AI Usage` pill, summary, anchor, toggle, and refresh wiring.
- [x] 2.4 **GREEN:** Re-run `bash tests/test_ai_usage.sh` and prove failed refreshes retain totals, missing data is never shown as zero, and no `app_tracker.py`, `AppUsageView.qml`, or `app_usage.json` contract changes occur.

## Phase 3: Runner, Static, and Runtime Verification

- [x] 3.1 Append `&& bash tests/test_ai_usage.sh` to the four-command runner in `openspec/config.yaml`; do not alter existing commands.
- [x] 3.2 Run the configured runner, `bash tests/test_ai_usage.sh`, and `bash tests/test_graphical_runtime.sh`; record pass evidence or the harness’s controlled unavailable result, and verify `git status --porcelain` preserves all pre-existing unrelated changes.

## Acceptance Evidence

Valid fixtures produce required numeric totals and safe optional metadata; incompatible/failed sources produce exact status with null totals; QML toggles one monitor popup and retains prior good data; static/runtime checks prove no network, credentials, prompt/raw-message access, provider quotas, undocumented schema, or tracker regression.
