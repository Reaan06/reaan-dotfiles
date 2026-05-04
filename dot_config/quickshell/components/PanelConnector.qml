import QtQuick

/**
 * PanelConnector: Crea una transición visual curva entre la barra superior y un panel.
 * Soporta neckOffset para alinear el cuello superior de forma asimétrica.
 */
Canvas {
    id: root

    property color color: "#1e1e2e"
    property real connectorHeight: 12
    property real cornerRadius: 12
    property real barWidth: 100
    property real neckOffset: 0

    implicitWidth: barWidth + (cornerRadius * 2)
    implicitHeight: connectorHeight

    onColorChanged: requestPaint()
    onBarWidthChanged: requestPaint()
    onNeckOffsetChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        ctx.fillStyle = root.color;
        
        var centerX = width / 2;
        var topCenter = centerX + neckOffset;
        var halfBar = barWidth / 2;
        
        ctx.beginPath();
        // Top line (at the bar)
        ctx.moveTo(topCenter - halfBar, -1);
        ctx.lineTo(topCenter + halfBar, -1);
        
        // Right curve
        ctx.bezierCurveTo(
            topCenter + halfBar, connectorHeight * 0.4,
            centerX + (width/2 - cornerRadius), connectorHeight * 0.6,
            width + 1, connectorHeight + 1
        );
        
        // Bottom line (at the panel)
        ctx.lineTo(-1, connectorHeight + 1);
        
        // Left curve
        ctx.bezierCurveTo(
            centerX - (width/2 - cornerRadius), connectorHeight * 0.6,
            topCenter - halfBar, connectorHeight * 0.4,
            topCenter - halfBar, -1
        );
        
        ctx.closePath();
        ctx.fill();
    }
}
