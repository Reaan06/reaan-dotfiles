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
    property bool isFocused: false
    
    signal pinToggled()
    signal actionExecuted()
    
    function forceLaunch() {
        root.scale = 0.9
        clickAnimation.start()
        
        var cleanCmd = root.execCmd.replace(/'/g, "'\\''");
        var binCmd = cleanCmd.split(" ")[0];
        var fallbackCmd = "grep -rilm1 '" + cleanCmd + "' /usr/share/applications/ ~/.local/share/applications/ 2>/dev/null | head -1 | xargs grep -oP 'Exec=\\\\K[^%]*' | head -1 | xargs";
        var cmd = "if command -v '" + binCmd + "' >/dev/null 2>&1; then " +
                  "/usr/bin/hyprctl dispatch exec '" + cleanCmd + "'; " +
                  "else " +
                  "fb=$(" + fallbackCmd + "); " +
                  "if [ -n \"$fb\" ]; then /usr/bin/hyprctl dispatch exec \"$fb\"; " +
                  "else /usr/bin/hyprctl dispatch exec '" + cleanCmd + "'; fi; " +
                  "fi";
        execLaunch.command = ["sh", "-c", cmd]
        execLaunch.running = true
    }

    function triggerAction() {
        root.scale = 0.9
        clickAnimation.start()
        
        if (root.isActive) {
            execFocus.command = ["/usr/bin/hyprctl", "dispatch", "focuswindow", root.appClass]
            execFocus.running = true
        } else {
            root.forceLaunch()
        }
        root.actionExecuted()
    }

    width: 48; height: 48; radius: 12
    color: (mouseArea.containsMouse || root.isFocused) ? Qt.rgba(1,1,1,0.15) : "transparent"
    border.color: root.isFocused ? root.accentColor : "transparent"
    border.width: root.isFocused ? 2 : 0
    
    Behavior on color { ColorAnimation { duration: 200 } }
    
    Image {
        id: icon
        anchors.centerIn: parent
        anchors.margins: 8
        width: 32; height: 32
        source: {
            if (root.iconName.startsWith("/")) return "file://" + root.iconName;
            return "image://icon/" + (root.iconName || "application-x-executable");
        }
        fillMode: Image.PreserveAspectFit
        
        scale: (mouseArea.containsMouse || root.isFocused) ? 1.2 : 1.0
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
    // Pin Toggle Button (Same as launcher)
    Rectangle {
        anchors.top: parent.top; anchors.right: parent.right
        anchors.topMargin: -2; anchors.rightMargin: -2
        width: 20; height: 20; radius: 10
        color: root.isPinned ? shellRoot.cMauve : Qt.rgba(0,0,0,0.5)
        border.color: Qt.rgba(1,1,1,0.2); border.width: 1
        visible: mouseArea.containsMouse || root.isFocused
        z: 10
        
        Text {
            anchors.centerIn: parent
            text: "󰐃"
            color: "white"
            font.pixelSize: 10
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: root.pinToggled()
        }
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                root.pinToggled()
                return;
            }
            if (mouse.button === Qt.MiddleButton) {
                root.forceLaunch()
                root.actionExecuted()
                return;
            }
            root.triggerAction()
        }
    }
    
    SequentialAnimation {
        id: clickAnimation
        NumberAnimation { target: root; property: "scale"; to: 1.0; duration: 200; easing.type: Easing.OutBack }
    }
    
    Process { id: execLaunch }
    Process { id: execFocus }
}
