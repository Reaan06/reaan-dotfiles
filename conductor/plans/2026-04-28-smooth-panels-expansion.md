# Plan: Implementación de Paneles Animados con Curvatura en Quickshell

Este plan detalla los cambios necesarios para que los paneles de Ecualizador (Super+F1) y Dashboard (Super+F2) se abran de forma fluida y orgánica desde sus respectivos módulos en la barra superior, incluyendo una conexión visual curva ("neck").

## Objetivos
1.  **Transiciones Suaves**: Animar la altura y opacidad de los paneles al abrirse/cerrarse.
2.  **Conexión Visual**: Implementar un "cuello" con curvatura cóncava que una el panel con el módulo superior.
3.  **Alineación Precisa**: Ajustar las posiciones de las ventanas en `shell.qml` para que coincidan con los elementos de `StatusBar.qml`.
4.  **Feedback Visual**: Asegurar que el módulo de audio sea visible en la barra.

## Cambios Propuestos

### 1. Componente de Conexión (`dot_config/quickshell/components/PanelConnector.qml`)
Crear un nuevo componente `Canvas` que dibuje la transición curva entre la barra y el panel.
-   Ancho ajustable para coincidir con el módulo de origen.
-   Curvatura cóncava en las esquinas inferiores para unirse suavemente al panel.

### 2. Modificaciones en `StatusBar.qml`
-   Añadir el indicador de volumen al `sysRow` para que el panel de audio tenga un punto de origen claro.
-   Asegurar que los tamaños de las cajas sean consistentes.

### 3. Modificaciones en `shell.qml`
-   Ajustar `audioManagerWin` para que se ancle a la derecha (`anchors.right: true`) y se alinee con el gestor audiovisual.
-   Cambiar `margins.top` de 60 a 50 para que las ventanas de los paneles comiencen justo debajo de la barra.
-   Modificar la lógica de visibilidad: en lugar de un `visible` binario, pasar una propiedad `active` a los paneles para que ellos gestionen su propia animación de entrada/salida.

### 4. Modificaciones en `AudioManager.qml` y `SuperF2Panel.qml`
-   Añadir un `StateGroup` o propiedades animadas para `height` y `opacity`.
-   Incluir el `PanelConnector` en la parte superior del layout.
-   Asegurar que el fondo sea transparente y solo el contenedor interno se anime.

## Pasos de Implementación

### Paso 1: Crear `PanelConnector.qml`
Definir la lógica de dibujo para la curvatura.

### Paso 2: Actualizar `StatusBar.qml`
Añadir el módulo de volumen.

### Paso 3: Reestructurar `shell.qml`
Ajustar anclajes y pasar estados de animación.

### Paso 4: Actualizar Paneles
Implementar las animaciones internas y el conector.

## Verificación y Pruebas
1.  Ejecutar `quickshell` manualmente para observar la salida de consola.
2.  Probar Super+F1 y Super+F2 repetidamente para verificar la suavidad.
3.  Verificar que la curvatura se alinee correctamente con las cajas de la barra en diferentes resoluciones (si aplica).
4.  Revisar errores con el sistema de alertas de Hyprland si es necesario.
