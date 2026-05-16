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

    property string statusText: "WIFI"
    property string subStatusText: "Pulsa para buscar"

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
                        root.statusText = data.ssid
                        root.subStatusText = "Conectado"
                    } else {
                        root.connected = false
                        if (!root.isSearching) {
                            root.statusText = "WIFI"
                            root.subStatusText = "Pulsa para buscar"
                        }
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
                    // Fix potential trailing commas or malformed JSON from bash
                    if (cleanText.endsWith(",]")) cleanText = cleanText.replace(",]", "]")
                    
                    var data = JSON.parse(cleanText)
                    root.scanResults = data
                    
                    if (data.length === 0) {
                        root.statusText = "WIFI"
                        root.subStatusText = "No se encontraron redes"
                    } else {
                        root.statusText = "RESULTADOS"
                        root.subStatusText = data.length + " redes encontradas"
                    }
                } catch(e) { 
                    console.log("Error parseando WiFi:", e)
                    root.subStatusText = "Error en el escaneo"
                }
                root.isSearching = false
            }
        }
    }

    Process { id: connectProc }

    Timer { interval: 5000; running: !root.isSearching; repeat: true; triggeredOnStart: true; onTriggered: infoProc.running = true }

    property real animTime: 0
    Timer { 
        id: animTimer
        interval: 16; running: root.isSearching || (!root.connected && root.scanResults.length > 0); repeat: true 
        onTriggered: root.animTime += 0.016 
    }

    // ── VISTA: Grafo de Radar ──
    GraphCanvas {
        id: canvas
        anchors.fill: parent
        centerX: width / 2; centerY: height / 2
        nodes: {
            if (root.showingAuth) return []
            let n = []
            if (root.connected) {
                let offsets = [[280,0], [0,280], [-280,0], [0,-280]]
                for (let o of offsets) n.push({ x: width/2 + o[0], y: height/2 + o[1], color: root.accentColor })
            } else if (root.scanResults.length > 0) {
                for (let i = 0; i < root.scanResults.length; i++) {
                    let res = root.scanResults[i]
                    let radius = 180 + (100 - res.signal) * 2
                    let angle = (i / root.scanResults.length) * 2 * Math.PI + (root.animTime * 0.4)
                    n.push({ x: width/2 + radius * Math.cos(angle), y: height/2 + radius * Math.sin(angle), color: root.accentColor })
                }
            }
            return n
        }
    }

    Item {
        anchors.fill: parent
        visible: !root.showingAuth

        // Nodo Central
        NetworkNode {
            anchors.centerIn: parent
            icon: root.connected ? "󰖩" : (root.isSearching ? "󰖩" : "󰖪")
            label: root.isSearching ? "BUSCANDO..." : root.statusText
            subLabel: root.isSearching ? "Escaneando entorno" : root.subStatusText
            active: root.connected || root.isSearching
            loading: root.isSearching
            accentColor: root.accentColor; scale: 1.5
            onClicked: {
                if (!root.connected && !root.isSearching) {
                    root.isSearching = true
                    root.scanResults = []
                    scanProc.running = true
                }
            }
        }

        // Info Satélites
        Repeater {
            model: root.connected ? 4 : 0
            NetworkNode {
                property var info: [
                    {i:"󰩟", l:"IP Local", s:root.localIp},
                    {i:"󰇧", l:"MAC", s:root.mac},
                    {i:"󰈀", l:"Señal", s:root.signal+"%"},
                    {i:"󰌍", l:"Desconectar", s:"Cerrar vínculo"}
                ][index]
                x: parent.width/2 + (index==0?280 : index==1?0 : index==2?-280 : 0) - 70
                y: parent.height/2 + (index==0?0 : index==1?280 : index==2?0 : -280) - 70
                icon: info.i; label: info.l; subLabel: info.s
                accentColor: index == 3 ? "#f38ba8" : root.accentColor; scale: 1.1
                onClicked: {
                    if (index == 3) {
                        connectProc.command = ["nmcli", "device", "disconnect", "wlan0"]
                        connectProc.running = true
                    }
                }
            }
        }

        // Resultados Radar (Orbitando)
        Repeater {
            model: (!root.connected && root.scanResults.length > 0) ? root.scanResults.length : 0
            NetworkNode {
                property var result: root.scanResults[index]
                property real radius: 150 + (100 - result.signal) * 2
                property real angle: (index / root.scanResults.length) * 2 * Math.PI + (root.animTime * 0.5)
                
                x: parent.width/2 + radius * Math.cos(angle) - 70
                y: parent.height/2 + radius * Math.sin(angle) - 70
                
                icon: "󰖩"; label: result.ssid; subLabel: result.signal + "%"; scale: 0.9
                accentColor: root.accentColor
                onClicked: {
                    root.selectedSsid = result.ssid
                    if (result.security !== "--" && result.security !== "None") root.showingAuth = true
                    else {
                        connectProc.command = ["nmcli", "device", "wifi", "connect", result.ssid]
                        connectProc.running = true
                    }
                }
            }
        }
    }

    // Auth Overlay (Simplified)
    Rectangle {
        anchors.fill: parent; visible: root.showingAuth; color: Qt.rgba(0,0,0,0.4)
        ColumnLayout {
            anchors.centerIn: parent; spacing: 20; width: 350
            Text { text: "CONTRASEÑA PARA\n" + root.selectedSsid; font.family: root.font; font.pixelSize: 18; font.bold: true; color: root.cText; horizontalAlignment: Text.AlignHCenter }
            TextField {
                id: passField; Layout.fillWidth: true; placeholderText: "Password..."; echoMode: TextInput.Password; font.family: root.font; color: root.cText
                background: Rectangle { radius: 12; color: root.cSurface; border.color: root.accentColor }
                onTextChanged: root.password = text
            }
            RowLayout {
                spacing: 12
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
