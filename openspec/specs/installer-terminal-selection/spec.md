# Installer Terminal Selection Specification

## Purpose

Define safe delegation of terminal setup to the official Gentleman.Dots installer.

## Requirements

### Requirement: Gate and select terminal setup

`install.sh` MUST preserve the default-no Terminal DOTS prompt. After opt-in it
MUST ask for Fish, Zsh, or Nushell (Zsh default), then TMUX, Zellij, Herdr, or
None (Herdr default). Kitty MUST remain the fixed terminal emulator.

### Requirement: Delegate to the official installer

The installer MUST select the official Linux x86_64 or aarch64 binary asset and
invoke it with exact flags: `--non-interactive --terminal=kitty
--shell=<shell> --wm=<wm> --backup=true`. It MUST download the complete binary
to a private mode-0700 temporary file, execute it from a private temporary
working directory, and clean both resources on every exit path. Unsupported
architectures MUST fail clearly.

### Requirement: Persist state fail-closed

`terminal-dots.conf` MUST accept only `none`, `tmux`, `zellij`, or `herdr`.
`none` MUST be written before installation. The selected value MUST be written
only after official installation succeeds. Any failure MUST restore `none`,
preserve user files, and MUST NOT fall back to another shell or session.

### Requirement: Preserve local overlays safely

The installer MUST retain local Quickshell, Hyprland, and Kitty overlays, but
MUST NOT deploy this repository's `dot_zshrc`. The vendored Herdr config MAY be
copied only when upstream did not create one. Shell packages and configuration
are owned by Gentleman.Dots; local forced Zsh packages and setup MUST be absent.

### Scenarios

- Declining the first prompt records `none` and asks no further selection.
- Blank shell and WM answers select Zsh and Herdr respectively.
- A successful Fish/Zellij run passes the exact selections and activates `zellij`.
- Download, execution, architecture, or verification failure leaves state `none` with no fallback.
- Existing user configuration is preserved through upstream backups and local Herdr preservation rules.
