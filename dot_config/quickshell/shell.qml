import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Punto de entrada de Quickshell.
// Variants crea una instancia de PanelWindow por cada monitor conectado.
// Cuando se conecta/desconecta un monitor, Quickshell gestiona el ciclo
// de vida automáticamente.

ShellRoot {
    // ── Global state for AudioManager ──
    property bool audioManagerVisible: false
    property string _lastAmState: ""

    Process {
        id: amStateProc
        command: ["sh", "-c", "cat ${XDG_RUNTIME_DIR:-/tmp}/qs-audio-manager 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = text.trim()
                if (raw === _lastAmState) return
                _lastAmState = raw
                audioManagerVisible = (raw === "visible")
            }
        }
    }
    Timer { interval: 250; running: true; repeat: true; triggeredOnStart: true; onTriggered: amStateProc.running = true }

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

            anchors {
                top: true
                right: true
                bottom: true
            }

            margins {
                top: 60
                right: 12
                bottom: 60
            }

            exclusionMode: ExclusionMode.Ignore
            implicitWidth: 56
            color: "transparent"

            Osd {
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

            visible: audioManagerVisible

            anchors {
                top: true
                left: true
            }

            margins {
                top: 60
                left: 16
            }

            width: 500
            height: 650

            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            AudioManager {
                anchors.fill: parent
            }
        }
    }
}
