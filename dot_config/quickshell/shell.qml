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
    property bool amAnimating: false
    property bool f2Animating: false
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
                    var newVal = (amRaw === "visible")
                    if (!newVal && audioManagerVisible) {
                        amAnimating = true
                        amHideTimer.start()
                    } else if (newVal) {
                        amAnimating = false
                        amHideTimer.stop()
                    }
                    audioManagerVisible = newVal
                }
                if (f2Raw !== _lastF2State) {
                    _lastF2State = f2Raw
                    var newValF2 = (f2Raw === "visible")
                    if (!newValF2 && superF2Visible) {
                        f2Animating = true
                        f2HideTimer.start()
                    } else if (newValF2) {
                        f2Animating = false
                        f2HideTimer.stop()
                    }
                    superF2Visible = newValF2
                }
            }
        }
    }
    Timer { interval: 250; running: true; repeat: true; triggeredOnStart: true; onTriggered: amStateProc.running = true }

    Timer { id: amHideTimer; interval: 400; onTriggered: amAnimating = false }
    Timer { id: f2HideTimer; interval: 400; onTriggered: f2Animating = false }

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

            implicitWidth: 60
            implicitHeight: 300

            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            Osd {
                id: osdContent
                anchors.fill: parent
            }
        }
    }

    // ── AudioManager popup (top-left, aligned with music/mpris module) ──
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: audioManagerWin

            property var modelData
            screen: modelData

            // Solo visible cuando está activo o animando para no bloquear clics
            visible: audioManagerVisible || amAnimating

            anchors.top: true
            anchors.left: true
            anchors.right: false

            margins {
                top: 48 
                left: 280 // Alineación manual aproximada con el módulo MPRIS
            }

            implicitWidth: 500
            implicitHeight: 662

            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            AudioManager {
                anchors.fill: parent
                active: audioManagerVisible
            }
        }
    }

    // ── Super F2 Panel popup (center-top, aligned with clock) ──
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: superF2Win

            property var modelData
            screen: modelData

            visible: superF2Visible || f2Animating

            anchors.top: true
            anchors.left: true
            anchors.right: false
            
            margins {
                top: 48
                left: screen ? (screen.width - 1200) / 2 : 0
            }

            implicitWidth: 1200
            implicitHeight: 762

            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            SuperF2Panel {
                anchors.fill: parent
                active: superF2Visible
            }
        }
    }
}
