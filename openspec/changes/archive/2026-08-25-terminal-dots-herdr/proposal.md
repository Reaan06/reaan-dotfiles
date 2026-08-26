# Proposal: Optional Terminal DOTS with Herdr

## Intent

Rename the Arch installer to `install.sh` and add optional terminal sessions without changing Kitty + Zsh when declined. Herdr is a multiplexer/runtime, not an emulator: Kitty remains Hyprland’s `$terminal`; Herdr is the default session experience and TMUX the explicit alternative.

## Scope

### In Scope
- Rename `install-arch.sh` to `install.sh`, preserving script-relative deployment and the declined path.
- Ask default-no “terminal DOTS?”; only after yes ask “Herdr or TMUX?”, defaulting to Herdr.
- Persist `none`, `herdr`, or `tmux` at `$XDG_CONFIG_HOME/reaan/terminal-dots.conf`; reruns are idempotent.
- Opt-out disables startup but does not uninstall software or delete user configs.
- Auto-start only the selected runtime from interactive TTY Zsh with nested-session guards.

### Out of Scope
- Replacing Kitty, changing Hyprland bindings, or replacing Zsh.
- Installing both runtimes, importing upstream TMUX plugins, or taking over Gentleman.Dots.
- Uninstalling packages, deleting user configuration, non-Arch support, or old-name compatibility.

## Capabilities

### New Capabilities
- `installer-terminal-selection`: gated prompts, selection, state, idempotence, and opt-out.
- `terminal-session-integration`: guarded Zsh startup for Herdr or TMUX; Kitty remains the emulator.

### Modified Capabilities
- None.

## Approach

Use `yay` for TMUX. For Herdr, download the official stable Linux x86_64 release over HTTPS to `~/.local/bin/herdr`, pin its published SHA-256 (v0.8.2), and never execute a remote shell pipeline. Copy `dot_config/herdr/config.toml` only when absent; record its source revision and write state atomically. Add hermetic Bash tests and document choices.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `install.sh` | Renamed/Modified | Prompts, optional install, state. |
| `dot_zshrc` | Modified | Guarded selected-runtime startup. |
| `dot_config/herdr/config.toml` | New | Minimal pinned upstream snapshot. |
| `tests/test_installer.sh`, `README.md` | New/Modified | Tests and usage docs. |
| Kitty/Hyprland configs | Unchanged | Verify emulator boundary remains intact. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Release/network failure | Med | HTTPS, digest, temp download, no activation on failure. |
| Nested/stale sessions | Med | TTY plus `TMUX`, `ZELLIJ`, `HERDR_ENV` guards; `none` resets selection. |
| Upstream drift | Med | Vendor reviewed config and record revision. |

## Rollback Plan

Revert optional changes, restore `install-arch.sh`, and set state to `none`; existing packages/configs remain usable.

## Dependencies

- Arch Linux, `yay`, `curl`, `sha256sum`; network only for Herdr.
- Pinned Herdr release and Gentleman.Dots config revision.

## Success Criteria

- [ ] Declining terminal DOTS preserves the current `./install.sh` flow.
- [ ] Herdr defaults second; startup is safe from Kitty/Zsh and TMUX is exclusive.
- [ ] Reruns and opt-out neither duplicate startup nor destroy user state.
- [ ] Tests prove gating, state, digest failure, and unchanged Kitty/Hyprland boundaries.
