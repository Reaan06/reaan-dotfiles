import QtQuick
import QtQuick.Shapes

Item {
    id: root
    property real value: 0
    property real maxValue: 100
    property color color: "#cba6f7"
    property color bgColor: Qt.rgba(1, 1, 1, 0.05)
    property real strokeWidth: 8
    property string text: ""

    implicitWidth: 100
    implicitHeight: 100

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeColor: root.bgColor
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (root.width - root.strokeWidth) / 2
                radiusY: (root.height - root.strokeWidth) / 2
                startAngle: -90
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (root.width - root.strokeWidth) / 2
                radiusY: (root.height - root.strokeWidth) / 2
                startAngle: -90
                sweepAngle: (root.value / root.maxValue) * 360
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.text !== "" ? root.text : Math.round(root.value) + "%"
        color: "#cdd6f4"
        font.pixelSize: root.height * 0.2
        font.bold: true
        font.family: "JetBrains Mono Nerd Font"
    }
}
