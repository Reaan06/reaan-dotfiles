import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "components"

Item {
    id: root
    property real scale: 1.0
    property color accentColor: "#cba6f7"

    property color cBg:      Qt.rgba(0.07, 0.07, 0.1, 0.90)
    property color cText:    "#cdd6f4"
    property color cSub:     "#6c7086"
    property string font:    "JetBrains Mono Nerd Font"
    property color cSurface: Qt.rgba(1, 1, 1, 0.05)

    property bool connected: false
    property string deviceName: ""
    property string mac: ""
    property string battery: ""
    property string type: "unknown"

    // Búsqueda
    property bool isSearching: false
    property var scanResults: []

    Process {
        id: btInfoProc
        command: ["sh", "-c", "~/.config/scripts/bt-manager.sh info"]
        stdout: StdioCollector {
            onStreamFinished: (text) => {
                try {
                    var data = JSON.parse(text.trim())
                    if (data.status === "connected") {
                        root.connected = true
                        root.deviceName = data.name
                        root.mac = data.mac
                        root.battery = data.battery
                        root.type = data.type
                    } else {
                        root.connected = false
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: btScanProc
        command: ["sh", "-c", "~/.config/scripts/bt-manager.sh scan"]
        stdout: StdioCollector {
            onStreamFinished: (text) => {
                try {
                    root.scanResults = JSON.parse(text.trim())
                } catch(e) { }
                root.isSearching = false
            }
        }
    }

    Process { id: execProc }

    Timer { interval: 4000; running: !root.isSearching; repeat: true; triggeredOnStart: true; onTriggered: btInfoProc.running = true }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        // ── Status Box ──
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 100 * root.scale; radius: 20 * root.scale
            color: root.connected ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.15) : root.cSurface
            border.color: root.connected ? root.accentColor : Qt.rgba(1,1,1,0.1); border.width: 1

            RowLayout {
                anchors.fill: parent; anchors.margins: 20 * root.scale; spacing: 20 * root.scale
                
                Rectangle {
                    width: 60 * root.scale; height: 60 * root.scale; radius: 16 * root.scale; color: root.connected ? root.accentColor : root.cSub
                    Text { 
                        anchors.centerIn: parent; 
                        text: root.connected ? (root.type === "audio-card" || root.type === "audio-headset" ? "󰋋" : "󰂱") : "󰂲"
                        font.family: root.font; font.pixelSize: 28 * root.scale; color: "#11111b" 
                    }
                }

                ColumnLayout {
                    spacing: 2 * root.scale
                    Text { 
                        text: root.connected ? root.deviceName : "Desconectado"
                        font.family: root.font; font.pixelSize: 18 * root.scale; font.bold: true; color: root.cText 
                    }
                    Text { 
                        text: root.connected ? "Conectado • Batería: " + root.battery + (root.battery !== "N/A" ? "%" : "") : "Pulsa 'Buscar' para vincular dispositivos"
                        font.family: root.font; font.pixelSize: 12 * root.scale; color: root.cSub 
                    }
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 10 * root.scale
                    Button {
                        text: "DESCONECTAR"
                        visible: root.connected
                        onClicked: {
                            execProc.command = ["bluetoothctl", "disconnect", root.mac]
                            execProc.running = true
                        }
                    }
                    Button {
                        text: root.isSearching ? "BUSCANDO..." : "BUSCAR"
                        enabled: !root.isSearching
                        onClicked: {
                            root.isSearching = true
                            btScanProc.running = true
                        }
                    }
                }
            }
        }

        // ── List Area ──
        Text { 
            text: "DISPOSITIVOS CONOCIDOS / ENCONTRADOS"
            font.family: root.font; font.pixelSize: 13 * root.scale; font.bold: true; color: root.cSub 
            visible: root.scanResults.length > 0
        }

        ScrollView {
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff

            ListView {
                model: root.scanResults
                spacing: 10 * root.scale
                delegate: Rectangle {
                    width: ListView.view.width; height: 70 * root.scale; radius: 16 * root.scale
                    color: root.cSurface
                    border.color: mouseArea.containsMouse ? root.accentColor : "transparent"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 15 * root.scale; spacing: 15 * root.scale
                        
                        Text { text: "󰂯"; font.family: root.font; font.pixelSize: 20 * root.scale; color: root.accentColor }
                        
                        ColumnLayout {
                            spacing: 0
                            Text { text: modelData.name; font.family: root.font; font.pixelSize: 15 * root.scale; font.bold: true; color: root.cText }
                            Text { text: modelData.mac; font.family: root.font; font.pixelSize: 11 * root.scale; color: root.cSub }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 36 * root.scale; height: 36 * root.scale; radius: 10 * root.scale
                            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.1)
                            Text { anchors.centerIn: parent; text: "󰄄"; font.family: root.font; font.pixelSize: 16 * root.scale; color: root.accentColor }
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            execProc.command = ["sh", "-c", "bluetoothctl pair " + modelData.mac + " && bluetoothctl trust " + modelData.mac + " && bluetoothctl connect " + modelData.mac]
                            execProc.running = true
                            root.scanResults = []
                        }
                    }
                }
            }
        }
    }
}
