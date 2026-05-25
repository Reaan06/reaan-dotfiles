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
    readonly property color onAccentFg: "#11111b"

    readonly property string netScript: Quickshell.env("HOME") + "/.config/scripts/network-manager.sh"

    property bool connected: false
    property string ssid: ""
    property string signal: ""
    property string security: ""
    property string mac: ""
    property string localIp: ""

    property bool isSearching: false
    property bool scanAttempted: false
    property var scanResults: []
    property string selectedSsid: ""
    property string password: ""
    property bool showingAuth: false
    property string sudoPassword: ""
    property bool showingSudoAuth: false
    property string retrievedWifiPass: ""
    property bool showingWifiPass: false

    readonly property string getPassScript: Quickshell.env("HOME") + "/.config/scripts/get-wifi-pass.sh"

    function parseWifiJson(raw, label) {
        var clean = (raw || "").trim()
        if (!clean.length) return []
        if (clean.endsWith(",]")) clean = clean.replace(",]", "]")
        try {
            var data = JSON.parse(clean)
            if (Array.isArray(data)) return data
            if (data && data.error) console.log("Wifi " + label + " error:", data.error)
        } catch (e) {
            console.log("Wifi " + label + " parse error:", e, "raw:", clean.substring(0, 200))
        }
        return []
    }

    function applyInfo(raw) {
        try {
            var data = JSON.parse((raw || "").trim())
            if (data.status === "connected") {
                root.connected = true
                root.ssid = data.ssid || ""
                root.signal = (data.signal !== undefined) ? data.signal.toString() : ""
                root.security = data.security || ""
                root.mac = data.mac || ""
                root.localIp = data.local_ip || ""
            } else {
                root.connected = false
            }
        } catch (e) {
            console.log("Wifi Info Parse Error:", e)
            root.connected = false
        }
    }

    function applyScan(raw) {
        var results = parseWifiJson(raw, "scan")
        results.sort(function(a, b) {
            if (a.known !== b.known) return (b.known ? 1 : 0) - (a.known ? 1 : 0)
            return (b.signal || 0) - (a.signal || 0)
        })
        root.scanResults = results
        root.isSearching = false
        root.scanAttempted = true
    }

    function needsPassword(sec) {
        if (!sec || sec === "--" || sec === "None" || sec === "Open") return false
        return true
    }

    Process {
        id: infoProc
        command: ["sh", "-c", root.netScript + " info"]
        stdout: StdioCollector {
            onStreamFinished: applyInfo(text)
        }
    }

    Process {
        id: scanProc
        command: ["sh", "-c", root.netScript + " scan"]
        stdout: StdioCollector {
            onStreamFinished: applyScan(text)
        }
        onExited: function() {
            if (root.isSearching) {
                root.isSearching = false
                root.scanAttempted = true
            }
        }
    }

    Process {
        id: connectProc
        onExited: function() {
            infoProc.running = true
        }
    }

    Process {
        id: getPassProc
        command: ["sh", "-c", root.getPassScript + " '" + root.ssid + "' '" + root.sudoPassword + "'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.retrievedWifiPass = text.trim()
                if (root.retrievedWifiPass.length > 0) {
                    root.showingWifiPass = true
                }
            }
        }
    }

    Timer { interval: 5000; running: !root.isSearching; repeat: true; triggeredOnStart: true; onTriggered: infoProc.running = true }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 100 * root.scale; radius: 20 * root.scale
            color: root.connected ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.15) : root.cSurface
            border.color: root.connected ? root.accentColor : Qt.rgba(1,1,1,0.1); border.width: 1

            RowLayout {
                anchors.fill: parent; anchors.margins: 20 * root.scale; spacing: 20 * root.scale

                Rectangle {
                    width: 60 * root.scale; height: 60 * root.scale; radius: 16 * root.scale; color: root.connected ? root.accentColor : root.cSub
                    Text { anchors.centerIn: parent; text: root.connected ? "󰖩" : "󰖪"; font.family: root.font; font.pixelSize: 28 * root.scale; color: root.onAccentFg }
                }

                ColumnLayout {
                    spacing: 2 * root.scale
                    Text {
                        text: root.connected ? root.ssid : "Sin conexión"
                        font.family: root.font; font.pixelSize: 18 * root.scale; font.bold: true; color: root.cText
                    }
                    Text {
                        text: root.connected
                            ? ("Conectado • " + (root.localIp || "sin IP") + (root.signal ? " • " + root.signal + "%" : ""))
                            : "Pulsa 'Escanear' para buscar redes"
                        font.family: root.font; font.pixelSize: 12 * root.scale; color: root.cSub
                    }
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 10 * root.scale
                    ActionPill {
                        label: "VER CLAVE"
                        iconGlyph: "󰌆"
                        uiScale: root.scale
                        uiFont: root.font
                        accentColor: root.accentColor
                        onAccentFg: root.onAccentFg
                        fgColor: root.cText
                        visible: root.connected
                        onClicked: {
                            root.sudoPassword = ""
                            sudoPassField.text = ""
                            root.showingSudoAuth = true
                        }
                    }

                    ActionPill {
                        label: root.isSearching ? "BUSCANDO..." : "ESCANEAR"
                        iconGlyph: root.isSearching ? "󰑐" : "󰖩"
                        uiScale: root.scale
                        uiFont: root.font
                        accentColor: root.accentColor
                        onAccentFg: root.onAccentFg
                        fgColor: root.cText
                        primary: !root.isSearching
                        busy: root.isSearching
                        onClicked: {
                            root.isSearching = true
                            scanProc.running = true
                        }
                    }
                }
            }
        }

        Text {
            text: "REDES DISPONIBLES"
            font.family: root.font; font.pixelSize: 13 * root.scale; font.bold: true; color: root.cSub
            visible: root.scanResults.length > 0
        }

        Text {
            text: root.isSearching ? "Escaneando redes..." : "No se encontraron redes. Vuelve a escanear."
            font.family: root.font; font.pixelSize: 12 * root.scale; color: root.cSub
            visible: root.scanAttempted && !root.isSearching && root.scanResults.length === 0
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
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
                                        font.family: root.font; font.pixelSize: 9 * root.scale; font.bold: true; color: root.onAccentFg
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
                            if (root.needsPassword(modelData.security)) {
                                root.password = ""
                                passField.text = ""
                                root.showingAuth = true
                            } else {
                                connectProc.command = ["nmcli", "device", "wifi", "connect", modelData.ssid]
                                connectProc.running = true
                            }
                        }
                    }
                }
            }
        }
    }

    // --- MODALS LAYER ---
    Item {
        id: modalsLayer
        anchors.fill: parent
        z: 10
        visible: root.showingAuth || root.showingSudoAuth || root.showingWifiPass

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0,0,0,0.7)
            radius: 32 * root.scale

            MouseArea { 
                anchors.fill: parent
                propagateComposedEvents: true 
                onPressed: (mouse) => mouse.accepted = false
            }
        }

        // 1. WiFi Connection Auth (Original)
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.7
            height: parent.height * 0.5
            color: "transparent"
            visible: root.showingAuth
            onVisibleChanged: if (visible) passField.forceActiveFocus()

            ColumnLayout {
                anchors.centerIn: parent; spacing: 20 * root.scale; width: parent.width
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
                    focus: true
                    background: Rectangle { radius: 12 * root.scale; color: root.cBg; border.color: root.accentColor }
                    onTextChanged: root.password = text
                }
                RowLayout {
                    spacing: 12 * root.scale
                    Layout.fillWidth: true
                    ActionPill {
                        Layout.fillWidth: true
                        label: "CANCELAR"
                        iconGlyph: "󰅖"
                        uiScale: root.scale
                        uiFont: root.font
                        accentColor: root.accentColor
                        onAccentFg: root.onAccentFg
                        fgColor: root.cText
                        onClicked: root.showingAuth = false
                    }
                    ActionPill {
                        Layout.fillWidth: true
                        label: "CONECTAR"
                        iconGlyph: "󰖩"
                        uiScale: root.scale
                        uiFont: root.font
                        accentColor: root.accentColor
                        onAccentFg: root.onAccentFg
                        fgColor: root.cText
                        primary: true
                        onClicked: {
                            connectProc.command = ["nmcli", "device", "wifi", "connect", root.selectedSsid, "password", root.password]
                            connectProc.running = true
                            root.showingAuth = false
                        }
                    }
                }
            }
        }

        // 2. Sudo Auth Modal
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.7
            height: parent.height * 0.5
            color: "transparent"
            visible: root.showingSudoAuth
            onVisibleChanged: if (visible) sudoPassField.forceActiveFocus()

            ColumnLayout {
                anchors.centerIn: parent; spacing: 20 * root.scale; width: parent.width
                Text {
                    text: "SUDO AUTHENTICATION"
                    font.family: root.font; font.pixelSize: 22 * root.scale; font.bold: true; color: root.cText; horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
                Text {
                    text: "Introduce tu contraseña para ver la clave de la red"
                    font.family: root.font; font.pixelSize: 12 * root.scale; color: root.cSub; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true
                }
                TextField {
                    id: sudoPassField; Layout.fillWidth: true; placeholderText: "Sudo password..."; echoMode: TextInput.Password; font.family: root.font; color: root.cText
                    focus: true
                    background: Rectangle { radius: 12 * root.scale; color: root.cBg; border.color: root.accentColor }
                    onTextChanged: root.sudoPassword = text
                    onAccepted: {
                        getPassProc.running = true
                        root.showingSudoAuth = false
                    }
                }
                RowLayout {
                    spacing: 12 * root.scale
                    Layout.fillWidth: true
                    ActionPill {
                        Layout.fillWidth: true
                        label: "CANCELAR"
                        iconGlyph: "󰅖"
                        uiScale: root.scale
                        uiFont: root.font
                        accentColor: root.accentColor
                        onAccentFg: root.onAccentFg
                        fgColor: root.cText
                        onClicked: root.showingSudoAuth = false
                    }
                    ActionPill {
                        Layout.fillWidth: true
                        label: "VERIFICAR"
                        iconGlyph: "󰌆"
                        uiScale: root.scale
                        uiFont: root.font
                        accentColor: root.accentColor
                        onAccentFg: root.onAccentFg
                        fgColor: root.cText
                        primary: true
                        onClicked: {
                            getPassProc.running = true
                            root.showingSudoAuth = false
                        }
                    }
                }
            }
        }

        // 3. WiFi Password Display Modal
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.7
            height: parent.height * 0.5
            color: "transparent"
            visible: root.showingWifiPass

            // Close button (X)
            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: -10 * root.scale; anchors.rightMargin: -10 * root.scale
                width: 32 * root.scale; height: 32 * root.scale; radius: 16 * root.scale
                color: root.cSurface; border.color: root.accentColor; border.width: 1
                z: 100

                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    font.family: root.font; font.pixelSize: 16 * root.scale; color: root.cText
                }

                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.showingWifiPass = false
                }
            }

            ColumnLayout {
                anchors.centerIn: parent; spacing: 20 * root.scale; width: parent.width
                Text {
                    text: "CONTRASEÑA WIFI"
                    font.family: root.font; font.pixelSize: 22 * root.scale; font.bold: true; color: root.cText; horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
                Text {
                    text: root.ssid
                    font.family: root.font; font.pixelSize: 14 * root.scale; color: root.accentColor; horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
                Rectangle {
                    Layout.fillWidth: true; height: 50 * root.scale; radius: 12 * root.scale; color: root.cBg; border.color: root.accentColor
                    Text {
                        anchors.centerIn: parent
                        text: root.retrievedWifiPass
                        font.family: root.font; font.pixelSize: 16 * root.scale; color: root.cText; font.bold: true
                    }
                }
                ActionPill {
                    Layout.fillWidth: true
                    label: "CERRAR"
                    iconGlyph: "󰅖"
                    uiScale: root.scale
                    uiFont: root.font
                    accentColor: root.accentColor
                    onAccentFg: root.onAccentFg
                    fgColor: root.cText
                    primary: true
                    onClicked: root.showingWifiPass = false
                }
            }
        }
    }
}
