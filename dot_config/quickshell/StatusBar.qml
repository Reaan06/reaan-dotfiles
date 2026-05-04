import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import "components"

Item {
    id: root

    // ═══════════════════════════════════════════════
    // PALETA — Dinámica (se actualiza con el wallpaper)
    // Formato de ~/.config/quickshell/.palette:
    //   pill accent1 accent2 accent3 accent4 accent5 text sub
    // ═══════════════════════════════════════════════
    property color cPill:    Qt.rgba(0.16, 0.16, 0.18, 0.92)
    property color cHover:   Qt.rgba(0.22, 0.22, 0.25, 0.95)
    property color cText:    "#c8cad0"
    property color cSub:     "#5a5a64"
    property color cTeal:    "#8a9a9e"
    property color cGreen:   "#7a8e85"
    property color cMauve:   "#9490a0"
    property color cYellow:  "#a09882"
    property color cRed:     "#8a7e7a"
    property color cBlue:    "#8a9a9e"
    property color cPeach:   "#a09882"
    readonly property string font:    "JetBrains Mono Nerd Font"

    // ═══════════════════════════════════════════════
    // ESTADO DEL SISTEMA
    // ═══════════════════════════════════════════════
    property string sTime:    ""
    property string sDate:    ""
    property int    sBat:     0
    property bool   sChg:     false
    property string sNet:     ""
    property string sBt:      ""
    property int    sVol:     0
    property bool   sMute:    false
    property int    sBri:     0
    property string sWeather: ""

    property string sKbLang:  "EN"

    // Global coordinate helpers for panel alignment
    readonly property real mprisCenterWorldX: getCenterWorldX(mprisAnchor)
    readonly property real clockCenterWorldX: getCenterWorldX(clockAnchor)

    // Notify shellRoot about our coordinates
    onMprisCenterWorldXChanged: updateAnchors()
    onClockCenterWorldXChanged: updateAnchors()

    function updateAnchors() {
        if (!parent || !parent.screen) return
        var idx = parent.screen.index
        var data = shellRoot.anchors
        data[idx] = { mpris: mprisCenterWorldX, clock: clockCenterWorldX }
        shellRoot.anchors = data // Trigger update
    }

    Component.onCompleted: updateAnchors()

    function getCenterWorldX(item) {
        if (!item) return 0
        // Map center of the item to global window coordinates
        var p = item.mapToItem(null, item.width / 2, 0)
        return p.x
    }

    // MPRIS state via playerctl
    property string mpTitle: ""
    property string mpArtist: ""
    property string mpArtUrl: ""
    property bool   mpPlaying: false
    property int    mpPos: 0
    property int    mpLen: 0
    property bool   mpActive: false
    property string _mpPrevTitle: ""
    property real   mpInfoOpacity: 1.0

    // Live position ticker — increments every second while playing
    Timer {
        interval: 1000; running: root.mpPlaying && root.mpActive; repeat: true
        onTriggered: { if (root.mpPos < root.mpLen) root.mpPos++ }
    }

    // ═══════════════════════════════════════════════
    // PROCESOS DE ESTADO
    // ═══════════════════════════════════════════════

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var n = new Date()
            root.sTime = Qt.formatDateTime(n, "hh:mm:ss AP")
            root.sDate = Qt.formatDateTime(n, "dddd, MMMM d")
        }
    }

    // Palette (una sola vez)
    Process {
        id: paletteProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/.palette 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { root.parsePalette(text.trim()) } }
    }
    Component.onCompleted: { paletteProc.running = true }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: paletteProc.running = true }

    // Layout de teclado actual
    Process {
        id: kbProc
        command: ["sh", "-c", "hyprctl devices -j 2>/dev/null | grep -oP '\"active_keymap\": \"\\K[^\"]+' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var layout = text.trim().toLowerCase()
                root.sKbLang = layout.indexOf("spanish") >= 0 ? "ES" : "EN"
            }
        }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: kbProc.running = true }

    // Acción: cambiar layout de teclado
    Process { id: aKbSwitch; command: ["hyprctl", "switchxkblayout", "all", "next"] }

    // Batería
    Process {
        id: batProc
        command: ["sh", "-c", "echo $(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1) $(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1)"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split(" ")
                if (p.length >= 1) root.sBat = parseInt(p[0]) || 0
                if (p.length >= 2) root.sChg = (p[1] === "Charging" || p[1] === "Full")
            }
        }
    }
    Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true; onTriggered: batProc.running = true }

    // Red WiFi
    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f ACTIVE,NAME connection show --active 2>/dev/null | grep '^yes' | cut -d: -f2 | head -1"]
        stdout: StdioCollector { onStreamFinished: { root.sNet = text.trim() } }
    }
    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: netProc.running = true }

    // Bluetooth
    Process {
        id: btProc
        command: ["sh", "-c", "bluetoothctl devices Connected 2>/dev/null | head -1 | cut -d' ' -f3-"]
        stdout: StdioCollector { onStreamFinished: { root.sBt = text.trim() } }
    }
    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: btProc.running = true }

    // Volumen (polling rápido 500ms para sincronizar con F-keys)
    Process {
        id: volProc
        command: ["sh", "-c", "echo $(pamixer --get-volume 2>/dev/null) $(pamixer --get-mute 2>/dev/null)"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split(" ")
                if (p.length >= 1) root.sVol = parseInt(p[0]) || 0
                if (p.length >= 2) root.sMute = (p[1] === "true")
            }
        }
    }
    Timer { interval: 500; running: true; repeat: true; triggeredOnStart: true; onTriggered: volProc.running = true }

    // Brillo (polling rápido 500ms para sincronizar con F-keys)
    Process {
        id: briProc
        command: ["sh", "-c", "brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'"]
        stdout: StdioCollector {
            onStreamFinished: { root.sBri = parseInt(text.trim()) || 0 }
        }
    }
    Timer { interval: 500; running: true; repeat: true; triggeredOnStart: true; onTriggered: briProc.running = true }

    // Clima
    Process {
        id: weatherProc
        command: ["sh", "-c", "curl -sf 'wttr.in/?format=%c+%t' 2>/dev/null | sed 's/+//g' | xargs"]
        stdout: StdioCollector { onStreamFinished: { root.sWeather = text.trim() } }
    }
    Timer { interval: 900000; running: true; repeat: true; triggeredOnStart: true; onTriggered: weatherProc.running = true }

    // MPRIS — read output from mpris-follow.sh (started globally in shell.qml)
    Process {
        id: mprisProc
        command: ["sh", "-c", "cat ${XDG_RUNTIME_DIR:-/tmp}/qs-mpris 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n")
                if (lines.length >= 2 && lines[0] !== "Stopped" && lines[0] !== "") {
                    root.mpActive = true
                    root.mpPlaying = (lines[0] === "Playing")
                    var newTitle = lines.length > 1 ? lines[1] : ""
                    var newArtist = lines.length > 2 ? lines[2] : ""
                    var newArtUrl = lines.length > 3 ? lines[3] : ""
                    var pos = lines.length > 4 ? parseInt(lines[4]) : 0
                    var len = lines.length > 5 ? parseInt(lines[5]) : 0
                    pos = isNaN(pos) ? 0 : pos
                    len = isNaN(len) ? 0 : len

                    // Detect song change → trigger fade animation
                    if (newTitle !== root.mpTitle || newArtist !== root.mpArtist) {
                        root.mpInfoOpacity = 0.0
                        root._mpPrevTitle = root.mpTitle
                        root.mpTitle = newTitle
                        root.mpArtist = newArtist
                        root.mpArtUrl = newArtUrl
                        root.mpPos = pos
                        root.mpLen = len
                        mpFadeIn.start()
                    } else {
                        // Sync position only if drift > 3s (let local timer handle ticking)
                        if (Math.abs(pos - root.mpPos) > 3) root.mpPos = pos
                        root.mpLen = len
                    }
                } else {
                    root.mpActive = false
                }
            }
        }
    }
    Timer { interval: 250; running: true; repeat: true; triggeredOnStart: true; onTriggered: mprisProc.running = true }

    // Fade-in animation for song changes
    SequentialAnimation {
        id: mpFadeIn
        PauseAnimation { duration: 50 }
        NumberAnimation { target: root; property: "mpInfoOpacity"; to: 1.0; duration: 300; easing.type: Easing.OutCubic }
    }

    // Acciones one-shot
    Process { id: aRofi;   command: ["rofi", "-show", "drun"] }
    Process { id: aPower;  command: ["sh", "-c", "~/.config/scripts/powermenu.sh"] }
    Process { id: aPavu;   command: ["pavucontrol"] }
    Process { id: aMpNext;  command: ["sh", "-c", "~/.config/scripts/mp-next.sh"] }
    Process { id: aMpPrev;  command: ["sh", "-c", "~/.config/scripts/mp-prev.sh"] }
    Process { id: aMpToggle; command: ["sh", "-c", "~/.config/scripts/mp-toggle.sh"] }
    Process { id: aBtMan;  command: ["blueman-manager"] }
    Process { id: aNmEdit; command: ["nm-connection-editor"] }
    Process { id: aVolUp;  command: ["pamixer", "-i", "5"] }
    Process { id: aVolDn;  command: ["pamixer", "-d", "5"] }

    // ═══════════════════════════════════════════════
    // FUNCIONES AUXILIARES
    // ═══════════════════════════════════════════════
    function batIcon() {
        if (sChg) return "󰂄"
        if (sBat > 90) return "󰁹"; if (sBat > 70) return "󰂂"
        if (sBat > 50) return "󰁾"; if (sBat > 30) return "󰁼"
        if (sBat > 10) return "󰁺"; return "󰂎"
    }
    function batColor() {
        if (sChg) return cGreen
        if (sBat <= 15) return cRed; if (sBat <= 30) return cYellow
        return cGreen
    }
    function fmtTime(secs) {
        var s = Math.floor(secs)
        var m = Math.floor(s / 60)
        var r = s % 60
        return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r
    }

    function truncate(str, max) {
        return str.length > max ? str.substring(0, max - 1) + "…" : str
    }

    // Parsea la paleta dinámica desde el archivo de cache
    // Formato: "#hex1 #hex2 #hex3 #hex4 #hex5 #hex6 #hex7 #hex8"
    //           pill  acc1   acc2   acc3   acc4   acc5   text   sub
    property string _lastPalette: ""
    function parsePalette(raw) {
        if (!raw || raw.length === 0 || raw === _lastPalette) return
        var parts = raw.split(" ")
        if (parts.length < 8) return
        _lastPalette = raw
        try {
            var pc = parts[0]
            if (pc && pc.startsWith("#") && pc.length >= 7) {
                cPill  = Qt.rgba(parseInt(pc.substr(1,2),16)/255,
                                 parseInt(pc.substr(3,2),16)/255,
                                 parseInt(pc.substr(5,2),16)/255, 0.92)
                cHover = Qt.rgba(parseInt(pc.substr(1,2),16)/255 + 0.06,
                                 parseInt(pc.substr(3,2),16)/255 + 0.06,
                                 parseInt(pc.substr(5,2),16)/255 + 0.06, 0.95)
            }
            cTeal   = parts[1] || cTeal
            cGreen  = parts[2] || cGreen
            cMauve  = parts[3] || cMauve
            cYellow = parts[4] || cYellow
            cRed    = parts[5] || cRed
            cText   = parts[6] || cText
            cSub    = parts[7] || cSub
            cBlue   = parts[1] || cBlue
            cPeach  = parts[4] || cPeach
        } catch (e) {
            console.log("Error parsing palette: " + e)
        }
    }

    // ═══════════════════════════════════════════════
    // LAYOUT — SIN fondo de barra, pills flotantes
    // ═══════════════════════════════════════════════
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 8

        // ──────── 1. LOGO DISTRO (color fijo) ────────
        Pill {
            pillColor: root.cPill; hoverColor: root.cHover
            hPad: 18; vPad: 14
            onClicked: aRofi.running = true
            Text {
                text: "\uf17c"
                font.family: root.font; font.pixelSize: 24
                color: "#ffffff"
            }
        }

        // ──────── 2. WORKSPACES (grupos por monitor, estilo Caelestia) ────────
        Pill {
            pillColor: root.cPill; hoverEnabled: false; hPad: 6
            Row {
                spacing: 3
                Repeater {
                    model: 7
                    Rectangle {
                        required property int index
                        property int wsNum: index + 1
                        // Detectar si este WS está activo usando módulo 10
                        property bool isActive: Hyprland.focusedWorkspace
                            && ((Hyprland.focusedWorkspace.id - 1) % 10 + 1) === wsNum
                        width: 26; height: 24; radius: 8
                        color: isActive ? Qt.rgba(0.58, 0.89, 0.84, 0.30) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: parent.wsNum.toString()
                            font.family: root.font; font.pixelSize: 11; font.bold: true
                            color: parent.isActive ? root.cTeal : root.cSub
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // Calcular grupo del monitor actual
                                var active = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
                                var group = Math.floor((active - 1) / 10) * 10
                                Hyprland.dispatch("workspace " + (group + parent.wsNum))
                            }
                        }
                    }
                }
            }
        }

        // ──────── 3. MPRIS — art | info(2 líneas) | controles ────────
        Pill {
            id: mprisAnchor
            visible: root.mpActive
            pillColor: root.cPill; hoverColor: root.cHover; hPad: 18

            onScrolledUp: aMpNext.running = true
            onScrolledDown: aMpPrev.running = true
            onClicked: aMpToggle.running = true

            // Grupo Logo + Texto centrado
            Row {
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter

                // Carátula del álbum
                Rectangle {
                    width: 26; height: 26; radius: 6
                    color: Qt.rgba(1,1,1,0.05)
                    clip: true
                    opacity: root.mpInfoOpacity
                    Image {
                        anchors.fill: parent
                        source: root.mpArtUrl
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                        Behavior on source { PropertyAnimation { duration: 0 } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "󰎆"
                        font.family: root.font; font.pixelSize: 13; color: root.cGreen
                        visible: root.mpArtUrl.length === 0
                    }
                }

                // Info: título arriba, duración abajo
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    opacity: root.mpInfoOpacity
                    Text {
                        id: mpTitleText
                        text: {
                            var a = root.mpArtist
                            var t = root.mpTitle
                            var full = a.length > 0 ? a + " - " + t : t
                            return root.truncate(full, 28)
                        }
                        font.family: root.font; font.pixelSize: 10; color: root.cText
                    }
                    Text {
                        visible: root.mpLen > 0
                        text: root.fmtTime(root.mpPos) + " / " + root.fmtTime(root.mpLen)
                        font.family: root.font; font.pixelSize: 9; color: root.cSub
                    }
                }
            }

            Item { width: 4 }
            Rectangle {
                width: 1; height: 35; color: Qt.rgba(1,1,1,0.08)
                anchors.bottom: parent.bottom
            }

            // Controles centrados
            Row {
                spacing: 0
                Rectangle {
                    width: 24; height: 36; radius: 9
                    color: hoverAreaPrev.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        font.family: root.font; font.pixelSize: 16; color: root.cSub
                    }
                    MouseArea {
                        id: hoverAreaPrev
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: aMpPrev.running = true
                    }
                }
                Rectangle {
                    width: 32; height: 36; radius: 9
                    color: hoverAreaPlay.containsMouse ? Qt.rgba(0.58, 0.89, 0.84, 0.2) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        anchors.centerIn: parent
                        text: root.mpPlaying ? "󰏦" : "󰐍"
                        font.family: root.font; font.pixelSize: 21; color: root.cTeal
                    }
                    MouseArea {
                        id: hoverAreaPlay
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: aMpToggle.running = true
                    }
                }
                Rectangle {
                    width: 24; height: 36; radius: 9
                    color: hoverAreaNext.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        font.family: root.font; font.pixelSize: 16; color: root.cSub
                    }
                    MouseArea {
                        id: hoverAreaNext
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: aMpNext.running = true
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }

        // ──────── 4. RELOJ + FECHA + CLIMA (una sola caja) ────────
        Pill {
            id: clockAnchor
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            pillColor: root.cPill; hPad: 16

            Text {
                text: root.sTime
                font.family: root.font; font.pixelSize: 13; font.weight: Font.DemiBold
                color: root.cTeal
            }
            Rectangle { width: 1; height: 14; color: Qt.rgba(1,1,1,0.08) }
            Text {
                text: root.sDate
                font.family: root.font; font.pixelSize: 11
                color: root.cSub
            }
            Rectangle { width: 1; height: 14; color: Qt.rgba(1,1,1,0.08); visible: root.sWeather.length > 0 }
            Text {
                visible: root.sWeather.length > 0
                text: root.sWeather
                font.family: root.font; font.pixelSize: 11; color: root.cYellow
            }
        }

        Item { Layout.fillWidth: true }

        // ──────── 5. CAJA UNIFICADA DERECHA ────────
        // Tray + Teclado + WiFi + Bluetooth + Batería + Volumen
        // Todo en un solo Rectangle con separadores internos
        Rectangle {
            height: 36; radius: 12; color: root.cPill
            implicitWidth: sysRow.implicitWidth + 16

            Row {
                id: sysRow
                anchors.centerIn: parent
                spacing: 0

                // — System Tray (iconos de apps en segundo plano) —
                Repeater {
                    model: SystemTray.items
                    Item {
                        required property var modelData
                        width: 30; height: 36
                        Image {
                            anchors.centerIn: parent
                            width: 16; height: 16
                            source: modelData.icon
                            sourceSize.width: 16; sourceSize.height: 16
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.LeftButton) modelData.activate()
                                else modelData.secondaryActivate()
                            }
                        }
                    }
                }

                // Separador tras tray
                Rectangle { width: 1; height: 14; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(1,1,1,0.08) }

                // — Teclado (click para alternar ES/EN) —
                Item {
                    width: 42; height: 36
                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Text { text: "󰌌"; font.family: root.font; font.pixelSize: 12; color: root.cTeal }
                        Text { text: root.sKbLang; font.family: root.font; font.pixelSize: 11; font.bold: true; color: root.cTeal }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: aKbSwitch.running = true
                    }
                }
                Rectangle { width: 1; height: 14; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(1,1,1,0.08) }

                // — WiFi (icon only) —
                Item {
                    width: 30; height: 36
                    Text {
                        anchors.centerIn: parent
                        text: root.sNet.length > 0 ? "󰖩" : "󰖪"
                        font.family: root.font; font.pixelSize: 14
                        color: root.sNet.length > 0 ? root.cGreen : root.cSub
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: aNmEdit.running = true
                    }
                }
                Rectangle { width: 1; height: 14; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(1,1,1,0.08) }

                // — Bluetooth (icon only) —
                Item {
                    width: 30; height: 36
                    Text {
                        anchors.centerIn: parent
                        text: root.sBt.length > 0 ? "󰂱" : "󰂲"
                        font.family: root.font; font.pixelSize: 14
                        color: root.sBt.length > 0 ? root.cBlue : root.cSub
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: aBtMan.running = true
                    }
                }
                Rectangle { width: 1; height: 14; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(1,1,1,0.08) }

                // — Volumen (Anclaje para Super+F1) —
                Item {
                    id: audioAnchor
                    width: volContent.implicitWidth + 12; height: 36
                    Row {
                        id: volContent; anchors.centerIn: parent; spacing: 4
                        Text {
                            text: root.sMute ? "󰝟" : (root.sVol > 50 ? "󰕾" : (root.sVol > 0 ? "󰖀" : "󰕿"))
                            font.family: root.font; font.pixelSize: 14; color: root.cMauve
                        }
                        Text { text: root.sVol + "%"; font.family: root.font; font.pixelSize: 11; color: root.cText }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: aPavu.running = true
                    }
                }
                Rectangle { width: 1; height: 14; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(1,1,1,0.08) }

                // — Batería —
                Item {
                    width: batContent.implicitWidth + 12; height: 36
                    Row {
                        id: batContent; anchors.centerIn: parent; spacing: 4
                        Text { text: root.batIcon(); font.family: root.font; font.pixelSize: 14; color: root.batColor() }
                        Text { text: root.sBat + "%"; font.family: root.font; font.pixelSize: 11; color: root.batColor() }
                    }
                }
            }
        }

        // ──────── 6. POWER (pill separada) ────────
        Pill {
            pillColor: root.cPill; hoverColor: Qt.rgba(0.95, 0.55, 0.66, 0.15); hPad: 10
            onClicked: aPower.running = true
            Text { text: "⏻"; font.family: root.font; font.pixelSize: 14; color: root.cRed }
        }
    }
}
