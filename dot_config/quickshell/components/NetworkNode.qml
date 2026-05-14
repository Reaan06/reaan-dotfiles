import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

/**
 * NetworkNode.qml
 * A circular node representing a network entity in a graph-based view.
 */
Item {
    id: root

    // ── Properties ──
    property string icon: "󰇄"           
    property string label: ""            
    property string subLabel: ""         
    property bool active: false         
    property bool loading: false        
    property color accentColor: "#89b4fa" 
    
    // Theme references (Dynamic reactive colors)
    property color cBg: Qt.rgba(0.07, 0.07, 0.1, 0.95)
    property color cText: "#cdd6f4"
    property color cSub: "#6c7086"
    readonly property string fontName: "JetBrains Mono Nerd Font"

    implicitWidth: 140
    implicitHeight: 140

    // ── Internal State ──
    readonly property bool isHovered: mouseArea.containsMouse
    
    // Dynamic contrast for text based on accent or bg
    readonly property color contentColor: active || isHovered ? accentColor : cText

    // ── Transitions ──
    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
    Behavior on opacity { NumberAnimation { duration: 250 } }
    Behavior on accentColor { ColorAnimation { duration: 400 } }

    scale: isHovered ? 1.08 : 1.0

    // ── Pulse Animation ──
    SequentialAnimation {
        running: root.loading
        loops: Animation.Infinite
        NumberAnimation { target: body; property: "opacity"; from: 1.0; to: 0.5; duration: 800; easing.type: Easing.InOutQuad }
        NumberAnimation { target: body; property: "opacity"; from: 0.5; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
    }

    // ── Node Visuals ──
    Rectangle {
        id: body
        anchors.fill: parent
        radius: width / 2
        color: root.cBg
        border.width: root.active || isHovered ? 3 : 1.5
        border.color: root.active || isHovered ? root.accentColor : Qt.rgba(1, 1, 1, 0.12)
        
        Behavior on border.color { ColorAnimation { duration: 300 } }
        Behavior on border.width { NumberAnimation { duration: 300 } }

        // Subtle gradient overlay for depth
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            opacity: isHovered ? 0.25 : 0.08
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.accentColor }
                GradientStop { position: 1.0; color: "transparent" }
            }
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        // Glow effect
        layer.enabled: root.active || isHovered
        layer.effect: DropShadow {
            transparentBorder: true
            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.4)
            radius: isHovered ? 20 : 12
            samples: 24
        }

        Column {
            id: contentContainer
            anchors.centerIn: parent
            spacing: 4
            width: parent.width * 0.9

            Text {
                width: parent.width
                text: root.icon
                font.family: root.fontName
                font.pixelSize: 42 // Aún más grande
                color: root.contentColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Behavior on color { ColorAnimation { duration: 250 } }
            }

            Text {
                width: parent.width
                text: root.label
                font.family: root.fontName
                font.pixelSize: 14
                font.bold: true
                color: root.cText
                visible: text !== ""
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                maximumLineCount: 1
            }

            Text {
                width: parent.width
                text: root.subLabel
                font.family: root.fontName
                font.pixelSize: 11
                color: root.cSub
                visible: text !== ""
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                maximumLineCount: 2
                elide: Text.ElideRight
                lineHeight: 0.9
            }
        }
    }

    // ── Signals ──
    signal clicked()

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
