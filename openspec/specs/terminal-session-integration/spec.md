# Terminal Session Integration Specification

## Purpose

Define explicit, guarded runtime launcher behavior.

## Requirements

### Requirement: Preserve the emulator and shell boundaries

Kitty MUST remain the Hyprland terminal emulator and Zsh the shell. The
repository MUST NOT wire `terminal-session.sh` into `dot_zshrc` or start a
session automatically.

#### Scenario: No Zsh auto-start hook

- GIVEN `dot_zshrc` is loaded by Kitty's Zsh shell
- WHEN Zsh startup is evaluated
- THEN no terminal-session launcher reference or runtime MUST be invoked

#### Scenario: Explicit guarded invocation

- GIVEN the launcher is invoked explicitly from an interactive TTY
- WHEN no TMUX, Zellij, or Herdr nesting guard is active
- THEN it MAY launch the selected runtime and MUST leave Kitty and Zsh boundaries unchanged

#### Scenario: Unsafe or nested explicit invocation

- GIVEN the explicit launcher invocation is noninteractive, non-TTY, or inside TMUX, Zellij, or Herdr
- WHEN the launcher is evaluated
- THEN no runtime MUST launch and the user's shell state MUST remain usable

### Requirement: Launch the selected runtime exclusively

State `herdr` MUST launch only Herdr; `tmux` only TMUX. No fallback is
allowed; `none` MUST be a no-op.

#### Scenario: Herdr selection

- GIVEN valid state `herdr` and supported Herdr
- WHEN explicit guarded interactive TTY launcher invocation runs
- THEN Herdr MUST be the only runtime

#### Scenario: TMUX selection

- GIVEN valid state `tmux` and supported TMUX
- WHEN explicit guarded interactive TTY launcher invocation runs
- THEN TMUX MUST be the only runtime

### Requirement: Handle unavailable or stale runtime state safely

Unavailable, unsupported, failed, or stale state MUST not fall back or loop;
it MUST produce no alternate session and leave user configuration untouched.

#### Scenario: Herdr or TMUX cannot start

- GIVEN Herdr or TMUX is missing, unsupported, or fails
- WHEN explicit guarded launcher invocation runs
- THEN no alternate runtime MUST start and the user retains a usable shell

#### Scenario: None preserves user state

- GIVEN the installer records `none` after prior selection
- WHEN the launcher is invoked explicitly from a guarded interactive TTY
- THEN no runtime MUST start and Kitty, Zsh, packages, and user configuration remain available
