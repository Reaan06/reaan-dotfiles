import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    objectName: "TemperatureHistoryView.qml"
    
    readonly property string font: "JetBrains Mono Nerd Font"
    property color cMauve: "#cba6f7"
    property color cBlue: "#89b4fa"
    property color cTeal: "#94e2d5"
    property color cText: "#cdd6f4"
    property color cSub: "#6c7086"
    property color cBg: Qt.rgba(0.1, 0.1, 0.15, 0.4)

    function parsePalette(raw) {
        if (!raw || raw.length === 0) return
        var parts = raw.split(" ")
        if (parts.length < 8) return
        try {
            var pc = parts[0]
            if (pc && pc.startsWith("#") && pc.length >= 7) {
                cBg    = Qt.rgba(parseInt(pc.substr(1,2),16)/255, parseInt(pc.substr(3,2),16)/255, parseInt(pc.substr(5,2),16)/255, 0.4)
            }
            cBlue  = parts[1] || cBlue
            cTeal  = parts[2] || cTeal
            cMauve = parts[3] || cMauve
            cText  = parts[6] || cText
            cSub   = parts[7] || cSub
        } catch (e) {
            console.log("Error parsing palette in TemperatureHistoryView: " + e)
        }
    }

    Process {
        id: paletteProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/.palette 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { root.parsePalette(text.trim()) } }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: paletteProc.running = true }

    ColumnLayout {
        anchors.fill: parent; spacing: 32

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                spacing: 4
                Text {
                    text: "SENSORS & TEMPERATURE"; font.family: root.font; font.pixelSize: 18; font.bold: true
                    color: root.cMauve
                }
                Text {
                    text: "Historical data and heat levels"; font.family: root.font; font.pixelSize: 12; color: root.cSub
                }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                width: 120; height: 36; radius: 10; color: root.cBg; border.color: Qt.rgba(1,1,1,0.06)
                Text { anchors.centerIn: parent; text: "APRIL 2026"; font.family: root.font; font.pixelSize: 12; font.bold: true; color: root.cText }
            }
        }

        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: 24; color: root.cBg
            border.color: Qt.rgba(1,1,1,0.06); border.width: 1
            
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 32; spacing: 20
                
                RowLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 16
                    Repeater {
                        model: [38, 42, 55, 68, 72, 65, 58, 52, 48, 45, 42, 40, 38, 41, 44, 48, 52, 58, 62, 65, 60, 55, 48, 42]
                        Rectangle {
                            Layout.fillHeight: true; Layout.fillWidth: true; radius: 6
                            color: modelData > 60 ? Qt.rgba(1, 0.4, 0.4, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                            Rectangle {
                                anchors.bottom: parent.bottom; width: parent.width; radius: 6
                                height: parent.height * (modelData / 100)
                                color: modelData > 60 ? "#f38ba8" : (index % 6 === 0 ? root.cMauve : root.cBlue)
                                opacity: 0.8
                                
                                Behavior on height { NumberAnimation { duration: 1000; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    Repeater {
                        model: ["00", "04", "08", "12", "16", "20", "24"]
                        Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: modelData; font.family: root.font; font.pixelSize: 11; color: root.cSub }
                    }
                }
            }
        }
        
        RowLayout {
            Layout.fillWidth: true; spacing: 24
            Repeater {
                model: [
                    { name: "Max Temp", val: "72°C", color: "#f38ba8" },
                    { name: "Avg Temp", val: "54°C", color: root.cMauve },
                    { name: "Min Temp", val: "38°C", color: root.cBlue }
                ]
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 80; radius: 20; color: root.cBg; border.color: Qt.rgba(1,1,1,0.06)
                    ColumnLayout {
                        anchors.centerIn: parent; spacing: 4
                        Text { text: modelData.name; font.family: root.font; font.pixelSize: 11; color: root.cSub; Layout.alignment: Qt.AlignHCenter }
                        Text { text: modelData.val; font.family: root.font; font.pixelSize: 20; font.bold: true; color: modelData.color; Layout.alignment: Qt.AlignHCenter }
                    }
                }
            }
        }
    }
}
