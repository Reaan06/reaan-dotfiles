import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    property var currentData: null
    color: Qt.rgba(1, 1, 1, 0.05); radius: 20; border.color: Qt.rgba(1, 1, 1, 0.1)
    
    readonly property string font: "JetBrains Mono Nerd Font"
    property color cBlue: "#89b4fa"
    property color cMauve: "#cba6f7"
    property color cGreen: "#a6e3a1"
    property color cTeal: "#94e2d5"
    property color cText: "#cdd6f4"
    property color cSub: "#6c7086"
    property color cBg: Qt.rgba(0.1, 0.1, 0.15, 0.3)

    function parsePalette(raw) {
        if (!raw || raw.length === 0) return
        var parts = raw.split(" ")
        if (parts.length < 8) return
        try {
            cBlue  = parts[1] || cBlue
            cTeal  = parts[2] || cTeal
            cMauve = parts[3] || cMauve
            cGreen = parts[2] || cGreen 
            cText  = parts[6] || cText
            cSub   = parts[7] || cSub
        } catch (e) {
            console.log("Error parsing palette in WeatherDetails: " + e)
        }
    }

    Process {
        id: paletteProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/.palette 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { root.parsePalette(text.trim()) } }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: paletteProc.running = true }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 20; spacing: 20
        Text { text: "DETALLES"; font.family: root.font; font.pixelSize: 14; font.bold: true; color: root.cGreen }

        Repeater {
            model: [
                { label: "Humedad", value: root.currentData ? root.currentData.humidity + "%" : "--", icon: "󰖖", color: root.cBlue },
                { label: "Viento", value: root.currentData ? root.currentData.wind + " km/h" : "--", icon: "󰖝", color: root.cMauve },
                { label: "Lluvia", value: root.currentData ? root.currentData.rain + "%" : "--", icon: "󰖓", color: root.cMauve },
                { label: "Índice", value: "Normal", icon: "󰖙", color: root.cTeal }
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
                        color: root.cSub
                    }
                    Text {
                        text: modelData.value
                        font.family: root.font
                        font.pixelSize: 14
                        font.bold: true
                        color: root.cText
                    }
                }
            }
        }
        
        Item { Layout.fillHeight: true }
    }
}
