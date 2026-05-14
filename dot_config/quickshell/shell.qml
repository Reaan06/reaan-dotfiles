import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Punto de entrada de Quickshell.

ShellRoot {
    id: shellRoot

    // ── Global Anchor Registry ──
    // Almacena las coordenadas locales de los módulos (respecto a la barra) por monitor.
    property var anchors: ({})

    // ── Global state for AudioManager, Super F2 & Bluetooth ──
    property bool audioManagerVisible: false
    property string audioManagerMonitor: ""
    property bool superF2Visible: false
    property string superF2Monitor: ""
    property bool btVisible: false
    property string btMonitor: ""
    property bool amAnimating: false
    property bool f2Animating: false
    property bool btAnimating: false
    property string _lastAmState: ""
    property string _lastF2State: ""
    property string _lastBtState: ""

    Process {
        id: amStateProc
        command: ["sh", "-c", "cat ${XDG_RUNTIME_DIR:-/tmp}/qs-audio-manager 2>/dev/null; echo '---'; cat ${XDG_RUNTIME_DIR:-/tmp}/qs-super-f2 2>/dev/null; echo '---'; cat ${XDG_RUNTIME_DIR:-/tmp}/qs-bt-panel 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split("---")
                if (parts.length < 3) return
                
                var amRawFull = parts[0].trim()
                var f2RawFull = parts[1].trim()
                var btRawFull = parts[2].trim()

                if (amRawFull !== _lastAmState) {
                    _lastAmState = amRawFull
                    var amParts = amRawFull.split(" ")
                    var amRaw = amParts[0]
                    audioManagerMonitor = amParts.length > 1 ? amParts[1] : ""
                    var newVal = (amRaw === "visible")
                    if (!newVal && audioManagerVisible) { amAnimating = true; amHideTimer.start() }
                    else if (newVal) { amAnimating = false; amHideTimer.stop() }
                    audioManagerVisible = newVal
                }
                if (f2RawFull !== _lastF2State) {
                    _lastF2State = f2RawFull
                    var f2Parts = f2RawFull.split(" ")
                    var f2Raw = f2Parts[0]
                    superF2Monitor = f2Parts.length > 1 ? f2Parts[1] : ""
                    var newValF2 = (f2Raw === "visible")
                    if (!newValF2 && superF2Visible) { f2Animating = true; f2HideTimer.start() }
                    else if (newValF2) { f2Animating = false; f2HideTimer.stop() }
                    superF2Visible = newValF2
                }
                if (btRawFull !== _lastBtState) {
                    _lastBtState = btRawFull
                    var btParts = btRawFull.split(" ")
                    var btRaw = btParts[0]
                    btMonitor = btParts.length > 1 ? btParts[1] : ""
                    var newValBt = (btRaw === "visible")
                    if (!newValBt && btVisible) { btAnimating = true; btHideTimer.start() }
                    else if (newValBt) { btAnimating = false; btHideTimer.stop() }
                    btVisible = newValBt
                }
            }
        }
    }
    Timer { interval: 250; running: true; repeat: true; triggeredOnStart: true; onTriggered: amStateProc.running = true }

    Timer { id: amHideTimer; interval: 400; onTriggered: amAnimating = false }
    Timer { id: f2HideTimer; interval: 400; onTriggered: f2Animating = false }
    Timer { id: btHideTimer; interval: 400; onTriggered: btAnimating = false }

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
            anchors { top: true; left: true; right: true }
            margins { top: 6; left: 16; right: 16 }
            exclusionMode: ExclusionMode.Auto
            implicitHeight: 44
            color: "transparent"
            StatusBar { anchors.fill: parent }
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
            margins { top: 250; right: 12 }
            implicitWidth: 60; implicitHeight: 300
            exclusionMode: ExclusionMode.Ignore; color: "transparent"
            Osd { id: osdContent; anchors.fill: parent }
        }
    }

    // ── AudioManager popup (top-left, aligned with music/mpris module) ──
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: audioManagerWin
            property var modelData
            screen: modelData
            visible: (audioManagerVisible || amAnimating) && screen.name === audioManagerMonitor
            anchors.top: true; anchors.left: true
            
            // Coordenada X global del ancla (16px de margen de la barra + posición local del módulo)
            property real worldAnchorX: 16 + (shellRoot.anchors[screen.index] ? shellRoot.anchors[screen.index].mpris : 0)
            property real anchorWidth: shellRoot.anchors[screen.index] ? shellRoot.anchors[screen.index].mprisWidth : 200
            
            onWorldAnchorXChanged: console.log("AUDIO: worldAnchorX=" + worldAnchorX + " width=" + width + " screenWidth=" + modelData.width)

            margins {
                top: 48 
                // Centramos el panel pero aseguramos que no se salga de la pantalla (min 16px de margen)
                left: Math.max(16, Math.min(screen.width - width - 16, worldAnchorX - (width / 2)))
            }

            Behavior on margins.left { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            implicitWidth: Math.max(450, screen.width * 0.3)
            implicitHeight: Math.max(620, screen.height * 0.65)
            exclusionMode: ExclusionMode.Ignore; color: "transparent"

            AudioManager {
                anchors.fill: parent
                active: audioManagerVisible
                anchorWidth: audioManagerWin.anchorWidth
                // El cuello del conector persigue al ancla si el panel está desplazado por el clamping
                neckOffset: worldAnchorX - (audioManagerWin.x + audioManagerWin.width / 2)
                scale: Math.max(0.7, Math.min(width / 500, height / 662))
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
            visible: (superF2Visible || f2Animating) && screen.name === superF2Monitor
            anchors.top: true; anchors.left: true
            
            // Coordenada X global del reloj
            property real worldClockX: 16 + (shellRoot.anchors[screen.index] ? shellRoot.anchors[screen.index].clock : 0)
            property real clockWidth: shellRoot.anchors[screen.index] ? shellRoot.anchors[screen.index].clockWidth : 350

            margins {
                top: 48
                // Panel siempre centrado perfectamente en el monitor
                left: (screen.width - width) / 2
            }

            implicitWidth: screen.width * 0.74
            implicitHeight: screen.height * 0.70
            exclusionMode: ExclusionMode.Ignore; color: "transparent"

            SuperF2Panel {
                anchors.fill: parent
                active: superF2Visible
                anchorWidth: superF2Win.clockWidth
                // El conector se desplaza dinámicamente para unirse al reloj
                neckOffset: worldClockX - (superF2Win.x + superF2Win.width / 2)
                scale: Math.max(0.65, Math.min(parent.width / 1624, parent.height / 800))
            }
        }
    }

    // ── Bluetooth Panel popup (Network Manager, right side) ──
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: btWin
            property var modelData
            screen: modelData
            visible: (btVisible || btAnimating) && screen.name === btMonitor
            
            // Posicionamiento lateral derecho
            anchors.top: true; anchors.bottom: true; anchors.right: true
            
            margins {
                top: 60
                bottom: 60
                right: 40
            }

            // Ancho masivo (~48% del monitor, casi la mitad)
            implicitWidth: Math.max(850, screen.width * 0.48)
            
            exclusionMode: ExclusionMode.Ignore; color: "transparent"

            BluetoothPanel {
                anchors.fill: parent
                active: btVisible
                scale: 1.15 // Bajamos escala para que el layout nativo maneje el espacio extra
            }
        }
    }
}
