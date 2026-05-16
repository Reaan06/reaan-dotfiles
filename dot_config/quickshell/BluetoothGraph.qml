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
                    root.isSearching = false
                } catch(e) { root.isSearching = false }
            }
        }
    }

    Process { id: execProc }

    Timer { interval: 4000; running: !root.isSearching; repeat: true; triggeredOnStart: true; onTriggered: btInfoProc.running = true }

    property real animTime: 0
    Timer { interval: 16; running: root.isSearching || (!root.connected && root.scanResults.length > 0); repeat: true; onTriggered: root.animTime += 0.016 }

    // Grafo
    GraphCanvas {
        anchors.fill: parent
        centerX: width / 2; centerY: height / 2
        nodes: {
            let n = []
            if (root.connected) {
                let offsets = [[250, 180], [-250, 180], [0, -250]]
                for (let o of offsets) n.push({ x: width/2 + o[0], y: height/2 + o[1], color: root.accentColor })
            } else if (root.scanResults.length > 0) {
                for (let i = 0; i < root.scanResults.length; i++) {
                    let angle = (i / root.scanResults.length) * 2 * Math.PI + (root.animTime * 0.4)
                    n.push({ x: width/2 + 280 * Math.cos(angle), y: height/2 + 280 * Math.sin(angle), color: root.accentColor })
                }
            }
            return n
        }
    }

    // Nodo Central
    NetworkNode {
        anchors.centerIn: parent
        icon: root.connected ? (root.type === "audio-card" || root.type === "audio-headset" ? "󰋋" : "󰂱") : (root.isSearching ? "󰂯" : "󰂲")
        label: root.connected ? root.deviceName : (root.isSearching ? "BUSCANDO..." : "BLUETOOTH")
        subLabel: root.connected ? "Enlace Activo" : "Pulsa para buscar"
        active: root.connected || root.isSearching
        loading: root.isSearching
        accentColor: root.accentColor; scale: 1.5
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
                {i:"󰥉", l:"Batería", s:root.battery + (root.battery !== "N/A" ? "%" : "")},
                {i:"󰇧", l:"MAC ID", s:root.mac},
                {i:"󰂲", l:"Desconectar", s:"Cerrar vínculo"}
            ][index]
            x: parent.width/2 + (index==0?250 : index==1?-250 : 0) - 70
            y: parent.height/2 + (index==0?180 : index==1?180 : -250) - 70
            icon: info.i; label: info.l; subLabel: info.s
            accentColor: (index == 2) ? "#f38ba8" : root.accentColor; scale: 1.1
            onClicked: {
                if (index == 2) {
                    execProc.command = ["bluetoothctl", "disconnect", root.mac]
                    execProc.running = true
                }
            }
        }
    }

    // Satélites (Búsqueda)
    Repeater {
        model: (!root.connected && root.scanResults.length > 0) ? root.scanResults.length : 0
        NetworkNode {
            property var result: root.scanResults[index]
            property real angle: (index / root.scanResults.length) * 2 * Math.PI + (root.animTime * 0.4)
            
            x: parent.width/2 + 280 * Math.cos(angle) - 70
            y: parent.height/2 + 280 * Math.sin(angle) - 70
            
            icon: "󰂯"; label: result.name; subLabel: "Pulsa para vincular"; scale: 0.9
            accentColor: root.accentColor
            onClicked: {
                execProc.command = ["sh", "-c", "bluetoothctl pair " + result.mac + " && bluetoothctl trust " + result.mac + " && bluetoothctl connect " + result.mac]
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
