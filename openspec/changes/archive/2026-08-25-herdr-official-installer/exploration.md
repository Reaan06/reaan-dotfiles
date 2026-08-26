## Exploration: herdr-official-installer

### Current State

`install.sh` currently preserves the Terminal DOTS state machine but deliberately blocks Herdr: `herdr_release_metadata` always fails, and `install_herdr_runtime` reports that the official Linux x86_64 v0.8.2 metadata is unavailable. An already executable `$HOME/.local/bin/herdr` is reused; otherwise no download is attempted. `configure_terminal_dots` writes `none` atomically before optional installation, activates `herdr` or `tmux` only after success, and resets to `none` on failure without uninstalling or deleting user files. The vendored Herdr config is copied only when the user's config is absent.

The supplied official installer removes the need for locally invented release metadata: it is POSIX shell, fetches `https://herdr.dev/latest.json`, selects Linux/macOS and x86_64/aarch64 assets, validates a 64-hex SHA-256 from that manifest, installs under `${HERDR_INSTALL_DIR:-$HOME/.local/bin}`, and exits on failure. The integration should set `HERDR_INSTALL_DIR` explicitly to the existing `$HOME/.local/bin` target and verify that the expected executable exists before copying config or activating state. It must not duplicate release selection or pin an unprovided version/hash.

The runtime boundary does not need to change. `dot_config/scripts/terminal-session.sh` reads only `none`, `herdr`, or `tmux`, requires an interactive TTY, rejects TMUX/Zellij/Herdr nesting, and launches only the selected runtime with no fallback. `dot_zshrc` and the existing Kitty/Hyprland contract keep Zsh inside Kitty; Herdr remains a session runtime rather than a terminal emulator. Current tests already provide hermetic HOME/XDG fixtures, fake command logs, pseudo-TTY coverage, and no real sessions. The Herdr-specific tests and README still assert the old metadata blocker and must be updated.

### Affected Areas

- `install.sh` — replace the `herdr_release_metadata` gate with the official installer invocation, preserve the existing executable short-circuit, explicit install directory, post-install executable check, atomic `none` prewrite, config-preserving copy, and no-fallback failure path.
- `tests/test_installer.sh` — replace metadata/digest-fixture expectations with hermetic official-installer fixtures covering success, curl failure, installer failure, missing executable after success, existing-binary idempotence, state reset, and absence of TMUX fallback; retain all existing state, opt-out, Kitty/Zsh, and pseudo-TTY scenarios.
- `README.md` — document the official installer and its manifest-based release verification, remove the obsolete unavailable-metadata claim, and disclose the remaining remote-shell supply-chain boundary plus rollback/opt-out behavior.
- `openspec/specs/installer-terminal-selection/spec.md` — future delta should describe Herdr installation failure in terms of the official installer and retain fail-closed activation semantics.
- `openspec/specs/terminal-session-integration/spec.md` — likely unchanged behaviorally; verify that the new installer still supplies the same executable path and exclusive startup contract.
- `openspec/changes/archive/2026-08-25-terminal-dots-herdr/` — read-only historical evidence; do not modify archived artifacts.
- `dot_config/scripts/terminal-session.sh`, `dot_zshrc`, Kitty, and Hyprland configuration — verify only; no runtime-boundary changes are required.

### Approaches

1. **Exact official pipe** — run `curl -fsSL https://herdr.dev/install.sh | HERDR_INSTALL_DIR="$HOME/.local/bin" sh` after the state has been reset to `none`.
   - Pros: exactly matches the published command, has minimal integration code, and delegates platform/architecture selection and manifest SHA-256 validation to the official script.
   - Cons: executes streamed remote shell text; a truncated response can begin executing before `curl` fails, and the installer script itself has no pinned digest or signature in the supplied information. `pipefail` can detect failure but cannot undo side effects already made by the stream.
   - Effort: Low

2. **Downloaded-script execution** — download the official script to a mode-0700 temporary file, execute that complete file with `HERDR_INSTALL_DIR` set, verify the expected executable, and remove the temporary file on every path.
   - Pros: prevents partial streamed script execution, gives a clear download-versus-installer failure boundary, is easier to stub and inspect hermetically, and still uses the official manifest/platform selection and binary checksum validation.
   - Cons: it remains remote-shell execution and is not cryptographically safer without a separately supplied installer-script hash or signature; it adds temporary-file cleanup and does not literally use the published pipe form.
   - Effort: Medium

### Recommendation

Use the downloaded-script approach. It keeps the official installer as the source of release metadata and checksum validation without inventing version data, while avoiding the partial-execution failure mode of a streamed pipe. Treat this as a bounded supply-chain improvement, not as full provenance: the script fetched from `herdr.dev` is still trusted code and should be disclosed in the README. Set `HERDR_INSTALL_DIR` explicitly, keep the existing binary short-circuit, confirm the executable after the official script exits successfully, and activate `herdr` only through the existing atomic state transition. A failed download, failed installer, or missing executable must leave `none` and must not invoke TMUX or remove prior user-owned files.

The exact pipe remains a valid lower-complexity alternative if strict adherence to the published command is prioritized over the safer execution boundary. If selected, retain `set -o pipefail`, check the final executable, and document that pipefail detects command failure but cannot provide rollback for partial remote-script side effects.

### Risks

- The official installer is a remote shell supply-chain boundary; downloaded-first execution reduces partial-stream risk but does not authenticate the installer script itself.
- The official script uses `latest.json`, so release selection can change over time; local code must not add stale version or checksum assumptions.
- A script can fail after making side effects; the installer must keep state at `none` and remain non-destructive rather than attempting an unsafe cleanup or runtime fallback.
- Existing tests explicitly expect missing metadata and no curl activity; leaving those assertions unchanged would falsely preserve the old blocker.
- The official script's internal installation atomicity is outside this repository's contract; tests should assert the state transition and final executable contract, not invent internal implementation details.

### Ready for Proposal

Yes. The proposal should choose downloaded-script execution (or explicitly accept the exact-pipe tradeoff), define the `HERDR_INSTALL_DIR` and post-install executable contract, update the Herdr failure scenarios, and preserve the existing Terminal DOTS state, no-fallback, opt-out, Kitty, Zsh, and hermetic-test requirements. This follow-up appears substantially smaller than the archived change and does not currently require chained PRs unless the implementation/test expansion exceeds the review budget.
