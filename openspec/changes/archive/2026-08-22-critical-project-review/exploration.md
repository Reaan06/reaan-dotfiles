## Exploration: critical-project-review

### Current State

#### Review boundary and evidence quality

This review covers the repository at `/home/reaan/reaandots` as observed on 2026-08-14. CodeGraph was unavailable because `.codegraph/` is absent; the review therefore used read-only repository inventory, source inspection, static checks, test execution, and Git history. No source code was modified. The working tree was not clean at the start: `dot_config/hypr/hyprland.conf` already changed `kb_layout = us,es` to `kb_layout = es`; `.atl/` and `openspec/` were already untracked.

The repository contains 124 tracked files: 44 shell scripts, 11 Python files, 35 QML files, 10 configuration files, and 4 test scripts. There is no `.github/` CI workflow, package manifest/lockfile, type checker, formatter, linter, or coverage command. `openspec/config.yaml` defines four Bash smoke/integration tests as the complete verification command, with `strict_tdd: true` but no automated enforcement beyond those scripts.

#### Current architecture

The system is a personal Arch Linux desktop configuration composed of:

- Hyprland declarative configuration and keybindings under `dot_config/hypr/`.
- A Quickshell/QML shell under `dot_config/quickshell/` that renders the bar, dock, overlays, network/Bluetooth panels, wallpaper picker, monitoring, and GitHub views.
- Bash and Python helpers under `dot_config/scripts/`, invoked by QML through `Process`, often via `sh -c`.
- Runtime state files in `$XDG_RUNTIME_DIR`, `/tmp`, `$HOME/.cache`, and `$HOME/.config`.
- `install-arch.sh`, which installs packages, copies configuration, enables services, writes sudoers policy, and optionally builds an absent `eq-service` directory.

This is a distributed process-and-file architecture rather than a single application boundary. The highest-leverage risk is that data, paths, credentials, and process ownership cross those boundaries without one shared contract.

#### Evidence-backed findings

| Priority | Root-cause cluster | Facts observed | Likely impact |
|---|---|---|---|
| P0 | Dynamic shell execution and secret handling | `WifiGraph.qml:122` builds `sh -c` from SSID and sudo password; `GitHubManager.qml:136-139` appends the token to a shell command; `AuraLauncher.qml:148-160`, `DockManager.qml:234-257`, and `DockItem.qml:28-39` build shell commands from desktop/app data. | Credentials can be exposed in process arguments; quote characters can change command meaning; local desktop metadata can become executable shell input. The command-injection paths are statically demonstrable, but exploitability and attacker reach still require runtime confirmation. |
| P1 | No canonical installation/runtime path contract | The repository root is `/home/reaan/reaandots`, while `README.md:18`, `wallpaper_bridge.py:14`, `test_minimal.qml:28`, and `tests/test_quickshell_exec.sh:4` use `/home/reaan/reaan-dotfiles`; `WallpaperPicker.qml:32,84,120` uses hard-coded `/home/reaan/.config/scripts`. | Features and tests depend on one historical machine layout. Wallpaper listing can silently return an empty array, and tests can validate a different path than production. |
| P1 | Tests are not fail-closed or hermetic | `tests/test_quickshell_exec.sh` has no `set -e` and no output assertions. It attempted to execute two nonexistent `/home/reaan/reaan-dotfiles/...` scripts and still exited 0. `test_wifi_scan.sh` uses live `nmcli`; `test_wallpaper_flow.sh` checks only that output contains `[` and mutates runtime state; no QML, installer, lifecycle, or security tests exist. | Green test results do not prove the configured behavior. Broken paths, environment-dependent results, and missing negative-path coverage can ship unnoticed. |
| P1 | Installer has high blast radius and weak recovery | `install-arch.sh:159,162` suppresses copy errors with `|| true`; `:201-207` performs a noninteractive full `yay -Syu --overwrite "*"`; `:360` executes a remote installer via `curl | sh`; `:267-268` writes a NOPASSWD sudoers rule without validation; configuration is deployed before dependencies and there is no backup, dry run, transaction, or rollback. | A failed or partially completed install can leave an unbootable or insecure desktop while reporting success. Package overwrite and remote bootstrap choices enlarge supply-chain and recovery risk. |
| P1 | Process lifecycle and state ownership are ad hoc | Hyprland starts Quickshell, swaync, hypridle, clipboard watchers, and `app_tracker.py` in `hyprland.conf:113-122`; the installer also starts/restarts several services; `shell.qml:153-158` starts `mpris-follow.sh`; `DockManager.qml:448-450` starts `dock_bridge.py`. `app_tracker.py` exists both at `dot_config/scripts/app_tracker.py` and `scripts/app_tracker.py` with divergent content. `dock_bridge.py:118-126` loops forever without a Hyprland socket. | Duplicate processes, stale processes after reloads, unbounded fallback loops, and silent loss of event tracking are plausible. There is no single supervisor, readiness contract, restart policy, or health signal. |
| P1 | Competing wallpaper implementations and state stores | The QML path uses `apply-wallpaper.sh`/`swaybg`; the legacy GTK picker uses `wallpaper-picker.py`/`hyprpaper`; `apply-wallpaper.sh:33` uses `/tmp/swaybg-pids` while `restore-wallpaper.sh:7` uses `$HOME/.cache/swaybg-pids`; restore kills both `swaybg` and `hyprpaper`. | Wallpaper behavior can diverge by entry point, and PID cleanup cannot reliably manage processes created by the other path. This is a concrete architectural split, not merely a documentation issue. |
| P2 | Documentation and repository identity drift | `README.md` documents missing `eq-service/` and the old `/home/reaan/reaan-dotfiles/` layout. `install-arch.sh:237-255` still contains conditional `eq-service` installation. The latest commit removed a large AGS tree, but stale AGS/Caelestia references remain in scripts and keybindings. | New users cannot infer the supported architecture or complete installation from repository documentation. Dead references create user-facing dead ends. |
| P2 | Operational data and privacy controls are implicit | `get_weather.py:10-29` sends IP-derived location to multiple providers, including an HTTP provider, and stores location/history in `~/.cache/weather.json`; `app_tracker.py` records active applications, usage, and package counts. Runtime files use predictable `/tmp` names such as `/tmp/qs-dock-state.json` and `/tmp/qs-colors-raw` without an explicit ownership/permission contract. | Privacy expectations, tamper resistance, and cleanup behavior are undefined. The severity depends on the local threat model and permissions, which should be made explicit before changing implementation. |

#### Validation performed

- `bash -n` passed for all tracked shell scripts.
- Python AST parsing passed for all 11 tracked Python files, but emitted a `SyntaxWarning` for an invalid escape sequence in `get_system_stats.py:42`.
- Bluetooth JSON tests passed.
- WiFi scan test passed against live local NetworkManager state; this is not a hermetic test.
- Wallpaper flow test passed, but its bridge assertion accepts any output containing `[` and the bridge uses the stale `~/reaan-dotfiles/wallps` path.
- The Quickshell execution test exited 0 despite both hard-coded script paths being absent, because failures are not asserted.
- `shellcheck`, package manifests, and CI workflows are absent; QML was not fully runtime-tested because the review environment is not a controlled graphical session.

#### Facts versus hypotheses

The path mismatches, shell-command construction, suppressed installer errors, divergent PID directories, duplicate tracker implementations, absent CI, and the false-green execution test are facts directly evidenced by source or commands above. The following are hypotheses to verify in a proposal/apply phase rather than claims of reproduced production failure:

1. A malicious or specially named desktop entry can reach command execution through the launcher. Reproduce with a harmless local fixture and a command-capture shim; do not use a real destructive payload.
2. A password, token, or SSID containing shell metacharacters can execute an unintended command. Prove with isolated mocks and no real credentials.
3. Repeated Quickshell reloads leak helper processes or create conflicting state writers. Measure process ownership before/after controlled reloads.
4. The wallpaper picker is empty or applies inconsistently on a fresh install. Verify with a temporary HOME and an installed-layout integration fixture.
5. `/tmp` state files are writable by an unintended principal in the target deployment. Check actual directory/file modes and the user/session threat model.

### Affected Areas

- `dot_config/quickshell/WifiGraph.qml`, `dot_config/scripts/get-wifi-pass.sh`, `dot_config/scripts/network-manager.sh` — credential input, shell boundaries, live network behavior, and JSON contract.
- `dot_config/quickshell/GitHubManager.qml`, `dot_config/quickshell/GitHubLinkingView.qml`, `dot_config/scripts/github-fetch.sh` — token persistence, command construction, API error handling, and privacy.
- `dot_config/quickshell/AuraLauncher.qml`, `dot_config/quickshell/DockManager.qml`, `dot_config/quickshell/DockItem.qml`, `dot_config/scripts/app_launcher_data.py` — desktop-file data crossing into shell execution.
- `dot_config/quickshell/WallpaperPicker.qml`, `dot_config/scripts/wallpaper_bridge.py`, `dot_config/scripts/apply-wallpaper.sh`, `dot_config/scripts/restore-wallpaper.sh`, `dot_config/scripts/wallpaper-picker.py` — path resolution, file trust, competing wallpaper engines, and state ownership.
- `dot_config/hypr/hyprland.conf`, `dot_config/hypr/keybinds.conf`, `dot_config/scripts/launch-quickshell.sh`, `dot_config/scripts/app_tracker.py`, `scripts/app_tracker.py`, `dot_config/scripts/dock_bridge.py`, `dot_config/scripts/mpris-follow.sh` — process lifecycle and duplicate implementations.
- `install-arch.sh` — privileged installation, package supply chain, deployment atomicity, validation, and rollback.
- `tests/*.sh`, `openspec/config.yaml`, `README.md`, `docs/`, `conductor/` — quality gates, reproducibility, documentation truth, and change traceability.

### Approaches

1. **Symptom-by-symptom cleanup** — Patch each failing path, script, and UI call site independently.
   - Pros: Small local diffs and low immediate coordination cost.
   - Cons: Preserves the shared causes (dynamic shell boundary, path drift, ad-hoc lifecycle); likely creates inconsistent fixes and repeated regressions.
   - Effort: Medium initially, high over time.

2. **Contract-first chained hardening (recommended)** — Establish one runtime path contract and one safe process/argument boundary, then migrate the highest-risk call sites and make tests prove those contracts. Follow with lifecycle/installer and documentation slices.
   - Pros: Addresses the two highest-leverage root causes, makes failures observable, allows security fixes to land before broad refactoring, and fits the requested `auto-chain` strategy.
   - Cons: Requires coordinated QML/Bash/Python changes and careful compatibility tests; some behavior must be validated in a real Hyprland session.
   - Effort: Medium for the first slice; Medium/High across the chain.

3. **Supervisor/rewrite first** — Replace ad-hoc launchers with user services and consolidate the desktop shell/backend architecture before fixing individual boundaries.
   - Pros: Strong long-term lifecycle and ownership model.
   - Cons: High blast radius, delays the P0 credential fixes, and risks introducing new state/coordination machinery before current contracts are characterized.
   - Effort: High.

### Recommendation

Use Approach 2 and make the first slice **runtime contract and secure execution boundary**. Keep it bounded to the highest-risk paths:

1. Define a portable configuration root/runtime-path contract consumed by the wallpaper bridge, QML helpers, tests, and installer; eliminate repository-user absolute paths and verify a fresh temporary HOME/install layout.
2. Remove data-derived `sh -c` construction from WiFi password retrieval, GitHub fetch invocation, launcher execution, and pin/hide actions. Use argument arrays or controlled stdin/file descriptors; never place passwords or tokens in argv or interpolated shell source. Validate wallpaper inputs remain inside the approved wallpaper directory before copy/apply.
3. Strengthen the first-slice tests: `set -euo pipefail`, fail on missing scripts and nonzero commands, mock `nmcli`/`bluetoothctl`/`hyprctl` where needed, assert exact JSON and error behavior, and add negative tests for shell metacharacters and path traversal. Include a static check that secrets do not appear in constructed process commands.
4. Add explicit acceptance evidence for the real graphical boundary: one controlled Quickshell smoke run, one temporary-HOME install fixture, and a process-list check proving no credential reaches argv. If the environment cannot support these, mark the corresponding scenarios unverified rather than green.

Defer full installer redesign, service supervision, wallpaper-engine consolidation, and documentation cleanup to subsequent chained slices, but make them named follow-up clusters. Do not close any cluster on a self-reported fix: reproduce the current failure shape and run the named regression test on an unmodified baseline where possible.

Suggested chain:

- **Slice 1 — Secure boundary and portable paths:** credential/process safety, path contract, hermetic regression harness.
- **Slice 2 — Lifecycle ownership:** one tracker implementation, supervised helper processes, runtime state directory/permissions, restart and reconnect behavior.
- **Slice 3 — Installer/reproducibility:** preflight, dependency manifest/version policy, backups/rollback, privilege validation, and post-install health checks.
- **Slice 4 — Product/documentation convergence:** select one wallpaper engine, remove dead AGS/Caelestia/eq-service references, update README and operational runbook.

### Risks

- The current working tree contains a pre-existing Hyprland source edit and untracked SDD/bootstrap files; proposal work must preserve and separately review those changes.
- Runtime behavior depends on Arch package versions, Hyprland IPC, Quickshell APIs, Wayland session state, NetworkManager, Bluetooth hardware, and user-specific desktop files. Static evidence alone cannot establish all UI failures.
- Changing credential transport may affect sudo policy, shell prompts, and QML process APIs; security tests must avoid real passwords/tokens and use isolated fixtures.
- Introducing a path contract can change where wallpapers, caches, and credentials are read. A migration/compatibility plan is required to avoid silently losing user state.
- Installer hardening can make failures visible that were previously swallowed. Rollback and recovery instructions are required before enabling stricter gates.
- The project has no automated CI or coverage baseline, so a proposal must define a minimal reproducible test environment rather than claim broad verification.

### Ready for Proposal

Yes. The proposal should state that the change is a systemic hardening review, not a feature rewrite; name the secure execution/path-contract cluster as the first slice; preserve the evidence/hypothesis distinction; and define explicit regression tests and runtime verification gates before implementation.
