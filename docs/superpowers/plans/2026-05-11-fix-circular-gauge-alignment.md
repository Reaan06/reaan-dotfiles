# Plan de Implementación: Centrado de CircularGauge en SystemMonitor

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Corregir el descentrado de los indicadores circulares en el dashboard de monitoreo del sistema.

**Architecture:** Refactorizar el componente QML interno para usar coordenadas relativas al tamaño del componente en lugar de valores fijos escalados.

**Tech Stack:** QML (Qt Quick, Qt Quick Shapes)

---

### Tarea 1: Refactorización del Componente CircularGauge

**Files:**
- Modify: `dot_config/quickshell/SystemMonitor.qml:135-146`

- [ ] **Paso 1: Identificar el componente y definir propiedades base**

Modificar la definición de `component CircularGauge` para añadir un `id` y una propiedad `strokeWidth`.

```qml
    component CircularGauge: Item {
        id: gaugeRoot
        property real fillVal: 0
        property color fillCol: "white"
        property real strokeWidth: 12 * root.scale
        width: 130 * root.scale; height: 130 * root.scale
```

- [ ] **Paso 2: Actualizar el fondo del indicador (ShapePath de fondo)**

Cambiar los valores de `PathAngleArc` para que usen `gaugeRoot.width`, `gaugeRoot.height` y `gaugeRoot.strokeWidth`.

```qml
            ShapePath { 
                strokeColor: Qt.rgba(1,1,1,0.05); 
                strokeWidth: gaugeRoot.strokeWidth; 
                fillColor: "transparent"; 
                capStyle: ShapePath.RoundCap; 
                PathAngleArc { 
                    centerX: gaugeRoot.width / 2; 
                    centerY: gaugeRoot.height / 2; 
                    radiusX: (gaugeRoot.width - gaugeRoot.strokeWidth) / 2; 
                    radiusY: (gaugeRoot.height - gaugeRoot.strokeWidth) / 2; 
                    startAngle: -90; 
                    sweepAngle: 360 
                } 
            }
```

- [ ] **Paso 3: Actualizar el trazo de progreso (ShapePath de valor)**

Aplicar la misma lógica de coordenadas relativas al segundo `ShapePath`.

```qml
            ShapePath { 
                strokeColor: fillCol; 
                strokeWidth: gaugeRoot.strokeWidth; 
                fillColor: "transparent"; 
                capStyle: ShapePath.RoundCap; 
                PathAngleArc { 
                    centerX: gaugeRoot.width / 2; 
                    centerY: gaugeRoot.height / 2; 
                    radiusX: (gaugeRoot.width - gaugeRoot.strokeWidth) / 2; 
                    radiusY: (gaugeRoot.height - gaugeRoot.strokeWidth) / 2; 
                    startAngle: -90; 
                    sweepAngle: Math.max(0.1, (fillVal / 100) * 360) 
                } 
            }
```

- [ ] **Paso 4: Verificar el centrado del Texto**

Asegurarse de que el texto use `gaugeRoot.fillVal` y esté centrado en `gaugeRoot`.

```qml
        Text { 
            anchors.centerIn: gaugeRoot; 
            text: Math.round(gaugeRoot.fillVal) + "%"; 
            color: root.cText; 
            font.pixelSize: 20 * root.scale; 
            font.bold: true; 
            font.family: root.font 
        }
```

- [ ] **Paso 5: Commit de los cambios**

```bash
git add dot_config/quickshell/SystemMonitor.qml
git commit -m "fix: center circular gauges in system monitor using relative coordinates"
```
