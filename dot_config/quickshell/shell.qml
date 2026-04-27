import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Punto de entrada de Quickshell.
// Variants crea una instancia de PanelWindow por cada monitor conectado.
// Cuando se conecta/desconecta un monitor, Quickshell gestiona el ciclo
// de vida automáticamente.

ShellRoot {
    // ── Global state for AudioManager & Super F2 ──
    property bool audioManagerVisible: false
    property bool superF2Visible: false
    property string _lastAmState: ""
    property string _lastF2State: ""

    Process {
        id: amStateProc
        command: ["sh", "-c", "cat ${XDG_RUNTIME_DIR:-/tmp}/qs-audio-manager 2>/dev/null; echo '---'; cat ${XDG_RUNTIME_DIR:-/tmp}/qs-super-f2 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split("---")
                if (parts.length < 2) return
                
                var amRaw = parts[0].trim()
                var f2Raw = parts[1].trim()

                if (amRaw !== _lastAmState) {
                    _lastAmState = amRaw
                    audioManagerVisible = (amRaw === "visible")
                }
                if (f2Raw !== _lastF2State) {
                    _lastF2State = f2Raw
                    superF2Visible = (f2Raw === "visible")
                }
            }
        }
    }
    Timer { interval: 250; running: true; repeat: true; triggeredOnStart: true; onTriggered: amStateProc.running = true }

    property var mprisData: ({})
    property var clockData: ({})

    // ── Global: start MPRIS follow daemon (once, not per-monitor) ──
    Process {
        id: mprisStart
        command: ["sh", "-c", "~/.config/scripts/mpris-follow.sh &"]
    }
    Component.onCompleted: mprisStart.running = true

    // ── Top bar (one per monitor) ──
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar

            property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            margins {
                top: 6
                left: 16
                right: 16
            }

            exclusionMode: ExclusionMode.Auto
            implicitHeight: 44
            color: "transparent"

            StatusBar {
                anchors.fill: parent
                onMprisCenterXChanged: {
                    var d = mprisData
                    d[modelData.name] = { center: mprisCenterX, width: mprisWidth }
                    mprisData = d
                }
                onClockCenterXChanged: {
                    var d = clockData
                    d[modelData.name] = { center: clockCenterX, width: clockWidth }
                    clockData = d
                }
            }
        }
    }

    // ── OSD overlay (volume/brightness, right edge, one per monitor) ──
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: osdWin

            property var modelData
            screen: modelData

            visible: osdContent.osdVisible

            anchors.right: true
            
            margins {
                top: 250 // Offset from top to avoid overlapping Dashboard close button
                right: 12
            }

            width: 60
            height: 300

            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            Osd {
                id: osdContent
                anchors.fill: parent
            }
        }
    }

    // ── AudioManager popup (top-left, one per monitor, visibility controlled by shell state) ──
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: audioManagerWin

            property var modelData
            screen: modelData

            visible: audioManagerVisible || amContent.animating

            anchors {
                top: true
                left: true
            }

            margins {
                top: 50
                left: 16
            }

            width: 500
            height: 650

            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            AudioManager {
                id: amContent
                anchors.fill: parent
                opened: audioManagerVisible
                originX: (mprisData[modelData.name] ? mprisData[modelData.name].center : 250) - 16
                pillWidth: mprisData[modelData.name] ? mprisData[modelData.name].width : 150
            }
        }
    }

    // ── Super F2 Panel popup (center-top, one per monitor, visibility controlled by shell state) ──
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: superF2Win

            property var modelData
            screen: modelData

            visible: superF2Visible || f2Content.animating

            anchors.top: true
            // Removing left/right anchors lets the compositor center it horizontally
            // based on the explicit width.
            
            margins.top: 50

            width: 1200
            height: 750

            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            SuperF2Panel {
                id: f2Content
                anchors.fill: parent
                opened: superF2Visible
                originX: (clockData[modelData.name] ? clockData[modelData.name].center : (bar.width / 2)) - (bar.width - 1200)/2 - 16
                pillWidth: clockData[modelData.name] ? clockData[modelData.name].width : 200
            }
        }
    }
}
