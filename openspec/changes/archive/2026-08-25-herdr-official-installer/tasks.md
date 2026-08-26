# Tasks: Official Herdr Installer Execution

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 170–280 authored lines |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | One bounded work unit / PR 1 |
| Delivery strategy | auto-chain |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Replace the metadata blocker with a verified official-script flow while preserving terminal boundaries | PR 1 | `bash tests/test_installer.sh` | Hermetic sourced-function fixture with fake `curl` and downloaded script; no live network/Arch install | Revert `install.sh`, `tests/test_installer.sh`, `README.md`, and any aligned delta-spec wording |

## Phase 1: RED Contract Tests

- [x] 1.1 In `tests/test_installer.sh`, replace stale metadata/digest fixtures with a fake `curl` and complete fixture script that assert same-directory temp output, private mode `0700`, exact `curl --fail --location --silent --show-error --output TEMP https://herdr.dev/install.sh`, download-before-execution order, and `HERDR_INSTALL_DIR=$HOME/.local/bin`.
- [x] 1.2 Add the RED success scenario: fixture creates executable `$HOME/.local/bin/herdr`; assert post-install executable verification, config preservation, temp removal, and `herdr` state activation.
- [x] 1.3 Add RED failure scenarios for curl failure (script skipped), script failure, and missing executable; each must leave state `none`, remove temp files, preserve user config, and never invoke TMUX.
- [x] 1.4 Add RED idempotence coverage for an existing executable: content remains unchanged and neither curl nor the official script is invoked.
- [x] 1.5 Add the applicable documentation-like-path threat RED test: only repository `install.sh` and the private downloaded temp script execute; README, spec, and config files are never sourced or executed.

## Phase 2: GREEN Implementation

- [x] 2.1 In `install.sh`, remove `herdr_release_metadata`, define `HERDR_INSTALLER_URL='https://herdr.dev/install.sh'`, and short-circuit before curl when `$HOME/.local/bin/herdr` is executable.
- [x] 2.2 Implement private same-directory temp lifecycle under `umask 077`, explicit `0700`, exact curl arguments, direct downloaded-script execution with `HERDR_INSTALL_DIR="$HOME/.local/bin"`, and cleanup on every success/failure path.
- [x] 2.3 Verify the target executable before preserving config or writing `herdr`; retain atomic `none` prewrite/reset, no package removal, no alternate runtime, and no TMUX fallback.
- [x] 2.4 Update `README.md` and align the delta spec only as needed: disclose that the official script owns latest.json/SHA-256 selection, the temp-file trust boundary, fail-closed behavior, and why download-then-execute is used instead of `curl | sh` (avoids partial streaming without inventing metadata).

## Phase 3: Regression Verification

- [x] 3.1 Run `bash tests/test_installer.sh`; retain all existing prompt/state/opt-out/config, launcher, no-TTY, Zsh, Kitty, Hyprland, and TMUX coverage without editing `terminal-session.sh` or Zsh.
- [x] 3.2 Run `bash tests/test_quickshell_exec.sh && bash tests/test_bt_json.sh && bash tests/test_wifi_scan.sh && bash tests/test_wallpaper_flow.sh && bash tests/test_ai_usage.sh`; inspect `git diff --stat` to confirm the bounded work unit remains below budget.
