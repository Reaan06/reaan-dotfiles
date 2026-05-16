import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/**
 * DockItem.qml
 * Individual item for the Antigravity Dock.
 */
Rectangle {
    id: root
    property string name: ""
    property string iconName: ""
    property string execCmd: ""
    property string appClass: ""
    property bool isActive: false
    property bool isPinned: false
    property color accentColor: "#89b4fa"
    
    width: 48; height: 48; radius: 12
    color: mouseArea.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
    
    Behavior on color { ColorAnimation { duration: 200 } }
    
    Image {
        id: icon
        anchors.centerIn: parent
        anchors.margins: 8
        width: 32; height: 32
        source: "image://icon/" + root.iconName
        fillMode: Image.PreserveAspectFit
        
        scale: mouseArea.containsMouse ? 1.2 : 1.0
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
    }
    
    // Active Indicator
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.isActive ? 4 : 0
        height: 4; radius: 2
        color: root.accentColor
        visible: root.isActive
        
        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.scale = 0.9
            clickAnimation.start()
            
            if (root.isActive) {
                // Focus window via hyprctl
                execFocus.command = ["/usr/bin/hyprctl", "dispatch", "focuswindow", root.appClass]
                execFocus.running = true
            } else {
                // Lanzar app - Intentar hyprctl exec primero, luego buscar el .desktop como fallback
                var fallback = "grep -rilm1 '" + root.execCmd + "' /usr/share/applications/ ~/.local/share/applications/ 2>/dev/null | head -1 | xargs grep -oP 'Exec=\\K[^%]*' | head -1"
                var cmd = "/usr/bin/hyprctl dispatch exec " + root.execCmd + " || $(" + fallback + ") &"
                execLaunch.command = ["sh", "-c", cmd]
                execLaunch.running = true
            }
        }
    }
    
    SequentialAnimation {
        id: clickAnimation
        NumberAnimation { target: root; property: "scale"; to: 1.0; duration: 200; easing.type: Easing.OutBack }
    }
    
    Process { id: execLaunch }
    Process { id: execFocus }
}
