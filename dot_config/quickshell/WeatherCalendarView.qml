import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: root
    
    // Fallback visual para depuración
    Rectangle {
        anchors.fill: parent; color: "#1e1e2e"
        Text { anchors.centerIn: parent; text: "COMPONENTE CLIMA (DEBUG)"; color: "white" }
    }
}
