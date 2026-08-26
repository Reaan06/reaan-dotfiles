# Design: Optional Terminal DOTS with Herdr

## Technical Approach

Rename the Arch installer to `install.sh`; keep its existing Kitty, Zsh, Hyprland, package, and deployment flow. Add a default-no terminal-DOTS prompt, followed only on opt-in by a Herdr-default/TMUX choice. Persist one line (`none`, `herdr`, or `tmux`) under `${XDG_CONFIG_HOME:-$HOME/.config}/reaan/terminal-dots.conf`. A deployed session launcher reads that state; `dot_zshrc` invokes it only for an interactive TTY shell outside TMUX, Zellij, or Herdr. Kitty remains `$terminal` in Hyprland.

## Architecture Decisions

| Decision | Choice | Rejected | Rationale |
|---|---|---|---|
| Runtime boundary | Install only the selected runtime; TMUX via `yay`, Herdr as a verified user binary | Install both or import Gentleman.Dots wholesale | Keeps opt-out inert, avoids TPM/plugin coupling, and preserves user-config ownership. |
| State safety | Write `none` before optional installation, then atomically replace it with the selected value only after all checks succeed | Keep a failed previous selection active | A failed rerun cannot auto-start stale software; packages and user files remain untouched. |
| Herdr provenance | Vendor `dot_config/herdr/config.toml` from Gentleman.Dots commit `6b02894b71dc223105091729ebd673ea64e03fb0` (blob `b9f15f533a08e4464bacc59194110ed0527346fc`); copy only when absent | Fetch config at install time | The source is auditable and idempotent. Gentleman.Dots verifies `brew install herdr` but does not publish a Herdr Linux release URL/hash; no checksum is invented. |

## Data Flow

`install.sh` → prompt normalization → atomic `none` → selected runtime install/verification → optional config copy → atomic selected state → Zsh guard → `terminal-session.sh` → exactly Herdr or TMUX.

The state directory is user-only; the state file is mode `0600`. Write a temporary file in the same directory with `umask 077`, close it, then `mv` it into place. Invalid, missing, or multi-line state parses as `none`.

## File Changes

| File | Action | Description |
|---|---|---|
| `install-arch.sh` | Rename/delete | Replace with `install.sh`; preserve script-relative deployment and remove old-name compatibility. |
| `install.sh` | Modify | Add prompts, state helpers, TMUX package path, HTTPS Herdr download boundary, digest check, `0755` binary install, config-preserving copy, and failure reset. Refactor entry execution behind `main` for hermetic tests. |
| `dot_config/herdr/config.toml` | Create | Reviewed snapshot from the verified Gentleman.Dots source above, with provenance documented in README. |
| `dot_config/scripts/terminal-session.sh` | Create | Validate state, re-check nested guards, verify command presence, launch only the selected runtime, and warn/return on failure without fallback. |
| `dot_zshrc` | Modify | Add the interactive plus `-t 0`/`-t 1` and `TMUX`/`ZELLIJ`/`HERDR_ENV` guard; invoke the launcher once. |
| `tests/test_installer.sh`, `README.md` | Create/modify | Hermetic prompt/state/runtime tests and English installation, rollback, provenance, and Kitty boundary documentation. |
| `dot_config/kitty/kitty.conf`, `dot_config/hypr/hyprland.conf` | Verify only | Assert `shell zsh` and `$terminal = kitty`; do not modify. |

## Interfaces / Contracts

```bash
STATE ∈ {none, herdr, tmux}
HERDR_BIN="$HOME/.local/bin/herdr"
```

Blank first prompt means `none`; blank second prompt means `herdr`; invalid answers reprompt. Herdr downloads use HTTPS `curl --fail --location --silent --show-error`, a same-directory temporary file, `sha256sum -c`, then atomic `install -m 0755`; missing verified release metadata is a hard failure. Existing executable and user config are reused, never overwritten. TMUX failure has no Herdr fallback.

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Unit | Prompt gating, defaults, normalization, malformed state, atomic state and config preservation | Source functions with temporary HOME/XDG and feed stdin; stub `yay`, `curl`, and `sha256sum`. |
| Integration | Herdr digest failure, TMUX install failure, exclusive launcher and nested guards | Fake executables log calls and return controlled statuses; assert no real session is launched, no alternate runtime runs, and state becomes `none`. |
| Boundary | Rename, permissions, Kitty/Hyprland invariants, shell syntax | `bash -n`, executable/path assertions, and textual contract checks. |

## Threat Matrix

| Boundary | Applicability | Safe/failure behavior and planned RED test |
|---|---|---|
| Documentation-like paths | Applicable — installer rename and executable classification | Execute only `install.sh`; README/config are never sourced. RED: reject missing/non-executable `install.sh`, executable README, or old-name execution. |
| Git repository selection | N/A — no `git -C`, user repository selector, or VCS target is added; deployment uses `SCRIPT_DIR`. | No task/test. |
| Commit state | N/A — installer never stages or commits files. | No task/test. |
| Push state | N/A — installer never pushes or resolves refs. | No task/test. |
| PR commands | N/A — no PR/VCS automation exists. | No task/test. |

## Migration / Rollout

No package/config migration: opt-out writes `none` and never uninstalls or deletes. The rename is intentionally breaking; rollback restores `install-arch.sh` and writes `none`.

## Open Questions

- [ ] Obtain a verifiable official Herdr v0.8.2 Linux x86_64 asset URL and SHA-256. Gentleman.Dots commit `6b02894...` confirms config and Homebrew guidance, but not this release metadata; implementation MUST remain fail-closed until supplied.
