## Exploration: add-ai-usage-topbar

### Current State

The active repository is `/home/reaan/reaandots`; `/home/reaan/reaan-dotfiles-quickshell` is only the user-facing alias/pointer. The Quickshell entry point is `dot_config/quickshell/shell.qml`. It creates one `PanelWindow` top bar per `Quickshell.screens`, renders `StatusBar.qml`, and owns the existing monitor-aware popup windows. `StatusBar.qml` uses floating `Pill` components, a centered clock anchor, and a unified right-side system row for compact clickable modules.

Existing dashboard and data patterns are:

- `SuperF2Panel.qml` is the largest reusable dashboard surface. It already provides animated popup presentation, `PanelConnector`, palette propagation, tabs, scrolling content, and an `AppUsageView` tab.
- `AppUsageView.qml` reads `~/.cache/app_usage.json` every five seconds and displays daily/weekly/monthly wall-clock application time, active applications, and package counts.
- `dot_config/scripts/app_tracker.py` is started by `hyprland.conf` and writes `~/.cache/app_usage.json`. It tracks the active Hyprland application and playing MPRIS applications, not AI tokens, API spend, quotas, or model usage. A second divergent copy exists at `scripts/app_tracker.py`.
- No repository file implements AI usage accounting, and no AI-token or provider-quota data source was found under the repository. The existing application tracker recognizes names such as `cursor` and `windsurf`, but that is only application time.
- The inspected host has a populated local OpenCode SQLite database at `~/.local/share/opencode/opencode.db`. Its `session` table contains aggregate `cost`, input/output/reasoning/cache token counters, model, and timestamps. `message.data` contains provider/model/cost/token fields. This is a viable local source for OpenCode usage, but it is host/application data rather than a repository-owned contract and its schema may evolve.
- The current OpenCode database is read-only evidence for exploration only. A schema probe found populated session aggregates and provider/model message records; no credentials or prompt contents are needed for the proposed view.

There is no dedicated top-bar popup toggle for AI usage today. Existing popup state is coordinated through runtime files such as `qs-super-f2`, `qs-audio-manager`, and `qs-bt-panel`, polled by `shell.qml` every 250 ms. A new module can either follow that monitor-aware state pattern or reuse the existing Super F2 dashboard.

### Affected Areas

- `dot_config/quickshell/StatusBar.qml` — add the compact top-bar affordance, summary state, refresh/error indicator, and click interaction in the existing right-side module style.
- `dot_config/quickshell/shell.qml` — if the tool has its own popup, add per-monitor visibility, animation, anchor registration, and a `PanelWindow` using the established `PanelConnector` alignment pattern.
- `dot_config/quickshell/components/RuntimePaths.qml` — likely add an XDG data-home/OpenCode database path abstraction instead of hard-coding a user path in QML or a helper.
- `dot_config/quickshell/components/PanelConnector.qml` and `dot_config/quickshell/components/Pill.qml` — reusable presentation primitives; no change should be needed unless the chosen layout exposes a missing capability.
- `dot_config/quickshell/AiUsageView.qml` — new presentation component for totals, provider/model breakdown, selected period, freshness, loading, missing-source, and error states.
- `dot_config/scripts/ai_usage.py` — new read-only adapter that queries the local OpenCode SQLite database and emits a stable JSON contract. Keeping SQLite and schema knowledge outside QML makes the view testable and avoids adding a database parser to the bar.
- `tests/test_ai_usage.sh` (new) and the configured test command in `openspec/config.yaml` — fixture-backed checks for valid aggregates, missing/corrupt/locked sources, schema drift, no secret/prompt leakage, and preservation of the worktree. The graphical runtime test should cover the affected Quickshell boundary when Wayland/Hyprland/Quickshell are available.
- `dot_config/quickshell/SuperF2Panel.qml` — affected only by the reuse option: it could host an `AI Usage` tab, but that would require a reliable way for a top-bar click to open the panel on the requested tab.
- `dot_config/hypr/hyprland.conf` and `dot_config/hypr/keybinds.conf` — no change is required for a click-only tool. A keybind is an optional product decision, not part of the minimum top-bar scope.

### Approaches

1. **Dedicated top-bar pill and monitor-aware popup** — add a compact AI summary to `StatusBar.qml`, a new `AiUsageView.qml`, and a dedicated `PanelWindow` in `shell.qml`; obtain data through a read-only Python adapter.
   - Pros: directly satisfies the top-bar request; preserves the existing popup/anchor architecture; keeps AI usage independent from unrelated dashboard tabs; supports a useful compact summary plus detailed view; easy to give explicit stale/error states.
   - Cons: adds popup state and one new view; requires a small runtime-state/anchor extension; must define a stable adapter JSON contract around an external SQLite schema.
   - Effort: Medium.

2. **Top-bar pill opening a new AI Usage tab in `SuperF2Panel.qml`** — reuse the existing dashboard window and add an `AiUsageView` tab alongside system, weather, GitHub, and app usage.
   - Pros: least new window chrome; reuses the existing dashboard layout, scrolling, palette, and animation; keeps related usage dashboards together.
   - Cons: the current Super F2 panel has no clean external tab-selection contract; the click must coordinate panel visibility, monitor selection, and tab selection; the broad dashboard is much larger than a focused usage tool and can make the top-bar action surprising.
   - Effort: Medium.

3. **Inline/dropdown-only module** — place the entire AI usage summary in a `Pill` or small anchored item inside `StatusBar.qml`, with no new `PanelWindow`.
   - Pros: smallest file and state change; immediate interaction; no monitor runtime toggle protocol.
   - Cons: insufficient room for model/provider breakdown and error explanations; inline QML would become responsible for data loading and layout; poor usability for historical periods and stale-source diagnostics.
   - Effort: Low for a minimal indicator, High risk of scope growth.

### Recommendation

Choose **Approach 1** with a deliberately narrow v1 data contract: local OpenCode usage only, read-only, no network calls, no credentials, and no changes to the existing application tracker. The top bar should show a compact period summary (for example, today’s cost or token count) and open a dedicated monitor-aware popup containing period totals, input/output/reasoning/cache tokens, provider/model breakdown where available, the source timestamp, and a manual refresh action.

The adapter should resolve the database from XDG data conventions, open it read-only using Python’s standard-library `sqlite3`, aggregate the stable `session` counters, and treat provider/model detail as optional JSON fields. It should emit an explicit status such as `ok`, `missing`, `stale`, or `error`; a missing database must not be rendered as zero usage. QML should retain the last successful snapshot during a failed refresh and visibly report its age/error rather than silently clearing valid data.

This approach is the clearest boundary: QML owns presentation and polling, Python owns SQLite compatibility and normalization, and OpenCode remains the source of truth. It also leaves room for future provider adapters without pretending that application wall-clock time or online quota APIs are equivalent to API usage.

### Risks

- **Product ambiguity:** “AI Usage” could mean API cost/tokens, provider plan quota, AI application time, or all of them. The proposal should explicitly confirm that v1 means local OpenCode token/cost history; provider quotas and app-time analytics are separate scopes.
- **Source availability:** OpenCode may be absent, configured with a different `XDG_DATA_HOME`, or change its SQLite/JSON schema. Missing, malformed, locked, and partially populated databases need distinct user-visible states.
- **Freshness:** polling a live SQLite database can observe an in-progress write or WAL state. The UI needs a generated-at timestamp, a bounded polling interval, and last-known-good retention; it must not imply real-time provider quota accuracy.
- **External dependencies:** the adapter must not require the `sqlite3` CLI, network access, auth files, or provider credentials. Python’s standard library is already present in the project’s helper stack.
- **Privacy:** usage data contains project/model/provider metadata and potentially cost history. The feature should never read or display prompts, credential tokens, auth material, or raw message content, and should not copy usage data into a new persistent cache unless required.
- **Process safety:** follow the repository’s existing process-boundary requirements. Pass paths as discrete process arguments, avoid interpolated `sh -c`, and keep all data-derived strings out of shell source.
- **Testing/runtime:** the repository uses strict Bash smoke/integration tests and requires graphical evidence when a controlled Wayland/Hyprland/Quickshell runtime is available; there is no configured coverage, linter, type checker, or formatter. The current worktree already contains substantial pre-existing changes, so implementation and verification must preserve them.
- **Review budget:** the user supplied an 800-line changed-lines budget, above the default 400-line guard. The recommended slice should still target one focused, reviewable unit and forecast its actual size before apply; no chain is expected unless the design expands into multiple providers or a new daemon.

### Ready for Proposal

Yes, with one product clarification recorded in the proposal: confirm that “AI Usage” means local OpenCode token/cost analytics for v1, not provider quota dashboards or application-time tracking. If that meaning is accepted, proceed to proposal/design with the dedicated popup, read-only Python adapter, explicit freshness/error contract, and fixture-backed tests described above.
