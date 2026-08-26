---
title: Documentación del Proyecto: Dotfiles de Reaan
date: 2026-04-09
tags: [documentation, tech_doc, dotfiles, hyprland]
type: tech_doc
status: final
project: [[Reaan-Dotfiles]]
---

# 🏛️ Documentación de Proyecto: `reaan-dotfiles`

## Descripción General
Este repositorio contiene la configuración del sistema personal (*dotfiles*) para el entorno Linux con **Hyprland**. El objetivo es mantener una configuración declarativa, modular y documentada para asegurar la reproducibilidad y el mantenimiento a largo plazo.

## Estructura del Proyecto

```text
/home/reaan/reaan-dotfiles/
├── conductor/           # Planes de trabajo y gestión de proyectos
├── dot_config/          # Configuraciones de aplicaciones (Hyprland, Quickshell, etc.)
├── eq-service/          # Servicio Rust para ecualización de audio
├── scripts/             # Scripts de automatización y utilidades
└── wallps/              # Fondos de pantalla
```

## Conceptos Clave
- **Hyprland**: Gestor de ventanas principal (Wayland).
- **Quickshell**: Shell de escritorio principal — barra de estado, dock, OSD y paneles.
- **eq-service**: Servicio desarrollado en Rust para control de ecualización.

## Protocolos Operativos
- **Documentación**: Todo cambio significativo debe documentarse mediante `ADR` (Architecture Decision Records) o registros de errores en este formato Markdown.
- **Gestión de Conocimiento**: El formato sigue los principios de "Atomicidad" y "Frontmatter Estricto".
- **Interacción**: El sistema opera principalmente a través de la CLI mediante el agente Gemini configurado.

## Referencias
- [[conductor/index.md]] - Gestión de planes y proyectos.
- [[eq-service/README.md]] - Documentación del servicio de audio.

## Credenciales de AI Usage
El colector ChatGPT / OpenAI prefiere `OPENAI_HOME/auth.json`, luego `~/.openai/auth.json`. Si ninguna de esas credenciales existe, conserva compatibilidad usando `~/.codex/auth.json` como fallback de migración heredado.

---
_Nota: Este archivo sirve como MOC (Map of Content) principal para el proyecto._

## Optional Terminal DOTS

Run the Arch installer from this repository with:

```bash
./install.sh
```

Terminal DOTS are disabled by default. Leaving the first prompt blank, or
answering no, persists `none` and does not ask for a runtime. Only an
affirmative answer opens the conditional `Herdr or TMUX` choice; leaving that
choice blank selects Herdr.

Herdr and TMUX are session runtimes, not terminal emulators. Kitty remains the terminal emulator and Zsh remains the shell: Kitty keeps `shell zsh`, while
Hyprland keeps `$terminal = kitty`. This repository no longer wires the
optional launcher into `dot_zshrc` and does not start sessions automatically.
You can invoke `dot_config/scripts/terminal-session.sh` explicitly from a
guarded interactive TTY; its interactive-TTY, nesting, and no-fallback guards
remain active.

The installer stores exactly one selection, `none`, `herdr`, or `tmux`, in
`$XDG_CONFIG_HOME/reaan/terminal-dots.conf` (or
`~/.config/reaan/terminal-dots.conf` when `XDG_CONFIG_HOME` is unset). The
selection is exclusive and idempotent: reruns converge on one state and keep
existing user-owned Herdr configuration instead of overwriting it. Selecting
`none` records that no runtime is selected for explicit launcher invocation;
it does not disable a repository-managed automatic startup hook, because no
such hook is installed. The installer never uninstalls packages or deletes user configuration.

### Rollback

To stop selecting a runtime for explicit launcher invocation without removing
installed software or user files, run `./install.sh` and decline Terminal
DOTS. A failed optional runtime installation remains fail-closed and never
falls back to another runtime. To roll back this repository change, restore
the previous installer name and remove only the optional terminal integration
files; retain user packages and configuration.

### Herdr provenance and availability

`dot_config/herdr/config.toml` is an unmodified vendored snapshot from
[Gentleman.Dots commit
`6b02894b71dc223105091729ebd673ea64e03fb0`](https://github.com/Gentleman-Programming/Gentleman.Dots/tree/6b02894b71dc223105091729ebd673ea64e03fb0),
blob `b9f15f533a08e4464bacc59194110ed0527346fc`. The installer copies it only
when the user's Herdr configuration does not already exist.

This config provenance is separate from Herdr binary-release metadata. When
Herdr is selected, the installer uses the official endpoint
`https://herdr.dev/install.sh`. That official installer owns latest-release
selection from `latest.json` and SHA-256 release validation; this repository
does not invent or pin release URLs, versions, or hashes.

The complete script is downloaded to a private mode-0700 temporary file beside
`$HOME/.local/bin/herdr` and then executed with
`HERDR_INSTALL_DIR="$HOME/.local/bin"`. This is still a remote-shell trust boundary:
running the current official script means trusting its fetched contents. The download-then-execute flow is deliberate rather than `curl | sh`;
it avoids partial streamed execution while retaining the official script's
release and integrity checks.

The Herdr path is fail-closed. Download, script execution, or executable
verification failures remove the temporary file, persist `none`, preserve
existing user configuration, and never fall back to TMUX or uninstall
software. To roll back this optional runtime, decline Terminal DOTS; that
clears the selected runtime while retaining installed packages and user files.
