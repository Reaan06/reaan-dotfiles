# Especificación de Diseño: Aumento del Tamaño del Disco de Música

Este documento detalla el plan para aumentar el tamaño del componente de "disco" (arte del álbum) en el reproductor de música de Quickshell.

## 1. Objetivo
Aumentar el tamaño visual del disco en un 35% para darle más protagonismo al arte del álbum, manteniendo el equilibrio visual del panel mediante ajustes proporcionales en el ancho y espaciado.

## 2. Cambios Propuestos

### 2.1 Archivo: `dot_config/quickshell/AudioManager.qml`

#### A. Ajuste de Dimensiones Globales
*   **Propiedad:** `anchorWidth`
*   **Cambio:** De `200` a `250`.
*   **Razón:** Proporcionar espacio horizontal adicional para acomodar el disco más grande sin apretar el texto de metadata.

#### B. Componente del Disco (Vinilo)
*   **Dimensiones del Item contenedor:** De `140 * root.scale` a `190 * root.scale`.
*   **Borde decorativo (Rectangle):** El borde sutil con opacidad `0.15` y `scale: 1.15` se mantendrá proporcional al nuevo tamaño del Item.
*   **Punto central:** El pequeño círculo central (`14 * root.scale`) se mantendrá igual para preservar el aspecto de "vinilo".

#### C. Layout y Espaciado
*   **Spacing del RowLayout principal:** De `28 * root.scale` a `32 * root.scale`.
*   **Razón:** Evitar que el disco se sienta demasiado pegado al texto del título y artista.

## 3. Consideraciones Técnicas
*   **Escalado:** Todos los cambios deben seguir utilizando `root.scale` para mantener la compatibilidad con diferentes densidades de pantalla.
*   **Animación:** La `RotationAnimation` seguirá funcionando correctamente ya que está vinculada a la propiedad `rotation` del Item, que ahora es más grande pero mantiene su centro.
*   **Recorte (Clipping):** El `OpacityMask` y el `maskSource` deben actualizarse automáticamente al cambiar las dimensiones del Item padre (`vinyl`).

## 4. Validación Sugerida
1.  Verificar que el disco se vea notablemente más grande (aprox. 190px en escala 1.0).
2.  Confirmar que el título de la canción y el artista siguen siendo legibles y no se salen del panel.
3.  Asegurar que la rotación del disco durante la reproducción sigue siendo fluida y centrada.
