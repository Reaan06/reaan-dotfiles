# Tasks: Critical Project Review — Slice 1

## Review Workload Forecast

| Field | Value |
|---|---|
| Estimated changed lines | 650–800 authored lines |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 → PR 2 → PR 3 |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Apply Delivery Override

- Resolved delivery strategy: `single-pr`
- Maintainer authorization: `size:exception`
- Accepted review budget: 2000 changed lines
- This bounded implementation supersedes the suggested chain only for the current apply run.

### Suggested Work Units

| Unit | Goal / scoped files | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|---|---|---|---|---|---|
| 1 | Path adapters and wallpaper confinement: runtime adapters, wallpaper scripts/bridge, fixtures | PR 1; base = main | `bash tests/test_slice1_boundaries.sh paths` | N/A: temporary-HOME/command doubles only | Revert path adapters, wallpaper files, and fixtures |
| 2 | Safe process adapters/callers: network/GitHub/launcher/pin-hide scripts and QML | PR 2; base = main | `bash tests/test_slice1_boundaries.sh process` | N/A: captured argv/stdin doubles; no live services | Revert process scripts and QML callers |
| 3 | Hermetic runner, graphical gate, and config: existing test scripts, `test_slice1_boundaries.sh`, fixtures, `openspec/config.yaml` | PR 3; base = main | `bash tests/test_quickshell_exec.sh && bash tests/test_bt_json.sh && bash tests/test_wifi_scan.sh && bash tests/test_wallpaper_flow.sh` | Controlled Wayland/Hyprland/Quickshell session; record identity/boundary/result, or `UNVERIFIED` only when unavailable | Revert only tests/config/evidence gate; preserve prior worktree changes |

## Phase 1: RED Tests and Foundation

- [x] 1.1 RED: Create `tests/test_slice1_boundaries.sh` with `paths`/`process` selectors and `tests/fixtures/`; use strict mode, temporary HOME/XDG roots, relocated checkout, valid paths, and missing/nonzero failures.
- [x] 1.2 RED: Add path-security tests for wallpaper `..`, absolute, and outside symlink inputs; assert nonzero exit, no read/apply, and exact stderr.
- [x] 1.3 RED: Add process cases for SSID/desktop/app separators, substitutions, newlines, credentials absent from argv/shell source, preserved output, and temp-HOME/runtime evidence.

## Phase 2: GREEN Path Boundary

- [x] 2.1 GREEN: Implement environment-rooted `runtime-paths.sh`, `runtime_paths.py`, and `components/RuntimePaths.qml` using `QS_CONFIG_HOME`, `QS_RUNTIME_DIR`, and `QS_WALLPAPER_ROOT`.
- [x] 2.2 GREEN: Harden `wallpaper_bridge.py` and `apply-wallpaper.sh` with canonicalization and approved-root confinement; run path tests after each minimal change.
- [x] 2.3 TRIANGULATE then REFACTOR path adapters with relocated layouts and edge cases; keep tests green after each refactor.

## Phase 3: GREEN Process Boundaries and Wiring

- [x] 3.1 GREEN: Convert `network-manager.sh`, `get-wifi-pass.sh`, and `github-fetch.sh` to discrete argv plus stdin/FD credentials; satisfy process RED cases.
- [x] 3.2 GREEN: Add `app-launch.py` and `github-config.py`; harden `pin_app.py` and `hide_app.py` with literal argv protocols and fail-closed errors.
- [x] 3.3 GREEN: Migrate `WifiGraph`, `GitHubManager`, `GitHubLinkingView`, `AuraLauncher`, `DockManager`, `DockItem`, and `shell.qml` to `RuntimePaths.qml` and direct `Process` argv.
- [x] 3.4 TRIANGULATE valid, metacharacter/newline, nonzero, and secret-capture cases; REFACTOR without changing JSON, UI, or state-file contracts.

## Phase 4: Integration and Verification

- [x] 4.1 Update `tests/test_quickshell_exec.sh`, `test_wifi_scan.sh`, `test_wallpaper_flow.sh`, fixtures, and `openspec/config.yaml`; enforce strict fail-closed assertions and worktree snapshots.
- [x] 4.2 Run the exact full runner; exercise controlled Quickshell evidence when available, otherwise record `UNVERIFIED`; verify `install-arch.sh` compatibility only and make no out-of-scope edits.
