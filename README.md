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
├── dot_config/          # Configuraciones de aplicaciones (Hyprland, Waybar, etc.)
├── eq-service/          # Servicio Rust para ecualización de audio
├── mcp/                 # Configuraciones del Model Context Protocol (MCP) para IA
├── scripts/             # Scripts de automatización y utilidades
└── wallps/              # Fondos de pantalla
```

## Conceptos Clave
- **Hyprland**: Gestor de ventanas principal (Wayland).
- **Qml/Quickshell**: Interfaz de usuario para widgets de escritorio.
- **eq-service**: Servicio desarrollado en Rust para control de ecualización.

## Protocolos Operativos
- **Documentación**: Todo cambio significativo debe documentarse mediante `ADR` (Architecture Decision Records) o registros de errores en este formato Markdown.
- **Gestión de Conocimiento**: El formato sigue los principios de "Atomicidad" y "Frontmatter Estricto".
- **Interacción**: El sistema opera principalmente a través de la CLI mediante el agente Gemini configurado.
- **Integración con IA (MCP)**: Se emplea el Model Context Protocol para la integración del agente con la base de conocimiento local en Obsidian. La configuración se encuentra en `mcp/obsidian.json`, montando el vault ubicado en `/home/reaan/Brain/Brain/00-Inteligencia-Artificial`.

## Referencias
- [[conductor/index.md]] - Gestión de planes y proyectos.
- [[eq-service/README.md]] - Documentación del servicio de audio.
- [[mcp/obsidian.json]] - Configuración del servidor MCP para Obsidian.

---
_Nota: Este archivo sirve como MOC (Map of Content) principal para el proyecto._
