import QtQuick

/**
 * PanelConnector: Crea una transición visual curva entre la barra superior y un panel.
 */
Canvas {
    id: root

    property color color: "#1e1e2e"
    property real connectorHeight: 12
    property real cornerRadius: 12
    property real barWidth: 100

    implicitWidth: barWidth + (cornerRadius * 2)
    implicitHeight: connectorHeight

    onColorChanged: requestPaint()
    onBarWidthChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        
        ctx.fillStyle = root.color;
        
        // Dibujamos un pequeño solapamiento superior para asegurar una unión limpia
        ctx.beginPath();
        ctx.moveTo(cornerRadius, -1);
        ctx.lineTo(barWidth + cornerRadius, -1);
        
        // Bajada hacia la derecha con curva cóncava suave
        ctx.bezierCurveTo(
            barWidth + cornerRadius, connectorHeight * 0.4,
            barWidth + cornerRadius * 2, connectorHeight * 0.6,
            barWidth + cornerRadius * 2, connectorHeight + 1
        );
        
        // Base que conecta con el panel (solapamiento inferior)
        ctx.lineTo(-1, connectorHeight + 1);
        
        // Subida hacia la izquierda con curva cóncava suave
        ctx.bezierCurveTo(
            0, connectorHeight * 0.6,
            cornerRadius, connectorHeight * 0.4,
            cornerRadius, -1
        );
        
        ctx.closePath();
        ctx.fill();
    }
}
