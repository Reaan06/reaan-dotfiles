import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "components"

Item {
    id: root

    property bool active: false
    property real neckOffset: 0
    property real anchorWidth: 200
    readonly property string font: "JetBrains Mono Nerd Font"
    
    // ═══════════════════════════════════════════════
    // THEME — 100% Dinámico del Wallpaper
    // ═══════════════════════════════════════════════
    property color cPill:   "#1e1e2e"
    property color cMauve:  "#cba6f7"
    property color cBlue:   "#89b4fa"
    property color cGreen:  "#a6e3a1"
    property color cRed:    "#f38ba8"
    property color cText:   "#cdd6f4"
    property color cSub:    "#6c7086"

    // Animaciones agresivas para que el cambio se note
    Behavior on cPill  { ColorAnimation { duration: 600 } }
    Behavior on cMauve { ColorAnimation { duration: 600 } }
    Behavior on cBlue  { ColorAnimation { duration: 600 } }
    Behavior on cGreen { ColorAnimation { duration: 600 } }
    Behavior on cRed   { ColorAnimation { duration: 600 } }
    Behavior on cText  { ColorAnimation { duration: 600 } }
    Behavior on cSub   { ColorAnimation { duration: 600 } }

    function parsePalette(raw) {
        if (!raw || raw.length === 0) return
        var parts = raw.split(" ")
        if (parts.length < 8) return
        try {
            var pc = parts[0]
            if (pc && pc.startsWith("#") && pc.length >= 7) {
                cPill  = Qt.rgba(parseInt(pc.substr(1,2),16)/255,
                                 parseInt(pc.substr(3,2),16)/255,
                                 parseInt(pc.substr(5,2),16)/255, 0.92)
            }
            cBlue  = parts[1] || cBlue
            cGreen = parts[2] || cGreen
            cMauve = parts[3] || cMauve
            cRed   = parts[5] || cRed
            cText  = parts[6] || cText
            cSub   = parts[7] || cSub
        } catch (e) {
            console.log("Error parsing palette in AudioManager: " + e)
        }
    }

    Process {
        id: paletteProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/.palette 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { root.parsePalette(text.trim()) } }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: paletteProc.running = true }

    // Metadata state
    property string mpTitle: "No Media"; property string mpArtist: ""; property string mpArtUrl: ""
    property bool mpPlaying: false; property int mpPos: 0; property int mpLen: 0
    property string mpSource: "System"; property string btDevice: "Built-in Audio"
    property var eqBands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]; property string activePreset: "Flat"

    // ── DATA SYNC ──
    Process {
        id: mprisProc; command: ["sh", "-c", "cat ${XDG_RUNTIME_DIR:-/tmp}/qs-mpris 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n")
                if (lines.length >= 7 && lines[0] !== "Stopped" && lines[0] !== "") {
                    root.mpPlaying = (lines[0] === "Playing"); root.mpTitle = lines[1]; root.mpArtist = lines[2]
                    root.mpArtUrl = lines[3]; root.mpPos = parseInt(lines[4]) || 0; root.mpLen = parseInt(lines[5]) || 0
                    var rawSource = lines[6].toLowerCase()
                    if (rawSource.indexOf("spotify") !== -1) root.mpSource = "Spotify"
                    else if (rawSource.indexOf("firefox") !== -1) root.mpSource = "YouTube/Browser"
                    else root.mpSource = rawSource.charAt(0).toUpperCase() + rawSource.slice(1)
                } else { root.mpTitle = "No Media"; root.mpArtist = ""; root.mpPlaying = false; root.mpSource = "System" }
            }
        }
    }
    Timer { interval: 500; running: true; repeat: true; onTriggered: mprisProc.running = true }

    Process {
        id: btProc; command: ["sh", "-c", "bluetoothctl devices Connected 2>/dev/null | head -1 | cut -d' ' -f3-"]
        stdout: StdioCollector { onStreamFinished: { var dev = text.trim(); root.btDevice = dev.length > 0 ? dev : "System Output" } }
    }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: btProc.running = true }

    function togglePlay() { mProc.command = ["playerctl", "play-pause"]; mProc.running = true }
    function nextTrack() { mProc.command = ["playerctl", "next"]; mProc.running = true }
    function prevTrack() { mProc.command = ["playerctl", "previous"]; mProc.running = true }
    function setPreset(p) { 
        root.activePreset = p; mProc.command = ["sh", "-c", "~/.config/scripts/eq-control.sh set-preset " + p]; mProc.running = true
        var nb = [0,0,0,0,0,0,0,0,0,0]
        if (p === "Bass") nb = [12, 10, 6, 2, 0, -2, -4, -6, -8, -10]
        else if (p === "Treble") nb = [-8, -6, -4, -2, 0, 2, 6, 9, 11, 12]
        else if (p === "Rock") nb = [9, 7, 4, -1, -3, -1, 3, 6, 8, 9]
        else if (p === "Pop") nb = [-3, -1, 2, 5, 8, 7, 4, 1, -1, -3]
        else if (p === "Jazz") nb = [7, 5, 3, 5, -1, -1, 2, 4, 6, 7]
        root.eqBands = nb
    }
    Process { id: mProc }

    // ── UI ──
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        opacity: root.active ? 1.0 : 0.0
        scale: root.active ? 1.0 : 0.98
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

        // Conector curvo alineado con el módulo MPRIS (izquierda de la barra)
        PanelConnector {
            Layout.fillWidth: true
            color: root.cPill
            barWidth: root.anchorWidth
            neckOffset: root.neckOffset
        }

        Rectangle {
            id: mainContainer; 
            Layout.fillWidth: true; 
            Layout.fillHeight: true; 
            radius: 36; color: root.cPill
            border.color: Qt.rgba(1,1,1,0.1); border.width: 1

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 32; spacing: 20
                RowLayout {
                    Layout.fillWidth: true; spacing: 28; Layout.alignment: Qt.AlignHCenter
                    Item {
                        width: 140; height: 140
                        Rectangle { anchors.fill: parent; radius: 70; color: "transparent"; border.color: root.cMauve; border.width: 2; opacity: 0.15; scale: 1.15 }
                        Item {
                            id: vinyl; anchors.fill: parent
                            Rectangle { id: maskRect; anchors.fill: parent; radius: 70; visible: false }
                            Image { id: albumArt; anchors.fill: parent; source: root.mpArtUrl; fillMode: Image.PreserveAspectCrop; visible: status === Image.Ready; layer.enabled: true; layer.effect: OpacityMask { maskSource: maskRect } }
                            Rectangle { anchors.centerIn: parent; width: 14; height: 14; radius: 7; color: root.cPill; border.color: Qt.rgba(1,1,1,0.2); border.width: 1; z: 10 }
                            Text { anchors.centerIn: parent; text: "󰎆"; font.family: root.font; font.pixelSize: 45; color: root.cMauve; visible: albumArt.status !== Image.Ready }
                            RotationAnimation on rotation { from: 0; to: 360; duration: 7000; loops: Animation.Infinite; running: root.mpPlaying }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 6; Layout.alignment: Qt.AlignVCenter
                        Text { text: root.mpTitle; font.family: root.font; font.pixelSize: 22; font.bold: true; color: root.cText; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: "BY " + (root.mpArtist || "Unknown Artist"); font.family: root.font; font.pixelSize: 14; color: root.cSub; font.weight: Font.Medium }
                        RowLayout {
                            spacing: 12
                            Rectangle { height: 26; implicitWidth: devTxt.implicitWidth + 24; radius: 13; color: Qt.rgba(1,1,1,0.08)
                                Row { anchors.centerIn: parent; spacing: 6
                                    Text { text: "󰂱"; font.family: root.font; font.pixelSize: 12; color: root.cBlue }
                                    Text { id: devTxt; text: root.btDevice; font.family: root.font; font.pixelSize: 11; color: root.cText }
                                }
                            }
                            Text { text: "VIA " + root.mpSource; font.family: root.font; font.pixelSize: 11; font.bold: true; color: root.cMauve }
                        }
                        Item { Layout.preferredHeight: 12 }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 8
                            Item { Layout.fillWidth: true; Layout.preferredHeight: 10
                                Rectangle { anchors.fill: parent; radius: 5; color: Qt.rgba(0,0,0,0.3) }
                                Rectangle { width: Math.max(12, parent.width * (root.mpLen > 0 ? root.mpPos / root.mpLen : 0)); height: parent.height; radius: 5; color: root.cMauve
                                    Rectangle { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; radius: 7; color: "white"; border.color: root.cMauve; border.width: 1 }
                                }
                            }
                            RowLayout { Layout.fillWidth: true
                                Text { text: root.fmtTime(root.mpPos); font.family: root.font; font.pixelSize: 11; color: root.cSub }
                                Item { Layout.fillWidth: true }
                                Text { text: root.fmtTime(root.mpLen); font.family: root.font; font.pixelSize: 11; color: root.cSub }
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignHCenter; spacing: 48
                    Text { text: "󰒮"; font.family: root.font; font.pixelSize: 32; color: root.cText; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.prevTrack() } }
                    Rectangle {
                        width: 60; height: 60; radius: 20
                        color: Qt.rgba(1,1,1,0.08)
                        Text { anchors.centerIn: parent; text: root.mpPlaying ? "󰏦" : "󰐍"; font.family: root.font; font.pixelSize: 34; color: root.cMauve }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.togglePlay() }
                    }
                    Text { text: "󰒭"; font.family: root.font; font.pixelSize: 32; color: root.cText; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.nextTrack() } }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1,1,1,0.08) }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Equalizer"; font.family: root.font; font.pixelSize: 18; font.bold: true; color: root.cMauve }
                    Item { Layout.fillWidth: true }
                    Text { text: root.activePreset; font.family: root.font; font.pixelSize: 14; font.bold: true; color: root.cText }
                }
                RowLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 14; Layout.alignment: Qt.AlignHCenter
                    Repeater {
                        model: 10
                        ColumnLayout {
                            Layout.fillHeight: true; spacing: 8; Layout.alignment: Qt.AlignHCenter
                            Item { id: barBox; Layout.fillHeight: true; Layout.preferredWidth: 24; Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 8; height: parent.height; radius: 4; color: Qt.rgba(0,0,0,0.3) }
                                Rectangle { width: 8; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; radius: 4; color: root.cMauve; height: parent.height - dot.y - (dot.height / 2) }
                                Rectangle { id: dot; width: 22; height: 22; radius: 11; color: "white"; border.color: root.cMauve; border.width: 1.5; anchors.horizontalCenter: parent.horizontalCenter; y: da.drag.active ? y : (parent.height - 22) * (1.0 - (root.eqBands[index] + 12) / 24); Behavior on y { enabled: !da.drag.active; NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                                    MouseArea { id: da; anchors.fill: parent; drag.target: dot; drag.axis: Drag.YAxis; drag.minimumY: 0; drag.maximumY: barBox.height - 22; onPositionChanged: if (drag.active) { var db = (1.0 - (dot.y / (barBox.height - 22))) * 24 - 12; var nb = root.eqBands.slice(); nb[index] = db; root.eqBands = nb; mProc.command = ["sh", "-c", "~/.config/scripts/eq-control.sh set-band " + index + " " + db]; mProc.running = true } }
                                }
                            }
                            Text { Layout.alignment: Qt.AlignHCenter; text: (root.eqBands[index] >= 0 ? "+" : "") + root.eqBands[index].toFixed(1); font.family: root.font; font.pixelSize: 8; font.bold: true; color: root.eqBands[index] !== 0 ? root.cMauve : root.cSub }
                        }
                    }
                }
                GridLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignHCenter; columns: 4; rowSpacing: 10; columnSpacing: 10
                    Repeater {
                        model: ["Flat", "Bass", "Treble", "Rock", "Pop", "Jazz", "Vocal", "Classic"]
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 36; radius: 12; color: root.activePreset === modelData ? root.cMauve : Qt.rgba(1,1,1,0.06)
                            Text { anchors.centerIn: parent; text: modelData; font.family: root.font; font.pixelSize: 12; font.bold: root.activePreset === modelData; color: root.activePreset === modelData ? "#11111b" : root.cText }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setPreset(modelData) }
                        }
                    }
                }
            }
        }
    }
    function fmtTime(s) { var m = Math.floor(s / 60); var r = s % 60; return m + ":" + (r < 10 ? "0" : "") + r }
}
