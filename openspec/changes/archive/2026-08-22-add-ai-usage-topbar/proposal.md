# Proposal: Add AI Usage to the Top Bar

## Intent

Make AI usage discoverable from the Quickshell top bar without conflating different kinds of usage. V1 assumes “AI Usage” means local OpenCode token and cost analytics; the request did not define the term more precisely. The feature is read-only and keeps OpenCode as the source of truth.

## Scope

### In Scope
- Add a compact, clickable AI Usage affordance to the top bar.
- Open a dedicated monitor-aware popup with period totals, token categories, available provider/model breakdowns, source freshness, and manual refresh.
- Read local OpenCode SQLite data through a small Python standard-library adapter with a stable JSON boundary and fixture-backed failure/privacy tests.
- Preserve the last successful snapshot while reporting missing, stale, malformed, locked, or schema-incompatible sources explicitly.

### Out of Scope
- Application wall-clock tracking, including changes to `app_tracker.py` or `AppUsageView.qml`.
- Provider quota dashboards, online APIs, multiple provider adapters, network access, credentials, auth files, prompts, or raw message content.
- A new daemon, persistent usage cache, keybind, or unrelated Super F2 dashboard redesign.

## Capabilities

### New Capabilities
- `ai-usage-analytics`: Discoverable local OpenCode token/cost summaries with read-only collection, privacy boundaries, freshness, and failure states.

### Modified Capabilities
- None. The new capability must conform to existing portable-path, safe-process, and hermetic-testing requirements without changing their contracts.

## Approach

Use a dedicated top-bar pill and popup. QML owns presentation, polling, monitor-aware visibility, and last-known-good state. A Python adapter resolves the OpenCode database through XDG data conventions, opens it read-only with `sqlite3`, aggregates stable session counters, and emits optional provider/model details without reading prompts or secrets. Missing data is never displayed as zero. No network or credential path is introduced.

## Privacy and Process Boundaries

Only normalized aggregates and approved provider/model metadata cross into QML. The adapter MUST NOT read prompts, raw messages, credentials, or auth material; database paths are passed as discrete arguments, never interpolated into shell source, and secrets never enter `argv`.

## Freshness and Error Behavior

Each snapshot reports its generation time and status. Polling and manual refresh may observe live SQLite writes, so the UI retains the last known good data and shows age plus an actionable missing, stale, malformed, locked, or schema error instead of clearing data or implying quota accuracy.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `dot_config/quickshell/StatusBar.qml`, `shell.qml` | Modified | Top-bar affordance and dedicated popup lifecycle. |
| `dot_config/quickshell/AiUsageView.qml` | New | Summary, detail, freshness, loading, and error states. |
| `dot_config/quickshell/components/RuntimePaths.qml` | Modified | XDG/OpenCode path resolution. |
| `dot_config/scripts/ai_usage.py` | New | Read-only SQLite normalization boundary. |
| `tests/test_ai_usage.sh` | New | Fixture, privacy, failure, and process-boundary coverage. |

## Risks and Tradeoffs

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| “AI Usage” expectation includes quotas or app time | High | Label and document v1 as local OpenCode analytics; defer other scopes. |
| OpenCode schema, locking, or availability varies | Med | Stable adapter contract, explicit statuses, timestamps, and last-known-good retention. |
| Usage metadata exposes private context | Med | Read only aggregates and approved metadata; never prompts, credentials, or raw messages. |

The dedicated popup costs more UI state than an inline indicator, but it preserves discoverability and makes diagnostics understandable.

## Rollback Plan

Remove the AI Usage pill, popup, adapter, path additions, tests, and any test-command registration. Existing application tracking and dashboard behavior remain unchanged.

## Dependencies

- Local OpenCode SQLite database and Python’s standard-library `sqlite3`; no external service.

## Success Criteria

- [ ] A top-bar click opens a monitor-aware read-only AI Usage view with explicit freshness and error states.
- [ ] Valid local OpenCode fixtures produce correct token/cost aggregates without prompt or credential exposure.
- [ ] Missing or invalid sources never appear as zero usage, and existing application-time tracking is unchanged.
