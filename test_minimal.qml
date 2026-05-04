import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    PanelWindow {
        id: win
        WlrLayerShell.namespace: "quickshell-test"
        WlrLayerShell.layer: WlrLayerShell.Top
        
        anchors { top: true; left: true; right: true }
        implicitHeight: 60
        color: "purple"
        
        Text {
            anchors.centerIn: parent
            text: "IF YOU SEE THIS, IT WORKS"
            color: "white"
            font.pixelSize: 30
        }
    }
}
