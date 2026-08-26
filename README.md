# Reaan Dotfiles

This repository contains the Hyprland and Quickshell desktop configuration for Linux.

## Optional Terminal DOTS

Run the Arch installer with:

```bash
./install.sh
```

The installer keeps Terminal DOTS opt-in. If accepted, it asks for a shell and a
window-manager/session runtime:

| Choice | Values | Default |
| --- | --- | --- |
| Shell | Fish, Zsh, Nushell | Zsh |
| WM/session | TMUX, Zellij, Herdr, None | Herdr |

It delegates terminal setup to the official
[Gentleman.Dots](https://github.com/Gentleman-Programming/Gentleman.Dots)
Linux installer with Kitty fixed as the terminal emulator. Upstream installs the
selected shell and session dots, sets the default shell, and safely adds the
selected session auto-start behavior to Fish, Zsh, or Nushell. This repository
does not deploy `dot_zshrc` or add a second startup hook. Hyprland continues to
use `$terminal = kitty`.

The official binary is downloaded completely to a private mode-0700 temporary
file and executed from a private temporary directory with
`--non-interactive --terminal=kitty --shell=<shell> --wm=<wm> --backup=true`.
The temporary resources are removed on success and failure. The downloaded
upstream binary is a remote-shell trust boundary; `--backup=true` preserves
existing files through the upstream backup mechanism.

The state file contains exactly one of `none`, `tmux`, `zellij`, or `herdr` at
`$XDG_CONFIG_HOME/reaan/terminal-dots.conf` (or `~/.config/reaan/...`). The
installer writes `none` before an attempt and only activates the selected value
after upstream succeeds. Failure is fail-closed: there is no shell/session
fallback, user configuration is not deleted, and the selected state returns to
`none`. The vendored Herdr config is copied only when upstream did not create a
user config.

The standalone `dot_config/scripts/terminal-session.sh` launcher remains an
explicit, interactive-TTY-only escape hatch. It honors nesting guards for
TMUX, Zellij, and Herdr, and never falls back to another runtime.

## Rollback

Run `./install.sh` and decline Terminal DOTS to record `none` without removing
installed packages or user configuration.
