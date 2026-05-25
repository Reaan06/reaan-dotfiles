import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "components"

Item {
    id: root
    property real scale: 1.0
    property color accentColor: "#89b4fa"

    property color cBg:      Qt.rgba(0.07, 0.07, 0.1, 0.90)
    property color cText:    "#cdd6f4"
    property color cSub:     "#6c7086"
    property string font:    "JetBrains Mono Nerd Font"
    property color cSurface: Qt.rgba(1, 1, 1, 0.05)

    property bool connected: false
    property string ssid: ""
    property string signal: ""
    property string security: ""
    property string mac: ""
    property string localIp: ""

    // Búsqueda y Selección
    property bool isSearching: false
    property var scanResults: []
    property string selectedSsid: ""
    property string password: ""
    property bool showingAuth: false

    Process {
        id: infoProc
        command: ["sh", "-c", "~/.config/scripts/network-manager.sh info"]
        stdout: StdioCollector {
            onStreamFinished: (text) => {
                try {
                    var data = JSON.parse(text.trim())
                    if (data.status === "connected") {
                        root.connected = true
                        root.ssid = data.ssid
                        root.signal = data.signal.toString()
                        root.security = data.security
                        root.mac = data.mac
                        root.localIp = data.local_ip
                    } else {
                        root.connected = false
                    }
                } catch(e) { root.connected = false }
            }
        }
    }

    Process {
        id: scanProc
        command: ["sh", "-c", "~/.config/scripts/network-manager.sh scan"]
        stdout: StdioCollector {
            onStreamFinished: (text) => {
                try {
                    var cleanText = text.trim()
                    if (cleanText.endsWith(",]")) cleanText = cleanText.replace(",]", "]")
                    var results = JSON.parse(cleanText)
                    results.sort((a, b) => {
                        if (a.known !== b.known) return (b.known ? 1 : 0) - (a.known ? 1 : 0);
                        return b.signal - a.signal;
                    })
                    root.scanResults = results
                } catch(e) { 
                    console.log("Error parseando WiFi:", e)
                }
                root.isSearching = false
            }
        }
    }

    Process { id: connectProc }

    Timer { interval: 5000; running: !root.isSearching; repeat: true; triggeredOnStart: true; onTriggered: infoProc.running = true }

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
                    Text { anchors.centerIn: parent; text: root.connected ? "󰖩" : "󰖪"; font.family: root.font; font.pixelSize: 28 * root.scale; color: "#11111b" }
                }

                ColumnLayout {
                    spacing: 2 * root.scale
                    Text { 
                        text: root.connected ? root.ssid : "Sin conexión"
                        font.family: root.font; font.pixelSize: 18 * root.scale; font.bold: true; color: root.cText 
                    }
                    Text { 
                        text: root.connected ? "Conectado • " + root.localIp : "Pulsa 'Escanear' para buscar redes"
                        font.family: root.font; font.pixelSize: 12 * root.scale; color: root.cSub 
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: root.isSearching ? "BUSCANDO..." : "ESCANEAR"
                    enabled: !root.isSearching
                    onClicked: {
                        root.isSearching = true
                        scanProc.running = true
                    }
                }
            }
        }

        // ── List Area ──
        Text { 
            text: "REDES DISPONIBLES"
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
                    width: ListView.view.width; height: 80 * root.scale; radius: 16 * root.scale
                    color: root.cSurface
                    border.color: mouseArea.containsMouse ? root.accentColor : "transparent"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 15 * root.scale; spacing: 15 * root.scale
                        
                        Text { text: "󰖩"; font.family: root.font; font.pixelSize: 22 * root.scale; color: root.accentColor }
                        
                        ColumnLayout {
                            spacing: 4 * root.scale
                            RowLayout {
                                spacing: 8 * root.scale
                                Text { text: modelData.ssid; font.family: root.font; font.pixelSize: 15 * root.scale; font.bold: true; color: root.cText }
                                
                                Rectangle {
                                    visible: modelData.known
                                    height: 16 * root.scale; radius: 4 * root.scale
                                    color: root.accentColor
                                    implicitWidth: knownText.implicitWidth + 10 * root.scale
                                    Text {
                                        id: knownText
                                        anchors.centerIn: parent
                                        text: "CONOCIDA"
                                        font.family: root.font; font.pixelSize: 9 * root.scale; font.bold: true; color: "#11111b"
                                    }
                                }
                            }

                            Text { 
                                text: modelData.band + " • Ch " + modelData.chan + " • " + modelData.rate + " • " + modelData.security
                                font.family: root.font; font.pixelSize: 10 * root.scale; color: root.cSub 
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Text { 
                            text: modelData.signal + "%"
                            font.family: root.font; font.pixelSize: 12 * root.scale; font.bold: true; color: root.cSub
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Rectangle {
                            width: 36 * root.scale; height: 36 * root.scale; radius: 10 * root.scale
                            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.1)
                            Text { anchors.centerIn: parent; text: "󱘖"; font.family: root.font; font.pixelSize: 16 * root.scale; color: root.accentColor }
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedSsid = modelData.ssid
                            if (modelData.security !== "--" && modelData.security !== "None") root.showingAuth = true
                            else {
                                connectProc.command = ["nmcli", "device", "wifi", "connect", modelData.ssid]
                                connectProc.running = true
                            }
                        }
                    }
                }
            }
        }
    }

    // Auth Overlay
    Rectangle {
        anchors.fill: parent; visible: root.showingAuth; color: Qt.rgba(0,0,0,0.7); radius: 32 * root.scale
        ColumnLayout {
            anchors.centerIn: parent; spacing: 20 * root.scale; width: parent.width * 0.6
            Text { 
                text: "CONEXIÓN A RED"
                font.family: root.font; font.pixelSize: 22 * root.scale; font.bold: true; color: root.cText; horizontalAlignment: Text.AlignHCenter 
                Layout.fillWidth: true
            }
            Text { 
                text: root.selectedSsid
                font.family: root.font; font.pixelSize: 14 * root.scale; color: root.accentColor; horizontalAlignment: Text.AlignHCenter 
                Layout.fillWidth: true
            }
            TextField {
                id: passField; Layout.fillWidth: true; placeholderText: "Contraseña..."; echoMode: TextInput.Password; font.family: root.font; color: root.cText
                background: Rectangle { radius: 12 * root.scale; color: root.cBg; border.color: root.accentColor }
                onTextChanged: root.password = text
            }
            RowLayout {
                spacing: 12 * root.scale
                Button { text: "CANCELAR"; Layout.fillWidth: true; onClicked: root.showingAuth = false }
                Button { 
                    text: "CONECTAR"; Layout.fillWidth: true; 
                    onClicked: {
                        connectProc.command = ["nmcli", "device", "wifi", "connect", root.selectedSsid, "password", root.password]
                        connectProc.running = true
                        root.showingAuth = false
                    }
                }
            }
        }
    }
}
