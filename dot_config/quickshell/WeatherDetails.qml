import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property var currentData: null
    color: Qt.rgba(1, 1, 1, 0.05); radius: 20; border.color: Qt.rgba(1, 1, 1, 0.1)
    
    readonly property string font: "JetBrains Mono Nerd Font"

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 20; spacing: 20
        Text { text: "DETALLES"; font.family: root.font; font.pixelSize: 14; font.bold: true; color: "#a6e3a1" }

        Repeater {
            model: [
                { label: "Humedad", value: root.currentData ? root.currentData.humidity + "%" : "--", icon: "󰖖", color: "#89b4fa" },
                { label: "Viento", value: root.currentData ? root.currentData.wind + " km/h" : "--", icon: "󰖝", color: "#f9e2af" },
                { label: "Lluvia", value: root.currentData ? root.currentData.rain + "%" : "--", icon: "󰖓", color: "#f38ba8" },
                { label: "Índice", value: "Normal", icon: "󰖙", color: "#94e2d5" }
            ]

            delegate: RowLayout {
                Layout.fillWidth: true; spacing: 15

                Rectangle {
                    width: 40; height: 40; radius: 10
                    color: Qt.rgba(1, 1, 1, 0.05)
                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        font.pixelSize: 18
                        color: modelData.color
                    }
                }

                ColumnLayout {
                    spacing: 0
                    Text {
                        text: modelData.label
                        font.family: root.font
                        font.pixelSize: 11
                        color: "#6c7086"
                    }
                    Text {
                        text: modelData.value
                        font.family: root.font
                        font.pixelSize: 14
                        font.bold: true
                        color: "#cdd6f4"
                    }
                }
            }
        }
        
        Item { Layout.fillHeight: true }
    }
}
