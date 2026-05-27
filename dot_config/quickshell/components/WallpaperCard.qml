import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Qt5Compat.GraphicalEffects

// Individual wallpaper item for the grid
Item {
    id: card
    property string name: ""
    property string path: ""
    property bool isActive: false
    signal clicked()

    width: 280; height: 180

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 16; color: shellRoot.cPill
        border.width: isActive ? 2 : 1
        border.color: isActive ? shellRoot.cMauve : Qt.rgba(1, 1, 1, 0.08)
        clip: true

        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }

        Image {
            anchors.fill: parent; anchors.margins: 4
            source: "file://" + card.path
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle { width: bg.width; height: bg.height; radius: 12 }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
            height: 40; color: Qt.rgba(0, 0, 0, 0.6)
            radius: 12
            visible: ma.containsMouse || isActive

            Text {
                anchors.centerIn: parent
                text: card.name; color: "#ffffff"; font.pixelSize: 12; font.bold: true
                elide: Text.ElideRight; width: parent.width - 20
                horizontalAlignment: Text.AlignHCenter
            }
        }

        MouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.clicked()
        }
        
        states: State {
            name: "hover"; when: ma.containsMouse
            PropertyChanges { target: bg; color: shellRoot.cHover; border.color: Qt.rgba(1, 1, 1, 0.2) }
        }
    }
}
