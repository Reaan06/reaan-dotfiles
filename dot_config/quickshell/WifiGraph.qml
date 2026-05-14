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

    property bool connected: false
    property string ssid: ""
    property string signal: ""
    property string security: ""
    property string mac: ""
    property string localIp: ""
    property string publicIp: ""

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
                var parts = text.trim().split("|")
                if (parts[0] === "connected") {
                    root.connected = true
                    root.ssid = parts[1] || "Unknown"
                    root.signal = parts[2] || "0"
                    root.security = parts[3] || "None"
                    root.mac = parts[4] || "N/A"
                } else {
                    root.connected = false
                }
            }
        }
    }

    Process {
        id: ipLocalProc
        command: ["sh", "-c", "~/.config/scripts/network-manager.sh ip_local"]
        stdout: StdioCollector { onStreamFinished: (text) => root.localIp = text.trim() }
    }

    Process {
        id: ipPublicProc
        command: ["sh", "-c", "~/.config/scripts/network-manager.sh ip_public"]
        stdout: StdioCollector { onStreamFinished: (text) => root.publicIp = text.trim() }
    }

    Process {
        id: scanProc
        command: ["sh", "-c", "~/.config/scripts/network-manager.sh scan"]
        stdout: StdioCollector {
            onStreamFinished: (text) => {
                var lines = text.trim().split("\n")
                var results = []
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i]) {
                        var p = lines[i].split(":")
                        if (p.length >= 2) {
                            results.push({ssid: p[0], signal: p[1], security: p[2] || ""})
                        }
                    }
                }
                root.scanResults = results
                root.isSearching = false
            }
        }
    }

    Process { id: connectProc }

    Timer { interval: 3000; running: !root.isSearching; repeat: true; triggeredOnStart: true; onTriggered: infoProc.running = true }

    // Grafo
    GraphCanvas {
        anchors.fill: parent
        centerX: width / 2; centerY: height / 2
        nodes: {
            if (root.showingAuth) return []
            if (root.scanResults.length > 0 && !root.connected) {
                var n = []
                for (var i = 0; i < root.scanResults.length; i++) {
                    var angle = (i / root.scanResults.length) * 2 * Math.PI
                    n.push({ x: width/2 + 280 * Math.cos(angle), y: height/2 + 280 * Math.sin(angle), color: root.accentColor })
                }
                return n
            }
            if (root.connected) {
                return [
                    { x: width/2 + 300, y: height/2, color: root.accentColor },
                    { x: width/2, y: height/2 + 300, color: root.accentColor },
                    { x: width/2 - 300, y: height/2, color: root.accentColor },
                    { x: width/2, y: height/2 - 300, color: root.accentColor }
                ]
            }
            return []
        }
    }

    // ── VISTA: Grafo de Conexión o Búsqueda ──
    Item {
        anchors.fill: parent
        visible: !root.showingAuth

        // Nodo Central
        NetworkNode {
            anchors.centerIn: parent
            icon: root.connected ? "󰖩" : (root.isSearching ? "󰖩" : "󰖪")
            label: root.connected ? root.ssid : (root.isSearching ? "BUSCANDO..." : "WIFI")
            subLabel: root.connected ? "Conectado" : "Pulsa para buscar"
            active: root.connected || root.isSearching
            loading: root.isSearching
            accentColor: root.accentColor; scale: 1.5
            onClicked: {
                if (!root.connected) {
                    root.isSearching = true
                    scanProc.running = true
                }
            }
        }

        // Nodos Satélites (Info Conectada)
        Repeater {
            model: root.connected ? 4 : 0
            NetworkNode {
                property var info: [
                    {i:"󰩟", l:"IP Local", s:root.localIp},
                    {i:"󰖟", l:"IP Pública", s:root.publicIp},
                    {i:"󰇧", l:"MAC", s:root.mac},
                    {i:"󰈀", l:"Señal", s:root.signal+"%"}
                ][index]
                x: parent.width/2 + (index==0?300 : index==1?0 : index==2?-300 : 0) - 70
                y: parent.height/2 + (index==0?0 : index==1?300 : index==2?0 : -300) - 70
                icon: info.i; label: info.l; subLabel: info.s
                accentColor: root.accentColor; scale: 1.1
            }
        }

        // Nodos Satélites (Resultados de Búsqueda)
        Repeater {
            model: (!root.connected && root.scanResults.length > 0) ? root.scanResults.length : 0
            NetworkNode {
                property var result: root.scanResults[index]
                x: parent.width/2 + 280 * Math.cos((index/root.scanResults.length)*2*Math.PI) - 70
                y: parent.height/2 + 280 * Math.sin((index/root.scanResults.length)*2*Math.PI) - 70
                icon: "󰖩"; label: result.ssid; subLabel: result.signal + "%"; scale: 0.9
                accentColor: root.accentColor
                onClicked: {
                    root.selectedSsid = result.ssid
                    if (result.security !== "--") root.showingAuth = true
                    else {
                        connectProc.command = ["nmcli", "device", "wifi", "connect", result.ssid]
                        connectProc.running = true
                    }
                }
            }
        }

        // Botón "Atrás" en búsqueda
        NetworkNode {
            visible: !root.connected && root.scanResults.length > 0
            x: parent.width/2 + 150; y: parent.height/2 - 150
            icon: "󰌍"; label: "ATRÁS"; scale: 0.7; accentColor: "#f38ba8"
            onClicked: root.scanResults = []
        }
    }

    // ── VISTA: Formulario de Autenticación ──
    Rectangle {
        anchors.fill: parent
        visible: root.showingAuth
        color: "transparent"

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 20
            width: 400

            NetworkNode {
                Layout.alignment: Qt.AlignHCenter
                icon: "󰷦"; label: root.selectedSsid; subLabel: "Requiere contraseña"; scale: 1.2
                accentColor: root.accentColor
            }

            TextField {
                id: passField
                Layout.fillWidth: true
                placeholderText: "Contraseña..."
                echoMode: TextInput.Password
                font.family: root.font
                color: root.cText
                background: Rectangle { radius: 8; color: root.cSurface; border.color: root.accentColor }
                onTextChanged: root.password = text
            }

            RowLayout {
                spacing: 15
                Button {
                    text: "CANCELAR"; font.family: root.font; Layout.fillWidth: true
                    onClicked: root.showingAuth = false
                }
                Button {
                    text: "CONECTAR"; font.family: root.font; Layout.fillWidth: true
                    onClicked: {
                        connectProc.command = ["nmcli", "device", "wifi", "connect", root.selectedSsid, "password", root.password]
                        connectProc.running = true
                        root.showingAuth = false
                        root.scanResults = []
                    }
                }
            }
        }
    }
}
