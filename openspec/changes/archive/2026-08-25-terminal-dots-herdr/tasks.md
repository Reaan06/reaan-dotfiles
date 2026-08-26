# Tasks: Optional Terminal DOTS with Herdr

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 650-800 authored lines |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 installer/state; PR 2 startup integration; PR 3 provenance/docs/boundaries |
| Delivery strategy | auto-chain |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Rename and make selection/state safe | PR 1 | `bash tests/test_installer.sh` | Temp HOME/XDG with stub `yay`, `curl`, `sha256sum`; no real installs | `install.sh`, `install-arch.sh`, installer tests |
| 2 | Add exclusive guarded startup | PR 2 | `bash tests/test_installer.sh` | Fake Herdr/TMUX executables and TTY/guard matrix; no real session | `dot_zshrc`, `dot_config/scripts/terminal-session.sh`, launcher tests |
| 3 | Close Herdr provenance gate and document boundaries | PR 3 | `bash tests/test_installer.sh && bash -n install.sh dot_config/scripts/terminal-session.sh` | N/A until verified upstream URL/hash exist; fail-closed test is the harness | config snapshot, README, boundary assertions, related tests |

## Phase 1: RED Contracts / Foundation

- [x] 1.1 RED: In `tests/test_installer.sh`, reject missing/non-executable `install.sh`, executable README/config, and any old-name execution; add prompt-gating/default and invalid-answer cases.
- [x] 1.2 RED: Add failing state tests for `none` prewrite, atomic same-directory replacement/mode `0600`, malformed/multiline stale state, rerun singularity, and config preservation.
- [x] 1.3 RED: Add failing Herdr digest/missing-metadata and TMUX-install failure tests proving no activation, no fallback, no uninstall, and state reset to `none`.
- [x] 1.4 RED: Add failing launcher/Zsh tests for interactive TTY only, `TMUX`/`ZELLIJ`/`HERDR_ENV` nesting, `none`, Herdr/TMUX exclusivity, missing runtime, and failed start.

## Phase 2: GREEN Implementation

- [x] 2.1 Rename `install-arch.sh` to `install.sh`, preserve script-relative deployment/declined flow, and refactor entry execution behind `main`.
- [x] 2.2 In `install.sh`, implement normalized default-no/default-Herdr prompts, XDG state helpers, atomic `none`-then-selected activation, idempotent config copy, and failure-safe reset.
- [x] 2.3 Before Herdr download code, require verified official Linux x86_64 v0.8.2 HTTPS URL and SHA-256; if unavailable, implement an explicit hard-failure blocker with no invented metadata or unsafe download.
- [x] 2.4 Create `dot_config/scripts/terminal-session.sh` and modify `dot_zshrc` for guarded, one-runtime-only startup with no fallback or loop.

## Phase 3: Provenance / Verification

- [x] 3.1 Create `dot_config/herdr/config.toml` only from the pinned Gentleman.Dots commit/blob; document provenance, install/rollback, opt-out, and Kitty/Hyprland boundaries in `README.md`.
- [x] 3.2 Make all RED tests pass hermetically; verify `dot_config/kitty/kitty.conf` and `dot_config/hypr/hyprland.conf` unchanged with `shell zsh` and `$terminal = kitty`, plus shell syntax, paths, permissions, and rename checks.
