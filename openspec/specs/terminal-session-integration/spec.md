# Terminal Session Integration Specification

## Purpose

Define explicit and guarded session launcher behavior after Gentleman.Dots setup.

## Requirements

Kitty MUST remain the fixed Hyprland terminal emulator, while Gentleman.Dots
owns the selected shell and its safe session auto-start integration. The
repository MUST NOT deploy `dot_zshrc` or add a competing startup hook.

The standalone launcher MUST require an interactive TTY and MUST refuse nested
TMUX, Zellij, or Herdr sessions. Missing, failed, malformed, or stale state MUST
leave the shell usable and MUST NOT trigger a fallback.

State `none` MUST be a no-op. State `herdr`, `tmux`, or `zellij` MUST launch only
that named runtime, resolving the executable without shell interpolation.

### Scenarios

- A guarded interactive TTY with `zellij` state launches Zellij only.
- A non-TTY or noninteractive invocation launches no runtime.
- An invocation inside TMUX, Zellij, or Herdr launches no runtime.
- Missing or failing selected runtimes produce no alternate session.
