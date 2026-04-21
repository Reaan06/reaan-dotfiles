import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    color: "transparent"

    readonly property string font: "JetBrains Mono Nerd Font"
    property color cYellow: "#f9e2af"
    property color cText: "#cdd6f4"
    property color cSub: "#6c7086"
    property color cBg: Qt.rgba(0.1, 0.1, 0.1, 0.4)

    Behavior on cYellow { ColorAnimation { duration: 600 } }
    Behavior on cText { ColorAnimation { duration: 600 } }
    Behavior on cSub { ColorAnimation { duration: 600 } }
    Behavior on cBg { ColorAnimation { duration: 600 } }

    function parsePalette(raw) {
        if (!raw || raw.length === 0) return
        var parts = raw.split(" ")
        if (parts.length < 8) return
        try {
            var pc = parts[0]
            if (pc && pc.startsWith("#") && pc.length >= 7) {
                cBg = Qt.rgba(parseInt(pc.substr(1,2),16)/255, parseInt(pc.substr(3,2),16)/255, parseInt(pc.substr(5,2),16)/255, 0.4)
            }
            cYellow = parts[4] || cYellow
            cText   = parts[6] || cText
            cSub    = parts[7] || cSub
        } catch (e) {
            console.log("Error parsing palette in ScreenUsage: " + e)
        }
    }

    Process {
        id: paletteProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/.palette 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { root.parsePalette(text.trim()) } }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: paletteProc.running = true }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20

        Rectangle {
            width: 120; height: 120; radius: 60
            color: Qt.rgba(root.cYellow.r, root.cYellow.g, root.cYellow.b, 0.1)
            border.color: root.cYellow; border.width: 2
            Text {
                anchors.centerIn: parent
                text: "󰍹"; font.pixelSize: 60; color: root.cYellow
            }
        }

        Text {
            text: "Uso en Pantalla"; font.family: root.font; font.pixelSize: 24; font.bold: true; color: root.cText
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: "Módulo en construcción..."; font.family: root.font; font.pixelSize: 14; color: root.cSub
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
