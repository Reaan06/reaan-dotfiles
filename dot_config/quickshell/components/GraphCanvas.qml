import QtQuick

/**
 * GraphCanvas.qml
 * A canvas that draws dynamic connecting lines between nodes in a graph.
 */
Canvas {
    id: canvas

    // ── Properties ──
    property var nodes: []      // List of {x, y, color}
    property real centerX: width / 2
    property real centerY: height / 2
    
    // Line style
    property real lineWidth: 1.5
    property real glowRadius: 4
    
    // Animation/Trigger updates
    onNodesChanged: canvas.requestPaint()
    onCenterXChanged: canvas.requestPaint()
    onCenterYChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    onPaint: {
        var ctx = canvas.getContext("2d");
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        
        if (!nodes || nodes.length === 0) return;

        nodes.forEach(function(node) {
            drawConnection(ctx, centerX, centerY, node.x, node.y, node.color || "#89b4fa");
        });
    }

    /**
     * Draws a smooth connection between two points.
     */
    function drawConnection(ctx, x1, y1, x2, y2, color) {
        ctx.save();
        
        // Setup line style
        ctx.lineWidth = canvas.lineWidth;
        
        // Create gradient for the line
        var grad = ctx.createLinearGradient(x1, y1, x2, y2);
        var baseColor = Qt.color(color);
        
        // Start from subtle/transparent at center
        grad.addColorStop(0.0, Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 0.1));
        // Fade in to full opacity at node
        grad.addColorStop(0.8, Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 0.6));
        grad.addColorStop(1.0, Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 0.8));
        
        ctx.strokeStyle = grad;
        
        // Glow effect (using shadow)
        ctx.shadowColor = color;
        ctx.shadowBlur = canvas.glowRadius;

        // Draw line
        ctx.beginPath();
        ctx.moveTo(x1, y1);
        
        // Use a simple quadratic curve for a "organic" look if needed, 
        // or just a straight line for technical look. 
        // For a network graph, straight lines with a subtle arc look nice.
        var midX = (x1 + x2) / 2;
        var midY = (y1 + y2) / 2;
        
        // Adding a slight offset for the curve
        // var cpX = midX + (y2 - y1) * 0.1;
        // var cpY = midY - (x2 - x1) * 0.1;
        // ctx.quadraticCurveTo(cpX, cpY, x2, y2);
        
        ctx.lineTo(x2, y2);
        ctx.stroke();
        
        ctx.restore();
    }
}
