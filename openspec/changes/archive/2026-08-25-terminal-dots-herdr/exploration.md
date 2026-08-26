## Exploration: terminal-dots-herdr

### Current State

The repository has one live installer, `install-arch.sh`, a 471-line Arch-only Bash script. It validates Arch Linux, bootstraps `yay`, asks about browser/editor/Docker/Steam, installs a fixed core including Kitty and Zsh, deploys `dot_config/*` and `dot_zshrc`, and performs privileged service and sudoers setup. No live repository caller references the installer filename, and no TMUX or Herdr configuration exists locally. Archived OpenSpec documents mention `install-arch.sh`, but archived artifacts must not be edited.

Kitty is the terminal emulator: `dot_config/kitty/kitty.conf` starts Zsh, while `dot_config/hypr/hyprland.conf` sets `$terminal = kitty` and the Hyprland keybinds launch that variable. `dot_zshrc` currently has no multiplexer auto-start logic. Therefore Herdr cannot coherently replace the terminal emulator without changing the Hyprland/Kitty boundary; it is a terminal multiplexer/agent runtime.

The referenced Gentleman.Dots repository provides `herdr/config.toml` and documents copying it to `~/.config/herdr/config.toml`. Its shell integration uses a selected multiplexer command with interactive/TTY and nested-session guards (`TMUX`, `ZELLIJ`, and `HERDR_ENV`). Gentleman.Dots documents `brew install herdr`; current Herdr documentation also supports an official Linux installer, Homebrew, mise, Nix, and manual release binaries. The external TMUX configuration depends on TPM and several plugins, so wholesale import would add substantial dependency and maintenance scope.

The repository has strict Bash smoke/integration tests and portable-path/process-boundary coverage, but no installer-specific test. `openspec/config.yaml` enables strict TDD and Bash testing, although its configured runner does not include every existing regression script. There is no formal CI, linter, or type checker.

### Affected Areas

- `install-arch.sh` — rename to `install.sh`; preserve the existing script-directory-derived `DOTFILES_DIR` and base installation flow.
- `dot_zshrc` — add an optional, idempotent startup gate that reads the installer’s selected terminal-DOTS state and starts only the selected multiplexer in interactive TTY shells.
- `dot_config/kitty/kitty.conf` — validate as the unchanged terminal-emulator boundary; no change is recommended.
- `dot_config/hypr/hyprland.conf` — validate that `$terminal` remains `kitty`; changing it to `herdr` would confuse a multiplexer with an emulator.
- `dot_config/herdr/config.toml` — likely new vendored configuration sourced from `Gentleman-Programming/Gentleman.Dots/herdr/config.toml`, with a pinned upstream revision or documented source snapshot.
- `tests/test_installer.sh` — likely new hermetic coverage for rename, prompt branching, selected package/config/state behavior, opt-out behavior, and shell-startup guards; existing test scripts do not cover these boundaries.
- `README.md` — likely document the new `./install.sh` entrypoint and the optional terminal-DOTS choices; current README has no installer instructions.
- `openspec/changes/terminal-dots-herdr/exploration.md` — this exploration artifact only.

### Approaches

1. **Vendored minimal integration with persistent local selection state** — rename the installer, ask opt-in/opt-out and then Herdr/TMUX only when opted in, install the selected executable, vendor only the Herdr configuration needed by this repository, and write a small state file under the user configuration root that `dot_zshrc` reads. Opt-out explicitly disables or resets prior selection.
   - Pros: preserves Kitty as the emulator, preserves current behavior when declined, avoids wholesale Zsh/config replacement, is idempotent, and makes the Herdr configuration auditable.
   - Cons: the Herdr config snapshot needs occasional upstream review; Herdr installation must choose between Homebrew, the official installer, or another supported Linux channel.
   - Effort: Medium

2. **Runtime clone or fetch of Gentleman.Dots** — when selected, clone/fetch the external repository and copy its Herdr/TMUX assets and shell snippets during installation.
   - Pros: follows upstream files without vendoring them into this repository.
   - Cons: introduces a large mutable network dependency, weakens reproducibility, exposes the installer to upstream layout changes, and risks importing external hardcoded paths, shell assumptions, and TMUX plugin requirements.
   - Effort: Medium

3. **Wholesale Gentleman.Dots installer delegation** — invoke the upstream installer or import its complete terminal stack.
   - Pros: delegates tool installation and upstream integration behavior.
   - Cons: it is a separate cross-platform TUI, conflicts with this Arch/Hyprland deployment model and local Kitty/Zsh ownership, and would make opt-out and rollback boundaries unclear.
   - Effort: High

### Recommendation

Use Approach 1. Interpret “primary terminal” as “the primary terminal session experience”: keep Kitty as the Hyprland-launched terminal emulator, keep Zsh as its shell, and auto-start the selected Herdr or TMUX multiplexer from Zsh. Herdr should be the default/primary choice in the second question if that is the intended product preference, while TMUX remains the explicit alternative. If the first answer is negative, install neither optional multiplexer, write a disabled selection state, and leave current Kitty + Zsh behavior unchanged. Do not source the external `.zshrc` wholesale and do not set Hyprland’s `$terminal` to `herdr`.

The proposal must explicitly choose Herdr’s Arch installation channel. The least coupled design is to use the official Herdr Linux installer only after opt-in, with command detection and a clear failure message; if the project requires package-manager-only installation, Homebrew/mise/Nix availability must be treated as a prerequisite rather than silently bootstrapped. The Herdr config should be copied as a writable user file, matching the upstream contract, and its source revision should be recorded.

### Risks

- “Primary terminal” is ambiguous because Herdr is a multiplexer, not a terminal emulator; changing `$terminal` would break the existing Kitty boundary.
- The current Arch installer has no Homebrew, mise, or Nix setup, while Gentleman.Dots documents Homebrew and current Herdr docs offer several channels; installation behavior must not be guessed.
- A direct `curl | sh` installer adds supply-chain and network failure risk inside an already privileged, non-transactional script.
- The Zsh hook must prevent nested Herdr/TMUX sessions and must disable stale prior selections when the user opts out on a later run.
- The upstream TMUX config references TPM/plugins; copying it without an explicit plugin strategy would create a partially working integration.
- The installer performs full system upgrades, privileged writes, and error-suppressing copies, so optional integration failures can leave a partially completed installation without rollback.
- External users or undocumented automation may still invoke `install-arch.sh`; no such caller exists in the live repository, but compatibility outside the repository is unknown.

### Ready for Proposal

Yes, provided the proposal records the terminology decision (Kitty remains the emulator; Herdr/TMUX is the selected multiplexer), the second-question default, the Herdr installation channel, and whether TMUX receives only package support or the full upstream plugin-backed configuration. No application/source files were modified during exploration.
