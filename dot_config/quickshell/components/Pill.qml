import QtQuick

// Pill: Contenedor rectangular con bordes redondeados reutilizable.
// Acepta contenido arbitrario via defaultProperty "data" (hijos directos).
// Emite señales de click izquierdo, derecho y medio.

Rectangle {
    id: root

    property color pillColor: Qt.rgba(0.157, 0.173, 0.204, 0.9)
    property color hoverColor: Qt.rgba(0.192, 0.196, 0.267, 0.95)
    property bool hoverEnabled: true
    property real pillRadius: 10
    property real hPad: 14
    property real vPad: 8

    default property alias content: innerRow.data

    signal clicked()
    signal rightClicked()
    signal middleClicked()
    signal scrolledUp()
    signal scrolledDown()

    color: hoverEnabled && mouseArea.containsMouse ? hoverColor : pillColor
    radius: pillRadius
    height: 36
    implicitWidth: innerRow.implicitWidth + (hPad * 2)
    implicitHeight: 36

    Behavior on color {
        ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: root.hoverEnabled
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) root.clicked()
            else if (mouse.button === Qt.RightButton) root.rightClicked()
            else if (mouse.button === Qt.MiddleButton) root.middleClicked()
        }

        onWheel: function(wheel) {
            if (wheel.angleDelta.y > 0) root.scrolledUp()
            else root.scrolledDown()
        }
    }

    Row {
        id: innerRow
        anchors.centerIn: parent
        spacing: 6
    }
}
