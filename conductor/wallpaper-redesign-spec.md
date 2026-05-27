# Spec: Rediseño Total de Wallpaper Picker

**Fecha:** 2026-05-25
**Estado:** Draft
**Autor:** Gemini CLI

## 1. Introducción
Rediseño completo del selector de fondos de pantalla para Hyprland, moviéndolo de una aplicación GTK independiente a un panel nativo de **Quickshell**. El objetivo es lograr una integración visual perfecta, mayor rapidez y una funcionalidad de gestión de archivos integrada.

## 2. Arquitectura y Flujo de Datos
- **Frontend:** Nuevo componente `WallpaperPicker.qml` en Quickshell.
- **Backend:** Script `wallpaper_bridge.py` que:
    - Escanea recursivamente `~/reaan-dotfiles/wallps/`.
    - Devuelve un JSON con las rutas de las imágenes.
    - Maneja la copia de nuevos archivos seleccionados por el usuario.
- **Estado:** Se utilizará un archivo en `/tmp/qs-wallpaper-picker` para controlar la visibilidad del panel, siguiendo el patrón de `audio-manager` y `super-f2`.
- **Aplicación:** Seguirá usando `swaybg` (a través de los scripts existentes modificados) para aplicar los fondos por monitor.

## 3. Diseño UI/UX (Quickshell)
- **Visualización:** Superposición (Overlay) centrada o de pantalla completa con `ExclusionMode.Ignore`.
- **Fondo:** Transparencia con desenfoque (blur) profundo usando la paleta dinámica del sistema.
- **Grid:** Cuadrícula responsiva de miniaturas con esquinas redondeadas.
- **Gestión:** 
    - Botón "Añadir Imagen" prominente.
    - Al hacer clic en una miniatura, se aplica inmediatamente al monitor enfocado.
    - Notificación visual de éxito.

## 4. Gestión de Archivos
- La carpeta de origen será estrictamente `~/reaan-dotfiles/wallps/`.
- La función de subida abrirá un diálogo (vía `zenity` o `kdialog` invocado desde el bridge) y copiará el archivo seleccionado a la carpeta de dotfiles.

## 5. Integración con el Sistema
- **Keybind:** `Super + W` ejecutará un script que alterna el estado de visibilidad en `/tmp/qs-wallpaper-picker`.
- **Quickshell:** El archivo `shell.qml` cargará el nuevo componente `WallpaperPicker.qml`.

---
**¿Este diseño cumple con tus expectativas para proceder al plan de implementación?**
