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
                var parts = text.trim().split("|")
                if (parts[0] === "connected") {
                    root.connected = true
                    root.deviceName = parts[1] || "Unknown"
                    root.mac = parts[2] || "N/A"
                    root.battery = parts[3] || "N/A"
                    root.type = parts[4] || "unknown"
                } else {
                    root.connected = false
                }
            }
        }
    }

    Process {
        id: btScanProc
        command: ["sh", "-c", "~/.config/scripts/bt-manager.sh devices"]
        stdout: StdioCollector {
            onStreamFinished: (text) => {
                var lines = text.trim().split("\n")
                var results = []
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i]) {
                        var p = lines[i].split(" ")
                        if (p.length >= 3) {
                            results.push({mac: p[1], name: p.slice(2).join(" ")})
                        }
                    }
                }
                root.scanResults = results
                root.isSearching = false
            }
        }
    }

    Process { id: execProc }

    Timer { interval: 4000; running: !root.isSearching; repeat: true; triggeredOnStart: true; onTriggered: btInfoProc.running = true }

    // Grafo
    GraphCanvas {
        anchors.fill: parent
        centerX: width / 2; centerY: height / 2
        nodes: {
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
                    { x: width/2 + 250, y: height/2 + 180, color: root.accentColor },
                    { x: width/2 - 250, y: height/2 + 180, color: root.accentColor },
                    { x: width/2, y: height/2 - 250, color: root.accentColor }
                ]
            }
            return []
        }
    }

    // Nodo Central
    NetworkNode {
        anchors.centerIn: parent
        icon: root.connected ? "󰂱" : (root.isSearching ? "󰂯" : "󰂲")
        label: root.connected ? root.deviceName : (root.isSearching ? "BUSCANDO..." : "BLUETOOTH")
        subLabel: root.connected ? "Enlace Activo" : "Pulsa para buscar"
        active: root.connected || root.isSearching
        loading: root.isSearching
        accentColor: root.accentColor; scale: 1.5
        cBg: root.cBg; cText: root.cText; cSub: root.cSub
        onClicked: {
            if (!root.connected) {
                root.isSearching = true
                btScanProc.running = true
            }
        }
    }

    // Satélites (Info Conectada)
    Repeater {
        model: root.connected ? 3 : 0
        NetworkNode {
            property var info: [
                {i:"󰥉", l:"Batería", s:root.battery + "%"},
                {i:"󰇧", l:"MAC ID", s:root.mac},
                {i: (root.type === "audio-card" ? "󰓃" : "󰂯"), l:"Desconectar", s:"Forzar cierre"}
            ][index]
            x: parent.width/2 + (index==0?250 : index==1?-250 : 0) - 70
            y: parent.height/2 + (index==0?180 : index==1?180 : -250) - 70
            icon: info.i; label: info.l; subLabel: info.s
            accentColor: (index == 2) ? "#f38ba8" : root.accentColor; scale: 1.1
            cBg: root.cBg; cText: root.cText; cSub: root.cSub
            onClicked: {
                if (index == 0) execProc.command = ["sh", "-c", "notify-send 'Energía' 'Batería: " + root.battery + "%'"]
                else if (index == 1) execProc.command = ["sh", "-c", "echo '" + root.mac + "' | wl-copy && notify-send 'Copiado' 'MAC copiada'"]
                else if (index == 2) execProc.command = ["sh", "-c", "bluetoothctl disconnect " + root.mac + " && notify-send 'Bluetooth' 'Dispositivo desconectado'"]
                execProc.running = true
            }
        }
    }

    // Satélites (Búsqueda)
    Repeater {
        model: (!root.connected && root.scanResults.length > 0) ? root.scanResults.length : 0
        NetworkNode {
            property var result: root.scanResults[index]
            x: parent.width/2 + 280 * Math.cos((index/root.scanResults.length)*2*Math.PI) - 70
            y: parent.height/2 + 280 * Math.sin((index/root.scanResults.length)*2*Math.PI) - 70
            icon: "󰂯"; label: result.name; subLabel: "Pulsa para vincular"; scale: 0.9
            accentColor: root.accentColor
            onClicked: {
                execProc.command = ["sh", "-c", "bluetoothctl connect " + result.mac]
                execProc.running = true
                root.scanResults = []
            }
        }
    }

    // Botón Atrás
    NetworkNode {
        visible: !root.connected && root.scanResults.length > 0
        x: parent.width/2 + 150; y: parent.height/2 - 150
        icon: "󰌍"; label: "ATRÁS"; scale: 0.7; accentColor: "#f38ba8"
        onClicked: root.scanResults = []
    }
}
