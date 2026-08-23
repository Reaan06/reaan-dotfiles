import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "components"

// Punto de entrada de Quickshell.

ShellRoot {
    id: shellRoot

    RuntimePaths { id: runtimePaths }

    // ── Global Anchor Registry ──
    // Almacena las coordenadas locales de los módulos (respecto a la barra) por monitor.
    property var anchors: ({})

    // ── Global state for AudioManager, Super F2 & Bluetooth ──
    property bool audioManagerVisible: false
    property string audioManagerMonitor: ""
    property bool superF2Visible: false
    property string superF2Monitor: ""
    property bool dockVisible: false
    property string dockMonitor: ""
    property bool btVisible: false
    property string btMonitor: ""
    property bool wallpaperVisible: false
    property string wallpaperMonitor: ""
    property bool aiUsageVisible: false
    property bool aiUsageAnimating: false
    property string aiUsageMonitor: ""
    property string aiUsagePeriod: "day"
    property string aiUsageStatus: "missing"
    property string aiUsageError: "source-missing"
    property int aiUsageSourceAge: -1
    property bool aiUsageLoading: false
    property var lastKnownGood: null
    readonly property var aiUsageStatuses: ["ok", "missing", "stale", "locked", "malformed", "schema-error"]
    property bool amAnimating: false
    property bool f2Animating: false
    property bool btAnimating: false
    property bool wpAnimating: false
    property string _lastAmState: ""
    property string _lastF2State: ""
    property string _lastDockState: ""
    property string _lastBtState: ""
    property string _lastWallpaperState: ""

    function toggleAiUsage(monitorName) {
        if (aiUsageVisible && aiUsageMonitor === monitorName) {
            aiUsageVisible = false
            aiUsageAnimating = true
            aiUsageHideTimer.start()
            return
        }
        aiUsageMonitor = monitorName
        aiUsageVisible = true
        aiUsageAnimating = false
        aiUsageHideTimer.stop()
        refreshAiUsage()
    }

    function refreshAiUsage() {
        if (aiUsageProcess.running) return
        aiUsageLoading = true
        aiUsageProcess.running = true
    }

    function setAiUsagePeriod(period) {
        if (period !== "day" && period !== "week" && period !== "month") return
        aiUsagePeriod = period
        refreshAiUsage()
    }

    function validAiUsageTotals(totals) {
        if (!totals || typeof totals !== "object") return false
        var keys = ["cost", "input_tokens", "output_tokens", "reasoning_tokens", "cache_tokens"]
        for (var i = 0; i < keys.length; i++) {
            if (typeof totals[keys[i]] !== "number" || !isFinite(totals[keys[i]])) return false
        }
        return true
    }

    function handleAiUsageOutput(raw) {
        var data = null
        try { data = JSON.parse(raw) } catch (error) { data = null }
        var status = data && aiUsageStatuses.indexOf(data.status) >= 0 ? data.status : "malformed"
        if (status === "ok" && !validAiUsageTotals(data.totals)) status = "malformed"

        aiUsageStatus = status
        aiUsageError = data && data.error ? data.error : (status === "ok" ? "" : status)
        aiUsageSourceAge = data && typeof data.source_age_seconds === "number"
            ? data.source_age_seconds : -1
        if (status === "ok") lastKnownGood = data
        aiUsageLoading = false
    }

    Process {
        id: aiUsageProcess
        command: ["python3", runtimePaths.scriptsDir + "/ai_usage.py", "--period", aiUsagePeriod]
        stdout: StdioCollector {
            onStreamFinished: shellRoot.handleAiUsageOutput(text.trim())
        }
        onExited: function(exitCode) {
            if (exitCode !== 0 && aiUsageLoading) {
                shellRoot.handleAiUsageOutput("")
            }
        }
    }

    Timer {
        id: aiUsageTimer
        interval: 300000
        running: aiUsageVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: refreshAiUsage()
    }
    Timer { id: aiUsageHideTimer; interval: 400; onTriggered: aiUsageAnimating = false }

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
        command: ["sh", "-c", "cat ${XDG_RUNTIME_DIR:-/tmp}/qs-audio-manager 2>/dev/null; echo '---'; cat ${XDG_RUNTIME_DIR:-/tmp}/qs-super-f2 2>/dev/null; echo '---'; cat ${XDG_RUNTIME_DIR:-/tmp}/qs-dock-toggle 2>/dev/null; echo '---'; cat ${XDG_RUNTIME_DIR:-/tmp}/qs-bt-panel 2>/dev/null; echo '---'; cat ${XDG_RUNTIME_DIR:-/tmp}/qs-wallpaper-picker 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split("---")
                if (parts.length < 5) return
                
                var amRawFull = parts[0].trim()
                var f2RawFull = parts[1].trim()
                var dockRawFull = parts[2].trim()
                var btRawFull = parts[3].trim()
                var wpRawFull = parts[4].trim()

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
                if (dockRawFull !== _lastDockState) {
                    _lastDockState = dockRawFull
                    var dockParts = dockRawFull.split(" ")
                    var dockRaw = dockParts[0]
                    dockMonitor = dockParts.length > 1 ? dockParts[1] : ""
                    dockVisible = (dockRaw === "visible")
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
                if (wpRawFull !== _lastWallpaperState) {
                    _lastWallpaperState = wpRawFull
                    var wpParts = wpRawFull.split(" ")
                    var wpRaw = wpParts[0]
                    wallpaperMonitor = wpParts.length > 1 ? wpParts[1] : ""
                    var newValWp = (wpRaw === "visible")
                    if (!newValWp && wallpaperVisible) { wpAnimating = true; wpHideTimer.start() }
                    else if (newValWp) { wpAnimating = false; wpHideTimer.stop() }
                    wallpaperVisible = newValWp
                }
            }
        }
    }
    Timer { interval: 250; running: true; repeat: true; triggeredOnStart: true; onTriggered: amStateProc.running = true }

    Timer { id: amHideTimer; interval: 400; onTriggered: amAnimating = false }
    Timer { id: f2HideTimer; interval: 400; onTriggered: f2Animating = false }
    Timer { id: btHideTimer; interval: 400; onTriggered: btAnimating = false }
    Timer { id: wpHideTimer; interval: 400; onTriggered: wpAnimating = false }

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

    // ── Local OpenCode AI Usage popup ──
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: aiUsageWin
            property var modelData
            screen: modelData
            visible: (aiUsageVisible || aiUsageAnimating) && screen.name === aiUsageMonitor
            anchors.top: true; anchors.left: true
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            property real worldAnchorX: 16 + (shellRoot.anchors[screen.index]
                ? shellRoot.anchors[screen.index].aiUsage : 0)
            property real anchorWidth: shellRoot.anchors[screen.index]
                ? shellRoot.anchors[screen.index].aiUsageWidth : 120

            margins {
                top: 48
                left: Math.max(16, Math.min(screen.width - width - 16, worldAnchorX - (width / 2)))
            }
            Behavior on margins.left { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            implicitWidth: Math.max(430, screen.width * 0.34)
            implicitHeight: Math.max(520, screen.height * 0.58)
            exclusionMode: ExclusionMode.Ignore; color: "transparent"

            AiUsageView {
                anchors.fill: parent
                period: shellRoot.aiUsagePeriod
                status: shellRoot.aiUsageStatus
                errorCode: shellRoot.aiUsageError
                loading: shellRoot.aiUsageLoading
                sourceAgeSeconds: shellRoot.aiUsageSourceAge
                snapshot: shellRoot.lastKnownGood
                anchorWidth: aiUsageWin.anchorWidth
                neckOffset: aiUsageWin.worldAnchorX - (aiUsageWin.x + aiUsageWin.width / 2)
                onRefreshRequested: shellRoot.refreshAiUsage()
                onPeriodSelected: shellRoot.setAiUsagePeriod(selectedPeriod)
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
            
            // Allow keyboard focus for text input (WiFi passwords)
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

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

    // ── Wallpaper Picker popup (Centered) ──
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: wallpaperWin
            property var modelData
            screen: modelData
            visible: (wallpaperVisible || wpAnimating) && screen.name === wallpaperMonitor
            
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            anchors.top: true; anchors.left: true
            
            margins {
                top: (screen.height - height) / 2
                left: (screen.width - width) / 2
            }

            implicitWidth: screen.width * 0.80
            implicitHeight: screen.height * 0.75
            
            exclusionMode: ExclusionMode.Ignore; color: "transparent"

            WallpaperPicker {
                anchors.fill: parent
                active: wallpaperVisible
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
            // Cuando está inactivo, extendemos horizontalmente todo el ancho para
            // capturar hover desde cualquier posición X en la franja inferior
            anchors.left: true
            anchors.right: !dm.active
            focusable: true
            
            // Centrado dinámico basado en el ancho real (solo cuando está activo)
            margins.left: dm.active ? (screen.width - implicitWidth) / 2 : 0
            margins.right: 0
            
            // Ancho dinámico: El ancho del dock + margen, pero NUNCA menor que el launcher si está abierto
            implicitWidth: Math.max(dm.dockWidth + 100, dm.launcherOpen ? 550 : 0)
            
            // Altura dinámica:
            // - 600 si el launcher está abierto
            // - 100 si el dock está desplegado
            // - 30 si está en modo "notch" (zona de hover)
            implicitHeight: dm.launcherOpen ? 600 : (dm.active ? 100 : 30)
            
            // ExclusionMode.Normal cuando está inactivo permite que el compositor
            // (Hyprland) envíe eventos de hover. ExclusionMode.Ignore los bloquea.
            exclusionMode: dm.active ? ExclusionMode.Exclusive : ExclusionMode.Normal
            
            WlrLayershell.keyboardFocus: dm.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            
            color: "transparent"
            
            DockManager { 
                id: dm
                anchors.fill: parent 
                externalActive: (dockVisible && screen.name === dockMonitor)
            }
        }
    }
}

