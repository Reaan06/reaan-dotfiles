# Especificación de Diseño: Centrado de CircularGauge en SystemMonitor

**Fecha:** 2026-05-11
**Estado:** Aprobado

## 1. Problema
Los indicadores circulares de Memoria y Almacenamiento en el Dashboard (`SystemMonitor.qml`) aparecen descentrados respecto a sus etiquetas y el texto del porcentaje que contienen. Esto se debe al uso de coordenadas fijas (`65 * root.scale`) que no se ajustan dinámicamente si las dimensiones del componente varían o si hay redondeos en la escala.

## 2. Objetivo
Asegurar que el círculo (Shape) y el texto (Text) estén siempre perfectamente centrados dentro del contenedor del indicador, independientemente de la escala.

## 3. Propuesta de Solución
Refactorizar el componente interno `CircularGauge` en `SystemMonitor.qml` para utilizar dimensiones relativas:

1.  **Identificación:** Añadir `id: gaugeRoot` al `Item` principal del componente.
2.  **Propiedades:** Definir `property real strokeWidth: 12 * root.scale` para centralizar el grosor del trazo.
3.  **Dimensiones:** Mantener `width` y `height` basados en la escala pero usarlos como referencia interna.
4.  **Centrado del Círculo:**
    *   `centerX: gaugeRoot.width / 2`
    *   `centerY: gaugeRoot.height / 2`
5.  **Radio Dinámico:**
    *   `radiusX: (gaugeRoot.width - gaugeRoot.strokeWidth) / 2`
    *   `radiusY: (gaugeRoot.height - gaugeRoot.strokeWidth) / 2`
6.  **Centrado del Texto:** Mantener `anchors.centerIn: parent` (donde `parent` es `gaugeRoot`).

## 4. Impacto
*   Mejora la legibilidad y estética del dashboard.
*   Aumenta la robustez del componente ante cambios de escala.
*   No requiere cambios en los archivos externos de `components/`.

## 5. Verificación
*   Verificar visualmente que los números están en el centro geométrico de los círculos.
*   Probar con diferentes escalas si es posible.
