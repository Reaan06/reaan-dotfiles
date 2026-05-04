import QtQuick

/**
 * PanelConnector: Crea una transición visual curva entre la barra superior y un panel.
 * Soporta neckOffset para alinear el cuello superior de forma asimétrica.
 */
Canvas {
    id: root

    property color color: "#1e1e2e"
    property real connectorHeight: 20
    property real cornerRadius: 16
    property real barWidth: 100
    property real neckOffset: 0

    implicitWidth: barWidth + (cornerRadius * 2)
    implicitHeight: connectorHeight

    onColorChanged: requestPaint()
    onBarWidthChanged: requestPaint()
    onNeckOffsetChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        ctx.fillStyle = root.color;
        
        var centerX = width / 2;
        var topCenter = centerX + neckOffset;
        var halfBar = barWidth / 2;
        
        // Ensure we don't draw outside if the neck is very offset
        ctx.beginPath();
        
        // 1. Move to top-left of the bar attachment
        ctx.moveTo(topCenter - halfBar, 0);
        
        // 2. Line to top-right of the bar attachment
        ctx.lineTo(topCenter + halfBar, 0);
        
        // 3. Curve down to the right side of the panel
        ctx.bezierCurveTo(
            topCenter + halfBar + cornerRadius * 2, height * 0.1, // Drastic pull
            width - cornerRadius, height * 0.4,                  // Pull from panel side
            width, height                                        // End
        );
        
        // 4. Bottom line connecting to the panel body
        ctx.lineTo(0, height);
        
        // 5. Curve back up to the left side of the bar attachment
        ctx.bezierCurveTo(
            cornerRadius, height * 0.4,                          // Pull from panel side
            topCenter - halfBar - cornerRadius * 2, height * 0.1, // Drastic pull
            topCenter - halfBar, 0                               // End
        );
        
        ctx.closePath();
        ctx.fill();
    }
}
