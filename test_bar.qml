import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    PanelWindow {
        anchors { top: true; left: true; right: true }
        implicitHeight: 50
        color: "red"
        Text {
            anchors.centerIn: parent
            text: "TEST BAR"
            color: "white"
            font.pixelSize: 20
        }
    }
}
