import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    objectName: "SystemMonitor.qml"
    
    readonly property string font: "JetBrains Mono Nerd Font"
    property color cMauve: "#cba6f7"
    property color cText: "#cdd6f4"
    property color cSub: "#6c7086"

    property string cpuTemp: "..."
    property string diskUsage: "..."
    property string memUsage: "..."

    // Data Fetching
    Process {
        id: statsProc
        command: ["sh", "-c", "~/.config/scripts/get_temp.sh; ~/.config/scripts/get_disk_usage.sh; ~/.config/scripts/get_memory_usage.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n")
                if (lines.length >= 3) {
                    root.cpuTemp = lines[0] + "°C"
                    root.diskUsage = lines[1]
                    root.memUsage = lines[2]
                }
            }
        }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: statsProc.running = true }

    ColumnLayout {
        anchors.fill: parent; spacing: 32

        Text {
            text: "SYSTEM HARDWARE"; font.family: root.font; font.pixelSize: 18; font.bold: true
            color: root.cMauve
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 24

            // CPU Temp Card
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 160; radius: 24; color: Qt.rgba(1,1,1,0.03)
                border.color: Qt.rgba(1,1,1,0.06); border.width: 1
                ColumnLayout {
                    anchors.centerIn: parent; spacing: 12
                    Text { text: "󰍛 CPU TEMP"; font.family: root.font; font.pixelSize: 12; font.bold: true; color: root.cSub; Layout.alignment: Qt.AlignHCenter }
                    Text { text: root.cpuTemp; font.family: root.font; font.pixelSize: 32; font.bold: true; color: root.cText; Layout.alignment: Qt.AlignHCenter }
                }
            }

            // Disk Card
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 160; radius: 24; color: Qt.rgba(1,1,1,0.03)
                border.color: Qt.rgba(1,1,1,0.06); border.width: 1
                ColumnLayout {
                    anchors.centerIn: parent; spacing: 12
                    Text { text: "󰋊 DISK USAGE"; font.family: root.font; font.pixelSize: 12; font.bold: true; color: root.cSub; Layout.alignment: Qt.AlignHCenter }
                    Text { text: root.diskUsage; font.family: root.font; font.pixelSize: 32; font.bold: true; color: root.cText; Layout.alignment: Qt.AlignHCenter }
                }
            }

            // Memory Card
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 160; radius: 24; color: Qt.rgba(1,1,1,0.03)
                border.color: Qt.rgba(1,1,1,0.06); border.width: 1
                ColumnLayout {
                    anchors.centerIn: parent; spacing: 12
                    Text { text: "󰑭 MEMORY"; font.family: root.font; font.pixelSize: 12; font.bold: true; color: root.cSub; Layout.alignment: Qt.AlignHCenter }
                    Text { text: root.memUsage; font.family: root.font; font.pixelSize: 20; font.bold: true; color: root.cText; Layout.alignment: Qt.AlignHCenter }
                }
            }
        }
        
        Item { Layout.fillHeight: true }
    }
}
