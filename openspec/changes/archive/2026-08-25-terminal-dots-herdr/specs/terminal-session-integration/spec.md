# Terminal Session Integration Specification

## Purpose

Define guarded runtime startup.

## Requirements

### Requirement: Preserve the emulator boundary and guard startup

Kitty MUST remain the Hyprland emulator and Zsh the shell. Auto-start MAY occur only in interactive TTY Zsh without nested guards; other contexts MUST start nothing.

#### Scenario: Normal terminal launch

- GIVEN Kitty launches interactive TTY Zsh with state `herdr` or `tmux`
- WHEN no nested-session guard is active
- THEN only the selected runtime MUST start; Kitty and Zsh stay unchanged

#### Scenario: Unsafe or nested context

- GIVEN startup is noninteractive, non-TTY, or inside TMUX, Zellij, or Herdr
- WHEN Zsh startup is evaluated
- THEN no runtime MUST launch and the shell stays usable

### Requirement: Launch the selected runtime exclusively

State `herdr` MUST launch only Herdr; `tmux` only TMUX. No fallback is allowed; `none` launches neither.

#### Scenario: Herdr selection

- GIVEN valid state `herdr` and supported Herdr
- WHEN guarded interactive TTY startup runs
- THEN Herdr MUST be the only runtime

#### Scenario: TMUX selection

- GIVEN valid state `tmux` and supported TMUX
- WHEN guarded interactive TTY startup runs
- THEN TMUX MUST be the only runtime

### Requirement: Handle unavailable or stale runtime state safely

Unavailable, unsupported, failed, or stale state MUST not fall back or loop; it MUST produce no automatic session and leave user configuration untouched.

#### Scenario: Herdr or TMUX cannot start

- GIVEN Herdr or TMUX is missing, unsupported, or fails
- WHEN guarded startup runs
- THEN no alternate runtime MUST start and the user retains a usable shell

#### Scenario: Opt-out disables startup

- GIVEN the installer records `none` after prior selection
- WHEN interactive TTY Zsh starts
- THEN no runtime MUST start; Kitty, Zsh, packages, and user configuration remain available
