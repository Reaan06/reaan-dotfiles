import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    objectName: "TemperatureHistoryView.qml"
    
    readonly property string font: "JetBrains Mono Nerd Font"
    property color cMauve: "#cba6f7"
    property color cText: "#cdd6f4"
    property color cSub: "#6c7086"

    ColumnLayout {
        anchors.fill: parent; spacing: 20

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "TEMPERATURE TRACKER"; font.family: root.font; font.pixelSize: 18; font.bold: true
                color: root.cMauve
            }
            Item { Layout.fillWidth: true }
            Text { text: "MARCH 2026"; font.family: root.font; font.pixelSize: 14; font.bold: true; color: root.cText }
        }

        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: 24; color: Qt.rgba(1,1,1,0.03)
            border.color: Qt.rgba(1,1,1,0.06); border.width: 1
            
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 24; spacing: 16
                
                // Simulated Chart Placeholder with style
                RowLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
                    Repeater {
                        model: [40, 45, 50, 48, 55, 60, 58, 52, 48, 45, 42, 40]
                        Rectangle {
                            Layout.fillHeight: true; Layout.fillWidth: true; radius: 6
                            color: index === 5 ? root.cMauve : Qt.rgba(1,1,1,0.08)
                            Rectangle {
                                anchors.bottom: parent.bottom; width: parent.width; radius: 6
                                height: parent.height * (modelData / 100); color: index === 5 ? root.cMauve : root.cSub; opacity: 0.6
                            }
                        }
                    }
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    Repeater {
                        model: ["00", "02", "04", "06", "08", "10", "12", "14", "16", "18", "20", "22"]
                        Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: modelData; font.family: root.font; font.pixelSize: 10; color: root.cSub }
                    }
                }
            }
        }
    }
}
