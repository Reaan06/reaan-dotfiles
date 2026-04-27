# Plan: Mejora de la Lógica de Rastreo de Aplicaciones (Sober/Roblox)

Este plan aborda la falta de rastreo preciso para aplicaciones con nombres de clase complejos o dinámicos, centrándose especialmente en Sober (Roblox).

## Objetivo
Optimizar `app_tracker.py` para identificar correctamente aplicaciones mediante el análisis combinado de clase y título de ventana, aplicando normalización recursiva y mapeos específicos.

## Archivos a Modificar
- `dot_config/scripts/app_tracker.py`
- `scripts/app_tracker.py`

## Pasos de Implementación

### 1. Mejorar la función `normalize_name`
- Añadir parámetros `cls_name` y `title`.
- Implementar búsqueda de palabras clave ("sober", "roblox", "vinegar") para mapeo inmediato.
- Implementar bucle de limpieza de prefijos DNS recursivo (ej: `org.kde.dolphin` -> `dolphin`).
- Ampliar el diccionario de mapeo de iconos.

### 2. Actualizar Captura de Eventos
- Modificar `handle_event` para extraer el título de la ventana del evento `activewindow>>`.
- Actualizar `get_active_window_info` para que devuelva tanto la clase como el título inicial.

### 3. Sincronización
- Asegurar que los cambios se repliquen en ambos scripts del repositorio.

## Verificación
- Ejecutar el script y abrir Sober/Roblox.
- Comprobar que `~/.cache/app_usage.json` registra la aplicación bajo la clave "sober".
- Verificar que el icono en la UI de Quickshell se muestra correctamente.
