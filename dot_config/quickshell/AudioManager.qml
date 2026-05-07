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
    property real scale: 1.0
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
                cPill  = Qt.rgba(parseInt(pc.substr(1,2),16)/255, parseInt(pc.substr(3,2),16)/255, parseInt(pc.substr(5,2),16)/255, 0.92)
            }
            cBlue  = parts[1] || cBlue
            cGreen = parts[2] || cGreen
            cMauve = parts[3] || cMauve
            cRed   = parts[5] || cRed
            cText  = parts[6] || cText
            cSub   = parts[7] || cSub
        } catch (e) {
            console.log("Error parsing palette: " + e)
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
    
    // App Volume state
    property bool showAppVol: false
    property var appsList: []
    property bool draggingVol: false

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

    Process {
        id: appVolProc; command: ["sh", "-c", "~/.config/scripts/app-volume.sh list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.appsList = JSON.parse(text.trim())
                } catch(e) {
                    root.appsList = []
                }
            }
        }
    }
    Timer { 
        interval: 1500; running: root.showAppVol && root.active; repeat: true; triggeredOnStart: true
        onTriggered: {
            if (!root.draggingVol) appVolProc.running = true
        }
    }

    function togglePlay() { mProc.command = ["playerctl", "play-pause"]; mProc.running = true }
    function nextTrack() { mProc.command = ["playerctl", "next"]; mProc.running = true }
    function prevTrack() { mProc.command = ["playerctl", "previous"]; mProc.running = true }
    function setPreset(p) { 
        root.activePreset = p; mProc.command = ["sh", "-c", "~/.config/scripts/eq-control.sh set-preset " + p]; mProc.running = true
        var nb = [0,0,0,0,0,0,0,0,0,0]
        if (p === "Bass") nb = [10, 8, 6, 3, 1, 0, -1, -2, -3, -4]
        else if (p === "Treble") nb = [-4, -3, -2, -1, 0, 2, 5, 8, 10, 12]
        else if (p === "Rock") nb = [8, 6, 4, -1, -3, -1, 3, 5, 7, 8]
        else if (p === "Pop") nb = [-2, -1, 2, 5, 7, 6, 3, 1, -1, -2]
        else if (p === "Jazz") nb = [6, 4, 2, 4, -1, -1, 2, 4, 5, 6]
        else if (p === "Vocal") nb = [-4, -2, 0, 2, 5, 6, 5, 2, 0, -2]
        else if (p === "Classic") nb = [5, 4, 3, 2, 0, 0, -2, -3, -4, -5]
        root.eqBands = nb
    }
    Process { id: mProc }

    // ── UI ──
    ColumnLayout {
        anchors.fill: parent; spacing: 0
        opacity: root.active ? 1.0 : 0.0; scale: root.active ? 1.0 : 0.98; visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

        PanelConnector {
            Layout.fillWidth: true; color: root.cPill; barWidth: root.anchorWidth * root.scale; neckOffset: root.neckOffset
        }

        Rectangle {
            id: mainContainer; Layout.fillWidth: true; Layout.fillHeight: true; radius: 36 * root.scale; color: root.cPill
            border.color: Qt.rgba(1,1,1,0.1); border.width: 1.5 * root.scale

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 32 * root.scale; spacing: 20 * root.scale
                RowLayout {
                    Layout.fillWidth: true; spacing: 28 * root.scale; Layout.alignment: Qt.AlignHCenter
                    Item {
                        width: 140 * root.scale; height: 140 * root.scale
                        Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border.color: root.cMauve; border.width: 2 * root.scale; opacity: 0.15; scale: 1.15 }
                        Item {
                            id: vinyl; anchors.fill: parent
                            Rectangle { id: maskRect; anchors.fill: parent; radius: width / 2; color: root.cPill; clip: true; visible: true; opacity: 0 }
                            OpacityMask {
                                anchors.fill: parent
                                source: albumArt
                                maskSource: Rectangle { width: vinyl.width; height: vinyl.height; radius: width / 2; visible: false }
                                visible: albumArt.status === Image.Ready
                            }
                            Image { id: albumArt; anchors.fill: parent; source: root.mpArtUrl; fillMode: Image.PreserveAspectCrop; visible: false }
                            Rectangle { anchors.centerIn: parent; width: 14 * root.scale; height: 14 * root.scale; radius: width / 2; color: root.cPill; border.color: Qt.rgba(1,1,1,0.2); border.width: 1 * root.scale; z: 10 }
                            Text { anchors.centerIn: parent; text: "󰎆"; font.family: root.font; font.pixelSize: 45 * root.scale; color: root.cMauve; visible: albumArt.status !== Image.Ready }
                            RotationAnimation on rotation { from: 0; to: 360; duration: 7000; loops: Animation.Infinite; running: root.mpPlaying }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 6 * root.scale; Layout.alignment: Qt.AlignVCenter
                        Text { text: root.mpTitle; font.family: root.font; font.pixelSize: 22 * root.scale; font.bold: true; color: root.cText; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: "BY " + (root.mpArtist || "Unknown Artist"); font.family: root.font; font.pixelSize: 14 * root.scale; color: root.cSub; font.weight: Font.Medium }
                        RowLayout {
                            spacing: 12 * root.scale
                            Rectangle { height: 26 * root.scale; implicitWidth: devTxt.implicitWidth + 24 * root.scale; radius: 13 * root.scale; color: Qt.rgba(1,1,1,0.08)
                                Row { anchors.centerIn: parent; spacing: 6 * root.scale
                                    Text { text: "󰂱"; font.family: root.font; font.pixelSize: 12 * root.scale; color: root.cBlue }
                                    Text { id: devTxt; text: root.btDevice; font.family: root.font; font.pixelSize: 11 * root.scale; color: root.cText }
                                }
                            }
                            Text { text: "VIA " + root.mpSource; font.family: root.font; font.pixelSize: 11 * root.scale; font.bold: true; color: root.cMauve }
                        }
                        Item { Layout.preferredHeight: 12 * root.scale }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 8 * root.scale
                            Item { Layout.fillWidth: true; Layout.preferredHeight: 10 * root.scale
                                Rectangle { anchors.fill: parent; radius: 5 * root.scale; color: Qt.rgba(0,0,0,0.3) }
                                Rectangle { width: Math.max(12 * root.scale, parent.width * (root.mpLen > 0 ? root.mpPos / root.mpLen : 0)); height: parent.height; radius: 5 * root.scale; color: root.cMauve
                                    Rectangle { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 14 * root.scale; height: 14 * root.scale; radius: width / 2; color: "white"; border.color: root.cMauve; border.width: 1 * root.scale }
                                }
                            }
                            RowLayout { Layout.fillWidth: true
                                Text { text: root.fmtTime(root.mpPos); font.family: root.font; font.pixelSize: 11 * root.scale; color: root.cSub }
                                Item { Layout.fillWidth: true }
                                Text { text: root.fmtTime(root.mpLen); font.family: root.font; font.pixelSize: 11 * root.scale; color: root.cSub }
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignHCenter; spacing: 48 * root.scale
                    Text { text: "󰒮"; font.family: root.font; font.pixelSize: 32 * root.scale; color: root.cText; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.prevTrack() } }
                    Rectangle {
                        width: 60 * root.scale; height: 60 * root.scale; radius: 20 * root.scale; color: Qt.rgba(1,1,1,0.08)
                        Text { anchors.centerIn: parent; text: root.mpPlaying ? "󰏦" : "󰐍"; font.family: root.font; font.pixelSize: 34 * root.scale; color: root.cMauve }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.togglePlay() }
                    }
                    Text { text: "󰒭"; font.family: root.font; font.pixelSize: 32 * root.scale; color: root.cText; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.nextTrack() } }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1.5 * root.scale; color: Qt.rgba(1,1,1,0.08) }
                
                // Toggle Header
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: root.showAppVol ? "App Volumes" : "Equalizer"; font.family: root.font; font.pixelSize: 18 * root.scale; font.bold: true; color: root.cMauve }
                    Item { Layout.fillWidth: true }
                    
                    Row {
                        spacing: 12 * root.scale
                        Layout.alignment: Qt.AlignVCenter
                        Rectangle {
                            width: 90 * root.scale; height: 32 * root.scale; radius: 16 * root.scale; color: root.showAppVol ? root.cMauve : Qt.rgba(1,1,1,0.08)
                            border.color: root.showAppVol ? "transparent" : Qt.rgba(1,1,1,0.1); border.width: 1.5 * root.scale
                            RowLayout {
                                anchors.centerIn: parent; spacing: 6 * root.scale
                                Text { text: "󰕾"; font.family: root.font; font.pixelSize: 16 * root.scale; color: root.showAppVol ? "#11111b" : root.cText }
                                Text { text: "Apps"; font.family: root.font; font.pixelSize: 13 * root.scale; font.bold: true; color: root.showAppVol ? "#11111b" : root.cText }
                            }
                            MouseArea { 
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.showAppVol = !root.showAppVol; if(root.showAppVol) appVolProc.running = true } 
                            }
                        }
                        
                        Text { text: root.activePreset; font.family: root.font; font.pixelSize: 14 * root.scale; font.bold: true; color: root.cText; visible: !root.showAppVol; Layout.alignment: Qt.AlignVCenter }
                    }
                }

                // Dynamic Area
                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true

                    // --- Equalizer View ---
                    ColumnLayout {
                        anchors.fill: parent; spacing: 14 * root.scale
                        opacity: root.showAppVol ? 0 : 1; visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 300 } }

                        RowLayout {
                            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 14 * root.scale; Layout.alignment: Qt.AlignHCenter
                            Repeater {
                                model: 10
                                ColumnLayout {
                                    Layout.fillHeight: true; spacing: 8 * root.scale; Layout.alignment: Qt.AlignHCenter
                                    Item { id: barBox; Layout.fillHeight: true; Layout.preferredWidth: 24 * root.scale; Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 8 * root.scale; height: parent.height; radius: 4 * root.scale; color: Qt.rgba(0,0,0,0.3) }
                                        Rectangle { width: 8 * root.scale; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; radius: 4 * root.scale; color: root.cMauve; height: Math.max(0, parent.height - dot.y - (dot.height / 2)) }
                                        Rectangle { id: dot; width: 22 * root.scale; height: 22 * root.scale; radius: width / 2; color: "white"; border.color: root.cMauve; border.width: 1.5 * root.scale; anchors.horizontalCenter: parent.horizontalCenter; y: da.drag.active ? y : (parent.height - height) * (1.0 - (root.eqBands[index] + 12) / 24); Behavior on y { enabled: !da.drag.active; NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                                            MouseArea { id: da; anchors.fill: parent; drag.target: dot; drag.axis: Drag.YAxis; drag.minimumY: 0; drag.maximumY: barBox.height - dot.height; onPositionChanged: if (drag.active) { var db = (1.0 - (dot.y / (barBox.height - dot.height))) * 24 - 12; var nb = root.eqBands.slice(); nb[index] = db; root.eqBands = nb; mProc.command = ["sh", "-c", "~/.config/scripts/eq-control.sh set-band " + index + " " + db]; mProc.running = true } }
                                        }
                                    }
                                    Text { Layout.alignment: Qt.AlignHCenter; text: (root.eqBands[index] >= 0 ? "+" : "") + root.eqBands[index].toFixed(1); font.family: root.font; font.pixelSize: 8 * root.scale; font.bold: true; color: root.eqBands[index] !== 0 ? root.cMauve : root.cSub }
                                }
                            }
                        }
                        GridLayout {
                            Layout.fillWidth: true; Layout.alignment: Qt.AlignHCenter; columns: 4; rowSpacing: 10 * root.scale; columnSpacing: 10 * root.scale
                            Repeater {
                                model: ["Flat", "Bass", "Treble", "Rock", "Pop", "Jazz", "Vocal", "Classic"]
                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: 36 * root.scale; radius: 12 * root.scale; color: root.activePreset === modelData ? root.cMauve : Qt.rgba(1,1,1,0.06)
                                    Text { anchors.centerIn: parent; text: modelData; font.family: root.font; font.pixelSize: 12 * root.scale; font.bold: root.activePreset === modelData; color: root.activePreset === modelData ? "#11111b" : root.cText }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setPreset(modelData) }
                                }
                            }
                        }
                    }

                    // --- App Volumes View ---
                    ColumnLayout {
                        anchors.fill: parent; spacing: 10 * root.scale
                        opacity: root.showAppVol ? 1 : 0; visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 300 } }

                        ListView {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            clip: true
                            model: root.appsList
                            spacing: 10 * root.scale
                            delegate: Rectangle {
                                width: ListView.view.width; height: 60 * root.scale; radius: 12 * root.scale; color: Qt.rgba(1,1,1,0.05)
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 12 * root.scale; spacing: 12 * root.scale
                                    // Icon / Mute
                                    Rectangle {
                                        width: 42 * root.scale; height: 42 * root.scale; radius: 12 * root.scale; color: modelData.muted ? Qt.rgba(root.cRed.r, root.cRed.g, root.cRed.b, 0.2) : Qt.rgba(root.cMauve.r, root.cMauve.g, root.cMauve.b, 0.1)
                                        
                                        Image {
                                            anchors.fill: parent; anchors.margins: 6 * root.scale
                                            source: modelData.icon_name ? "image://icon/" + modelData.icon_name.toLowerCase() : ""
                                            fillMode: Image.PreserveAspectFit
                                            visible: status === Image.Ready && !modelData.muted
                                        }

                                        Text { 
                                            anchors.centerIn: parent
                                            text: modelData.muted ? "󰝟" : modelData.icon
                                            font.family: root.font; font.pixelSize: 22 * root.scale
                                            color: modelData.muted ? root.cRed : root.cMauve
                                            visible: !modelData.muted ? (parent.children[0].status !== Image.Ready) : true
                                        }

                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                mProc.command = ["sh", "-c", "~/.config/scripts/app-volume.sh toggle-mute " + modelData.id]
                                                mProc.running = true
                                                appVolProc.running = true
                                            }
                                        }
                                    }
                                    
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 4 * root.scale
                                        Text { text: modelData.label; font.family: root.font; font.pixelSize: 13 * root.scale; font.bold: true; color: root.cText; elide: Text.ElideRight; Layout.fillWidth: true }
                                        
                                        Item {
                                            Layout.fillWidth: true; Layout.preferredHeight: 22 * root.scale
                                            Process { id: volProc }
                                            Rectangle {
                                                id: trackBar; anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 8 * root.scale; radius: 4 * root.scale; color: Qt.rgba(0,0,0,0.3)
                                                
                                                Rectangle {
                                                    width: Math.max(0, Math.min(parent.width, parent.width * (modelData.volume / 100.0)))
                                                    height: parent.height; radius: 4 * root.scale; color: modelData.muted ? root.cSub : root.cMauve
                                                    visible: !appDa.drag.active
                                                }

                                                // Progress bar while dragging (immediate feedback)
                                                Rectangle {
                                                    width: appDot.x + 8 * root.scale; height: parent.height; radius: 4 * root.scale; color: root.cMauve
                                                    visible: appDa.drag.active
                                                }

                                                Rectangle {
                                                    id: appDot; width: 18 * root.scale; height: 18 * root.scale; radius: width / 2; color: "white"; border.color: modelData.muted ? root.cSub : root.cMauve; border.width: 2 * root.scale
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    x: appDa.drag.active ? x : Math.max(0, Math.min(parent.width - width, (parent.width - width) * (modelData.volume / 100.0)))
                                                    
                                                    MouseArea {
                                                        id: appDa; anchors.fill: parent; anchors.margins: -10 * root.scale; drag.target: appDot; drag.axis: Drag.XAxis; drag.minimumX: 0; drag.maximumX: trackBar.width - appDot.width
                                                        onPressed: root.draggingVol = true
                                                        onPositionChanged: {
                                                            if (drag.active) {
                                                                var newVol = Math.round((appDot.x / (trackBar.width - appDot.width)) * 100.0)
                                                                // Debounce: solo ejecutar si no hay proceso corriendo para no saturar pactl
                                                                if (!volProc.running) {
                                                                    volProc.command = ["sh", "-c", "~/.config/scripts/app-volume.sh set " + modelData.id + " " + newVol]
                                                                    volProc.running = true
                                                                }
                                                            }
                                                        }
                                                        onReleased: {
                                                            root.draggingVol = false
                                                            var newVol = Math.round((appDot.x / (trackBar.width - appDot.width)) * 100.0)
                                                            mProc.command = ["sh", "-c", "~/.config/scripts/app-volume.sh set " + modelData.id + " " + newVol]
                                                            mProc.running = true
                                                            // Forzar actualización inmediata después del arrastre
                                                            appVolProc.running = true
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    Text { text: (appDa.drag.active ? Math.round((appDot.x / (trackBar.width - appDot.width)) * 100.0) : modelData.volume) + "%"; font.family: root.font; font.pixelSize: 12 * root.scale; color: root.cText; Layout.preferredWidth: 35 * root.scale; horizontalAlignment: Text.AlignRight }
                                }
                            }
                        }
                        Item {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            visible: root.appsList.length === 0
                            Text { anchors.centerIn: parent; text: "No active audio apps"; font.family: root.font; font.pixelSize: 14 * root.scale; color: root.cSub }
                        }
                    }
                }
            }
        }
    }
    function fmtTime(s) { var m = Math.floor(s / 60); var r = s % 60; return m + ":" + (r < 10 ? "0" : "") + r }
}
