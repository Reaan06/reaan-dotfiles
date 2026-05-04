import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Punto de entrada de Quickshell.
// Usamos un solo bloque Variants para agrupar todas las ventanas por monitor,
// lo que permite referenciar coordenadas entre ellas fácilmente.

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

    // ── Monitor-Specific Windows ──
    Variants {
        model: Quickshell.screens

        // Empleamos un Item como contenedor para que todas las ventanas del mismo monitor
        // compartan el mismo scope de IDs.
        Item {
            property var screenModel: modelData

            // 1. Top bar
            PanelWindow {
                id: bar
                screen: screenModel
                anchors { top: true; left: true; right: true }
                margins { top: 6; left: 16; right: 16 }
                exclusionMode: ExclusionMode.Auto
                implicitHeight: 44
                color: "transparent"

                StatusBar {
                    id: statusBar
                    anchors.fill: parent
                }
            }

            // 2. OSD overlay
            PanelWindow {
                id: osdWin
                screen: screenModel
                visible: osdContent.osdVisible
                anchors.right: true
                margins { top: 250; right: 12 }
                implicitWidth: 60
                implicitHeight: 300
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"

                Osd {
                    id: osdContent
                    anchors.fill: parent
                }
            }

            // 3. AudioManager popup
            PanelWindow {
                id: audioManagerWin
                screen: screenModel
                visible: audioManagerVisible || amAnimating
                anchors.top: true
                anchors.left: true
                
                margins {
                    top: 48 
                    // Alineación dinámica con el módulo MPRIS en la barra de estado
                    left: statusBar.mprisCenterWorldX - (audioManagerWin.width / 2)
                }

                // Animación suave para cuando el módulo MPRIS se mueve o aparece
                Behavior on margins.left { 
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic } 
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

            // 4. Super F2 Panel popup
            PanelWindow {
                id: superF2Win
                screen: screenModel
                visible: superF2Visible || f2Animating
                anchors.top: true
                anchors.left: true
                
                margins {
                    top: 48
                    // Centrado en la pantalla
                    left: (screenModel.width - 1200) / 2
                }

                implicitWidth: 1200
                implicitHeight: 762
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"

                SuperF2Panel {
                    anchors.fill: parent
                    active: superF2Visible
                    // Pasamos el desfase entre el centro del panel y el reloj de la barra
                    neckOffset: statusBar.clockCenterWorldX - (superF2Win.x + superF2Win.width / 2)
                }
            }
        }
    }
}
