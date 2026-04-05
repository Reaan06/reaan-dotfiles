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
    // Formato de ~/.cache/qs-palette:
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
    property string sDistro:  ""
    property string sKbLang:  "EN"

    readonly property var player: Mpris.players.count > 0 ? Mpris.players.values[0] : null

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

    // Distro (una sola vez)
    Process {
        id: distroProc
        command: ["sh", "-c", "grep '^ID=' /etc/os-release | cut -d= -f2"]
        stdout: StdioCollector { onStreamFinished: { root.sDistro = text.trim() } }
    }
    Component.onCompleted: { distroProc.running = true; paletteProc.running = true }

    // Lector de paleta dinámica (generada por wallpaper-picker.sh)
    Process {
        id: paletteProc
        command: ["sh", "-c", "cat $HOME/.cache/qs-palette 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { root.parsePalette(text.trim()) } }
    }
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

    // Acciones one-shot
    Process { id: aRofi;   command: ["rofi", "-show", "drun"] }
    Process { id: aPower;  command: ["sh", "-c", "~/.config/scripts/powermenu.sh"] }
    Process { id: aPavu;   command: ["pavucontrol"] }
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
    function distroIcon() {
        if (sDistro === "arch") return "\uf303"
        if (sDistro === "ubuntu") return "\uf31b"
        if (sDistro === "fedora") return "\uf30a"
        if (sDistro === "debian") return "\uf306"
        if (sDistro === "manjaro") return "\uf312"
        if (sDistro === "endeavouros") return "\uf322"
        return "\uf17c"
    }
    function truncate(str, max) {
        return str.length > max ? str.substring(0, max - 1) + "…" : str
    }

    // Parsea la paleta dinámica desde el archivo de cache
    // Formato: "#hex1 #hex2 #hex3 #hex4 #hex5 #hex6 #hex7 #hex8"
    //           pill  acc1   acc2   acc3   acc4   acc5   text   sub
    property string _lastPalette: ""
    function parsePalette(raw) {
        if (raw.length === 0 || raw === _lastPalette) return
        var parts = raw.split(" ")
        if (parts.length < 8) return
        _lastPalette = raw
        // pill bg con alpha para transparencia
        var pc = parts[0]
        cPill  = Qt.rgba(parseInt(pc.substr(1,2),16)/255,
                         parseInt(pc.substr(3,2),16)/255,
                         parseInt(pc.substr(5,2),16)/255, 0.92)
        cHover = Qt.rgba(parseInt(pc.substr(1,2),16)/255 + 0.06,
                         parseInt(pc.substr(3,2),16)/255 + 0.06,
                         parseInt(pc.substr(5,2),16)/255 + 0.06, 0.95)
        cTeal   = parts[1]
        cGreen  = parts[2]
        cMauve  = parts[3]
        cYellow = parts[4]
        cRed    = parts[5]
        cText   = parts[6]
        cSub    = parts[7]
        // Derivar azul y peach del accent más saturado
        cBlue   = parts[1]
        cPeach  = parts[4]
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
            pillColor: root.cPill; hoverColor: root.cHover; hPad: 12
            onClicked: aRofi.running = true
            Text {
                text: root.distroIcon()
                font.family: root.font; font.pixelSize: 20
                color: "#89b4fa"
            }
        }

        // ──────── 2. WORKSPACES ────────
        Pill {
            pillColor: root.cPill; hoverEnabled: false; hPad: 6
            Row {
                spacing: 3
                Repeater {
                    model: 7
                    Rectangle {
                        required property int index
                        width: 26; height: 24; radius: 8
                        color: Hyprland.focusedWorkspace
                               && Hyprland.focusedWorkspace.id === (index + 1)
                               ? Qt.rgba(0.58, 0.89, 0.84, 0.30) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: (parent.index + 1).toString()
                            font.family: root.font; font.pixelSize: 11; font.bold: true
                            color: Hyprland.focusedWorkspace
                                   && Hyprland.focusedWorkspace.id === (parent.index + 1)
                                   ? root.cTeal : root.cSub
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: Hyprland.dispatch("workspace " + (parent.index + 1))
                        }
                    }
                }
            }
        }

        // ──────── 3. MPRIS — art + artista - título + controles ────────
        Pill {
            visible: root.player !== null
            pillColor: root.cPill; hoverColor: root.cHover; hPad: 8

            // Carátula del álbum (cuadrada, redondeada)
            Rectangle {
                width: 28; height: 28; radius: 6
                color: Qt.rgba(1,1,1,0.05)
                clip: true
                Image {
                    anchors.fill: parent
                    source: root.player ? root.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }
                // Fallback: icono de música si no hay carátula
                Text {
                    anchors.centerIn: parent
                    text: "󰎆"
                    font.family: root.font; font.pixelSize: 14; color: root.cGreen
                    visible: root.player ? root.player.trackArtUrl === "" : true
                }
            }

            // Artista - Título
            Text {
                text: {
                    if (!root.player) return ""
                    var a = root.player.trackArtist || ""
                    var t = root.player.trackTitle || ""
                    var full = a.length > 0 ? a + " - " + t : t
                    return root.truncate(full, 25)
                }
                font.family: root.font; font.pixelSize: 11; color: root.cText
            }

            Rectangle { width: 1; height: 14; color: Qt.rgba(1,1,1,0.08) }

            // Controles de transporte
            Text {
                text: "󰒮"
                font.family: root.font; font.pixelSize: 14; color: root.cSub
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { if (root.player) root.player.previous() }
                }
            }
            Text {
                text: root.player && root.player.isPlaying ? "󰏦" : "󰐍"
                font.family: root.font; font.pixelSize: 16; color: root.cTeal
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { if (root.player) root.player.togglePlaying() }
                }
            }
            Text {
                text: "󰒭"
                font.family: root.font; font.pixelSize: 14; color: root.cSub
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { if (root.player) root.player.next() }
                }
            }

            Rectangle { width: 1; height: 14; color: Qt.rgba(1,1,1,0.08) }

            // Posición / Duración
            Text {
                text: {
                    if (!root.player || !root.player.lengthSupported) return ""
                    return root.fmtTime(root.player.position) + " / " + root.fmtTime(root.player.length)
                }
                font.family: root.font; font.pixelSize: 10; color: root.cSub
            }
        }

        Item { Layout.fillWidth: true }

        // ──────── 4. RELOJ + FECHA + CLIMA (una sola caja) ────────
        Pill {
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

                // — WiFi —
                Item {
                    width: wifiContent.implicitWidth + 16; height: 36
                    Row {
                        id: wifiContent; anchors.centerIn: parent; spacing: 4
                        Text {
                            text: root.sNet.length > 0 ? "󰖩" : "󰖪"
                            font.family: root.font; font.pixelSize: 14
                            color: root.sNet.length > 0 ? root.cGreen : root.cSub
                        }
                        Text {
                            visible: root.sNet.length > 0
                            text: root.truncate(root.sNet, 12)
                            font.family: root.font; font.pixelSize: 11; color: root.cGreen
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: aNmEdit.running = true
                    }
                }
                Rectangle { width: 1; height: 14; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(1,1,1,0.08) }

                // — Bluetooth —
                Item {
                    width: btContent.implicitWidth + 16; height: 36
                    Row {
                        id: btContent; anchors.centerIn: parent; spacing: 4
                        Text {
                            text: root.sBt.length > 0 ? "󰂱" : "󰂲"
                            font.family: root.font; font.pixelSize: 14
                            color: root.sBt.length > 0 ? root.cBlue : root.cSub
                        }
                        Text {
                            visible: root.sBt.length > 0
                            text: root.truncate(root.sBt, 12)
                            font.family: root.font; font.pixelSize: 11; color: root.cBlue
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: aBtMan.running = true
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
                Rectangle { width: 1; height: 14; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(1,1,1,0.08) }

                // — Brillo —
                Item {
                    width: briContent.implicitWidth + 12; height: 36
                    Row {
                        id: briContent; anchors.centerIn: parent; spacing: 4
                        Text {
                            text: root.sBri > 70 ? "󰃠" : root.sBri > 30 ? "󰃟" : "󰃞"
                            font.family: root.font; font.pixelSize: 14
                            color: root.cPeach
                        }
                        Text {
                            text: root.sBri + "%"
                            font.family: root.font; font.pixelSize: 11
                            color: root.cPeach
                        }
                    }
                }
                Rectangle { width: 1; height: 14; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(1,1,1,0.08) }

                // — Volumen —
                Item {
                    width: volContent.implicitWidth + 12; height: 36
                    Row {
                        id: volContent; anchors.centerIn: parent; spacing: 4
                        Text {
                            text: root.sMute ? "󰝟" : "󰕾"
                            font.family: root.font; font.pixelSize: 14
                            color: root.sMute ? root.cSub : root.cYellow
                        }
                        Text {
                            text: root.sVol.toString()
                            font.family: root.font; font.pixelSize: 11
                            color: root.sMute ? root.cSub : root.cYellow
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: aPavu.running = true
                        onWheel: function(w) { if (w.angleDelta.y > 0) aVolUp.running = true; else aVolDn.running = true }
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
