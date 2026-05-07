# Plan: Corregir Heatmap de GitHub y Reordenar Dashboard

Este plan aborda la desaparición de las cajas de contribuciones en el panel de GitHub y reubica la sección de contribuciones en la parte superior según lo solicitado por el usuario.

## Objetivo
- Mover la sección de "CONTRIBUTIONS" a la parte superior del dashboard (por encima del perfil).
- Asegurar que el heatmap de contribuciones sea visible y se renderice correctamente.
- Corregir problemas de diseño que causan que los elementos se superpongan o colapsen.

## Cambios Propuestos

### 1. `dot_config/quickshell/GitHubDashboardView.qml`
- **Reordenar Layout**: Mover el bloque de `RowLayout` (Heatmap + Sidebar) antes del `Rectangle` de Profile Header.
- **Corregir Layout Props**: 
    - Cambiar `width: parent.width` por `Layout.fillWidth: true` en los `RowLayout` de nivel superior.
    - Asegurar que el `Rectangle` del heatmap tenga un `Layout.minimumWidth` para evitar que colapse.
- **Mejorar Renderizado del Canvas**:
    - Añadir validación robusta para `weeksData`.
    - Añadir un mensaje de error/estado en el Canvas si no hay datos.
    - Usar un método de dibujo más seguro para las celdas del heatmap.
    - Asegurar que `root.scale` tenga un valor por defecto seguro.

### 2. `dot_config/scripts/github-fetch.sh` (Opcional/Verificación)
- Verificar que la consulta GraphQL sigue siendo válida y que los nombres de los campos no han cambiado. (Basado en la investigación, parece correcta).

## Pasos de Implementación

1.  **Ajustar `GitHubDashboardView.qml`**:
    - Modificar la propiedad `scale` para que sea más resiliente.
    - Intercambiar las posiciones del Perfil y de las Contribuciones.
    - Corregir el `RowLayout` de las contribuciones para evitar solapamientos.
    - Actualizar la lógica de `onPaint` del `Canvas` para ser más robusta y añadir logs (si fuera posible) o fallback visual.

2.  **Verificación**:
    - El panel de GitHub debería mostrar ahora las contribuciones en la parte superior.
    - Las cajas del heatmap deberían ser visibles.
    - Los stats (Streak, etc.) deberían estar correctamente alineados a la derecha.

## Verificación

```bash
# Verificar sintaxis de QML (si hay herramientas disponibles)
# De lo contrario, confiar en la recarga de Quickshell
```
