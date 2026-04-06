import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// OSD — Volume/Brightness overlay on the right edge of the screen
// Triggered by osd-control.sh writing to /tmp/qs-osd
// Auto-hides after 2 seconds

Item {
    id: root

    readonly property string font: "JetBrains Mono Nerd Font"
    property color cPill: Qt.rgba(0.16, 0.16, 0.18, 0.92)
    property color cTeal: "#8a9a9e"
    property color cYellow: "#a09882"
    property color cPeach: "#a09882"
    property color cSub: "#5a5a64"
    property color cText: "#c8cad0"

    // OSD state
    property string osdType: ""       // "volume" or "brightness"
    property int osdValue: 0          // 0-100
    property bool osdMuted: false
    property bool osdVisible: false
    property string _lastOsd: ""

    // Poll /tmp/qs-osd for changes
    Process {
        id: osdProc
        command: ["sh", "-c", "cat ${XDG_RUNTIME_DIR:-/tmp}/qs-osd 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = text.trim()
                if (raw.length === 0 || raw === root._lastOsd) return
                root._lastOsd = raw

                var parts = raw.split(" ")
                if (parts.length >= 2) {
                    root.osdType = parts[0]
                    root.osdValue = parseInt(parts[1]) || 0
                    root.osdMuted = parts.length >= 3 && parts[2] === "true"
                    root.osdVisible = true
                    hideTimer.restart()
                }
            }
        }
    }
    Timer { interval: 300; running: true; repeat: true; triggeredOnStart: true; onTriggered: osdProc.running = true }

    // Auto-hide after 2 seconds
    Timer {
        id: hideTimer
        interval: 2000
        onTriggered: root.osdVisible = false
    }

    // Palette loader (same as StatusBar)
    Process {
        id: palProc
        command: ["sh", "-c", "cat $HOME/.cache/qs-palette 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(" ")
                if (parts.length < 8) return
                var pc = parts[0]
                root.cPill = Qt.rgba(parseInt(pc.substr(1,2),16)/255,
                                     parseInt(pc.substr(3,2),16)/255,
                                     parseInt(pc.substr(5,2),16)/255, 0.92)
                root.cTeal   = parts[1]
                root.cYellow = parts[4]
                root.cPeach  = parts[4]
                root.cText   = parts[6]
                root.cSub    = parts[7]
            }
        }
    }
    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: palProc.running = true }

    // Helper functions
    function osdIcon() {
        if (osdType === "volume") {
            if (osdMuted) return "󰝟"
            if (osdValue > 66) return "󰕾"
            if (osdValue > 33) return "󰖀"
            return "󰕿"
        } else {
            if (osdValue > 70) return "󰃠"
            if (osdValue > 30) return "󰃟"
            return "󰃞"
        }
    }

    function osdColor() {
        if (osdType === "volume") {
            return osdMuted ? cSub : cTeal
        }
        return cPeach
    }

    // ═══════════════════════════════════════════════
    // VISUAL — Vertical pill on right edge
    // ═══════════════════════════════════════════════
    Rectangle {
        id: osdPopup

        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter

        width: 48
        height: 220
        radius: 24
        color: root.cPill

        opacity: root.osdVisible ? 1.0 : 0.0
        scale: root.osdVisible ? 1.0 : 0.8
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            // Icon
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.osdIcon()
                font.family: root.font; font.pixelSize: 18
                color: root.osdColor()
            }

            // Progress bar (vertical, bottom-up fill)
            Item {
                Layout.fillHeight: true
                Layout.preferredWidth: 8
                Layout.alignment: Qt.AlignHCenter

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: Qt.rgba(1,1,1,0.08)
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: parent.height * Math.min(root.osdValue / 100, 1.0)
                    radius: 4
                    color: root.osdColor()

                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
            }

            // Value text
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.osdMuted ? "M" : root.osdValue.toString()
                font.family: root.font; font.pixelSize: 11; font.bold: true
                color: root.osdColor()
            }
        }
    }
}
