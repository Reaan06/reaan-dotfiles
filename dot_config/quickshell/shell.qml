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

    // ── Global Palette ──
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

    Process {
        id: paletteProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/.palette 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { parsePalette(text.trim()) } }
    }
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: paletteProc.running = true }

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
        } catch (e) { console.log("Error parsing palette: " + e) }
    }

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

    // ── Dock Antigravity (Bottom, centered) ──
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: dockWin
            property var modelData
            screen: modelData
            
            anchors.bottom: true
            anchors.left: true
            focusable: true
            
            // Centrado dinámico basado en el ancho real
            margins.left: (screen.width - implicitWidth) / 2
            
            // Ancho dinámico: lo que necesite el dock + margen
            implicitWidth: dm.dockWidth + 100
            
            // Altura dinámica: 
            // - 480 si el launcher está abierto
            // - 100 si el dock está desplegado
            // - 40 si está en modo "notch" (oculto)
            implicitHeight: dm.launcherOpen ? 550 : (dm.active ? 100 : 40)
            
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            
            DockManager { 
                id: dm
                anchors.fill: parent 
            }
        }
    }
}
