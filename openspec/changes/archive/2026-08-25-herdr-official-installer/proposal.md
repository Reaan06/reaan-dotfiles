# Proposal: Use the Official Herdr Installer

## Intent

Replace the obsolete local Herdr release-metadata blocker with Herdr's official installer while keeping Terminal DOTS opt-in and fail-closed. Downloading the complete remote script before execution avoids partial streamed execution, but the remote-shell trust boundary remains and must be disclosed.

## Scope

### In Scope
- Fetch `https://herdr.dev/install.sh` to a private mode-0700 temporary file, execute it with `HERDR_INSTALL_DIR=$HOME/.local/bin`, remove it on every path, and require executable `$HOME/.local/bin/herdr` before activation.
- Preserve atomic `none` prewrite, activation, no fallback, non-destructive opt-out, config preservation, prompts, and Kitty/Zsh boundaries.
- Replace stale metadata tests with hermetic installer fixtures and update README/provenance wording.

### Out of Scope
- Inventing or pinning release versions, URLs, hashes, or installer signatures.
- Changing `terminal-session.sh`, Zsh guards, Kitty, Hyprland, TMUX behavior, or archived artifacts.
- Uninstalling packages, deleting user configuration, or implementing a streamed `curl | sh` fallback.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `installer-terminal-selection`: Herdr installation uses the official downloaded-script flow and post-install executable verification while retaining fail-closed state semantics.

## Approach

Update `install_herdr_runtime` to reuse an existing executable, download a private temporary script with `curl`, execute it with the explicit install directory, clean up, and verify the binary. Copy configuration and activate `herdr` only after checks succeed. Update focused tests for download, installer, missing-binary, cleanup, idempotence, reset, and no-TMUX-fallback paths; retain state, opt-out, pseudo-TTY, and boundary coverage. This is one work unit unless forecasting exceeds the review budget.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `install.sh` | Modified | Official installer execution and verification. |
| `tests/test_installer.sh` | Modified | Hermetic official-installer contract tests. |
| `README.md` | Modified | Manifest/SHA-256 behavior and trust disclosure. |
| `openspec/specs/installer-terminal-selection/spec.md` | Modified | Herdr failure/activation requirement delta. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Remote installer remains trusted shell code and latest metadata can drift | Med | Explicit disclosure; delegate release selection/checksums to official script; no invented pins. |
| Script fails after side effects | Med | Keep state `none`, clean temporary files, never uninstall or fall back. |

## Rollback Plan

Revert the installer, tests, README, and capability delta; restore the metadata blocker. Existing binaries, packages, and user configuration remain untouched.

## Dependencies

- Arch environment with `curl` and the official Herdr endpoint; hermetic tests must stub the network and script.

## Success Criteria

- [ ] Successful Herdr selection installs and verifies the executable, then activates `herdr`.
- [ ] Download, installer, or verification failure leaves `none`, removes the temporary script, and does not invoke TMUX.
- [ ] Existing prompts, opt-out/config preservation, Kitty/Zsh boundaries, and hermetic tests remain green.
