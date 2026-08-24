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
    // Stores monitor-local screen coordinates for top-bar anchors, by monitor.
    property var anchors: ({})
    property real topBarTopMargin: 6
    property real topBarLeftMargin: 16
    property real topBarHeight: 44

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
    property real aiUsageUnfoldProgress: aiUsageVisible ? 1 : 0
    property string aiUsageMonitor: ""
    property string aiUsagePeriod: "day"
    property string aiUsageStatus: "missing"
    property string aiUsageError: "source-missing"
    property int aiUsageSourceAge: -1
    property bool aiUsageLoading: false
    property bool aiUsageRefreshQueued: false
    property string aiUsageRequestPeriod: "day"
    property bool aiUsageResponseHandled: false
    property string aiUsageResponseStatus: ""
    property string aiUsageLastCompletedAt: ""
    property string aiUsageLastCompletedPeriod: ""
    property string aiUsageLastCompletedStatus: "never"
    property string aiUsageLastGoodPeriod: ""
    property var lastKnownGood: null
    property var aiUsageProviders: []
    property var lastKnownGoodProviders: ({})
    property bool aiProviderAuthBusy: false
    property string aiProviderAuthProvider: ""
    property string aiProviderAuthAction: ""
    property string aiProviderAuthStatus: ""
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
    property string _lastAiUsageState: ""
    property string aiUsageToggleMonitor: ""

    function toggleAiUsage(monitorName) {
        if (aiUsageToggleProcess.running) return
        aiUsageToggleMonitor = monitorName || ""
        aiUsageToggleProcess.running = true
    }

    function startAiUsageRefresh() {
        aiUsageRequestPeriod = aiUsagePeriod
        aiUsageResponseHandled = false
        aiUsageResponseStatus = ""
        aiUsageLoading = true
        aiUsageProcess.running = true
    }

    function refreshAiUsage() {
        if (aiUsageProcess.running) {
            aiUsageRefreshQueued = true
            aiUsageLoading = true
            return
        }
        startAiUsageRefresh()
    }

    function clearAiUsageCache() {
        aiUsageProviders = []
        lastKnownGood = null
        lastKnownGoodProviders = ({})
        aiUsageLastGoodPeriod = ""
        aiUsageStatus = "missing"
        aiUsageError = "refreshing"
        aiUsageSourceAge = -1
    }

    function setAiUsagePeriod(period) {
        if (period !== "day" && period !== "week" && period !== "month") return
        var changed = aiUsagePeriod !== period
        aiUsagePeriod = period
        if (changed) clearAiUsageCache()
        refreshAiUsage()
    }

    function handleAiUsageOutput(raw, requestedPeriod) {
        var requestPeriod = requestedPeriod || aiUsageRequestPeriod
        var data = null
        try { data = JSON.parse(raw) } catch (error) { data = null }
        var status = data && aiUsageStatuses.indexOf(data.status) >= 0 ? data.status : "malformed"
        if (status === "ok" && (!data.period || data.period !== requestPeriod)) {
            aiUsageResponseHandled = true
            aiUsageResponseStatus = "discarded"
            aiUsageRefreshQueued = true
            return
        }
        aiUsageResponseHandled = true
        aiUsageResponseStatus = status

        // Never let a response for an earlier selection become visible.
        if (requestPeriod !== aiUsagePeriod) {
            aiUsageRefreshQueued = true
            return
        }

        if (status === "ok" && !validAiUsageTotals(data.totals)) status = "malformed"
        aiUsageResponseStatus = status

        aiUsageStatus = status
        aiUsageError = data && data.error ? data.error : (status === "ok" ? "" : status)
        aiUsageSourceAge = data && typeof data.source_age_seconds === "number"
            ? data.source_age_seconds : -1
        aiUsageProviders = data && Array.isArray(data.providers) ? data.providers : []
        var retainedProviders = {}
        for (var providerId in lastKnownGoodProviders) retainedProviders[providerId] = lastKnownGoodProviders[providerId]
        for (var i = 0; i < aiUsageProviders.length; i++) {
            var provider = aiUsageProviders[i]
            if (provider && provider.status === "ok" && provider.id) {
                retainedProviders[provider.id] = provider
                aiUsageLastGoodPeriod = requestPeriod
            }
        }
        lastKnownGoodProviders = retainedProviders
        if (status === "ok") {
            lastKnownGood = data
            aiUsageLastGoodPeriod = requestPeriod
        }
    }

    function finishAiUsageRefresh(exitCode) {
        var completedPeriod = aiUsageRequestPeriod
        if (!aiUsageResponseHandled) handleAiUsageOutput("", completedPeriod)
        aiUsageLastCompletedAt = new Date().toISOString()
        aiUsageLastCompletedPeriod = completedPeriod
        aiUsageLastCompletedStatus = completedPeriod === aiUsagePeriod
            ? aiUsageResponseStatus : "discarded"

        if (aiUsageRefreshQueued) {
            aiUsageRefreshQueued = false
            startAiUsageRefresh()
        } else {
            aiUsageLoading = false
        }
    }

    function invokeAiProviderAuth(provider, action) {
        if (aiProviderAuthProcess.running) return
        if ((provider !== "openai" && provider !== "chatgpt" && provider !== "claude")
                || (action !== "login" && action !== "logout")) return
        aiProviderAuthProvider = provider
        aiProviderAuthAction = action
        aiProviderAuthStatus = action === "login" ? "Opening..." : "Logging out..."
        aiProviderAuthBusy = true
        aiProviderAuthProcess.running = true
    }

    function handleAiProviderAuthOutput(raw) {
        var message = (raw || "").trim()
        if (message.length > 96) message = message.substr(0, 96)
        if (message.length > 0) aiProviderAuthStatus = message
    }

    function validAiUsageTotals(totals) {
        if (!totals || typeof totals !== "object") return false
        var keys = ["cost", "input_tokens", "output_tokens", "reasoning_tokens", "cache_tokens"]
        for (var i = 0; i < keys.length; i++) {
            if (typeof totals[keys[i]] !== "number" || !isFinite(totals[keys[i]])) return false
        }
        return true
    }

    Process {
        id: aiUsageProcess
        command: ["python3", runtimePaths.scriptsDir + "/ai_usage.py", "--period", aiUsageRequestPeriod]
        stdout: StdioCollector {
            onStreamFinished: shellRoot.handleAiUsageOutput(text.trim(), shellRoot.aiUsageRequestPeriod)
        }
        onExited: function(exitCode) {
            shellRoot.finishAiUsageRefresh(exitCode)
        }
    }

    Process {
        id: aiUsageToggleProcess
        command: [runtimePaths.scriptsDir + "/ai-usage-toggle.sh", "toggle", shellRoot.aiUsageToggleMonitor]
    }

    Process {
        id: aiProviderAuthProcess
        command: [runtimePaths.scriptsDir + "/ai-provider-auth.sh",
            shellRoot.aiProviderAuthProvider === "chatgpt" ? "openai" : shellRoot.aiProviderAuthProvider,
            shellRoot.aiProviderAuthAction]
        stdout: StdioCollector {
            onStreamFinished: shellRoot.handleAiProviderAuthOutput(text)
        }
        onExited: function(exitCode) {
            var provider = shellRoot.aiProviderAuthProvider === "claude" ? "Claude" : "OpenAI"
            var action = shellRoot.aiProviderAuthAction
            shellRoot.aiProviderAuthBusy = false
            shellRoot.aiProviderAuthStatus = exitCode === 0
                ? provider + (action === "login" ? " login started" : " logged out")
                : provider + " " + action + " failed"
            shellRoot.refreshAiUsage()
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
    Behavior on aiUsageUnfoldProgress {
        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
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
        command: ["cat", runtimePaths.configHome + "/quickshell/.palette"]
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

    FileView {
        id: audioStateFile
        path: runtimePaths.runtimeDir + "/qs-audio-manager"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    FileView {
        id: superF2StateFile
        path: runtimePaths.runtimeDir + "/qs-super-f2"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    FileView {
        id: dockStateFile
        path: runtimePaths.runtimeDir + "/qs-dock-toggle"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    FileView {
        id: btStateFile
        path: runtimePaths.runtimeDir + "/qs-bt-panel"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    FileView {
        id: wallpaperStateFile
        path: runtimePaths.runtimeDir + "/qs-wallpaper-picker"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    FileView {
        id: aiUsageStateFile
        path: runtimePaths.runtimeDir + "/qs-ai-usage"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    function readRuntimeState(fileView) {
        try {
            return fileView.text() || ""
        } catch (error) {
            return ""
        }
    }

    function refreshPanelStates() {
        var amRawFull = readRuntimeState(audioStateFile).trim()
        var f2RawFull = readRuntimeState(superF2StateFile).trim()
        var dockRawFull = readRuntimeState(dockStateFile).trim()
        var btRawFull = readRuntimeState(btStateFile).trim()
        var wpRawFull = readRuntimeState(wallpaperStateFile).trim()
        var aiRawFull = readRuntimeState(aiUsageStateFile).trim()

        if (aiRawFull !== _lastAiUsageState) {
            _lastAiUsageState = aiRawFull
            var aiParts = aiRawFull.split(" ")
            var aiRaw = aiParts[0]
            aiUsageMonitor = aiParts.length > 1 ? aiParts[1] : ""
            var newValAi = (aiRaw === "visible")
            if (!newValAi && aiUsageVisible) { aiUsageAnimating = true; aiUsageHideTimer.start() }
            else if (newValAi) { aiUsageAnimating = false; aiUsageHideTimer.stop(); refreshAiUsage() }
            aiUsageVisible = newValAi
        }

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
    Timer { interval: 250; running: true; repeat: true; triggeredOnStart: true; onTriggered: refreshPanelStates() }

    Timer { id: amHideTimer; interval: 400; onTriggered: amAnimating = false }
    Timer { id: f2HideTimer; interval: 400; onTriggered: f2Animating = false }
    Timer { id: btHideTimer; interval: 400; onTriggered: btAnimating = false }
    Timer { id: wpHideTimer; interval: 400; onTriggered: wpAnimating = false }

    // ── Global: start MPRIS follow daemon (once, not per-monitor) ──
    Process {
        id: mprisStart
        command: [runtimePaths.scriptsDir + "/mpris-follow.sh"]
    }
    Component.onCompleted: {
        mprisStart.running = true
    }

    // ── Top bar (one per monitor) ──
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: bar
            property var modelData
            property string monitorName: modelData.name
            screen: modelData
            anchors { top: true; left: true; right: true }
            margins { top: shellRoot.topBarTopMargin; left: shellRoot.topBarLeftMargin; right: 16 }
            exclusionMode: ExclusionMode.Auto
            implicitHeight: shellRoot.topBarHeight
            color: "transparent"
            StatusBar {
                anchors.fill: parent
                barLeftMargin: shellRoot.topBarLeftMargin
                monitorName: bar.monitorName
            }
        }
    }

    // ── Local OpenCode AI Usage popup ──
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: aiUsageWin
            property var modelData
            property string monitorName: modelData.name
            screen: modelData
            visible: (aiUsageVisible || aiUsageAnimating) && monitorAnchorReady
                && monitorName === aiUsageMonitor && monitorName.length > 0
            anchors.top: true; anchors.left: true
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            // StatusBar publishes a monitor-local screen X including the bar inset.
            // Do not add the top bar margin again here.
            property var monitorAnchor: shellRoot.anchors[monitorName]
            property bool monitorAnchorReady: !!monitorAnchor
            property real screenAnchorX: monitorAnchorReady
                ? monitorAnchor.aiUsageScreenX
                : 0
            property real anchorWidth: monitorAnchorReady ? monitorAnchor.aiUsageWidth : 120

            margins {
                top: shellRoot.topBarTopMargin + shellRoot.topBarHeight
                left: Math.max(16, Math.min(screen.width - width - 16, screenAnchorX - (width / 2)))
            }
            Behavior on margins.left { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            implicitWidth: Math.max(430, screen.width * 0.34)
            implicitHeight: Math.max(520, screen.height * 0.58)
            exclusionMode: ExclusionMode.Ignore; color: "transparent"

             AiUsageView {
                 id: aiUsageContent
                 anchors.fill: parent
                period: shellRoot.aiUsagePeriod
                status: shellRoot.aiUsageStatus
                errorCode: shellRoot.aiUsageError
                 loading: shellRoot.aiUsageLoading
                 refreshQueued: shellRoot.aiUsageRefreshQueued
                 providers: shellRoot.aiUsageProviders
                 lastKnownGoodProviders: shellRoot.lastKnownGoodProviders
                 lastGoodPeriod: shellRoot.aiUsageLastGoodPeriod
                 lastCompletedAt: shellRoot.aiUsageLastCompletedAt
                 lastCompletedPeriod: shellRoot.aiUsageLastCompletedPeriod
                 lastCompletedStatus: shellRoot.aiUsageLastCompletedStatus
                  authBusy: shellRoot.aiProviderAuthBusy
                  authProvider: shellRoot.aiProviderAuthProvider
                  authAction: shellRoot.aiProviderAuthAction
                  authStatus: shellRoot.aiProviderAuthStatus
                    anchorWidth: aiUsageWin.anchorWidth
                  unfoldProgress: shellRoot.aiUsageUnfoldProgress
                  neckOffset: aiUsageWin.screenAnchorX - (aiUsageWin.x + aiUsageWin.width / 2)
                  onRefreshRequested: shellRoot.refreshAiUsage()
                  onPeriodSelected: shellRoot.setAiUsagePeriod(selectedPeriod)
                  onProviderAuthRequested: shellRoot.invokeAiProviderAuth(providerId, action)
             }
        }
    }

    // ── OSD overlay (volume/brightness, right edge, one per monitor) ──
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: osdWin
            property var modelData
            property string monitorName: modelData.name
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
            property string monitorName: modelData.name
            screen: modelData
            visible: (audioManagerVisible || amAnimating) && monitorName === audioManagerMonitor
            anchors.top: true; anchors.left: true
            
            // Coordenada X global del ancla (16px de margen de la barra + posición local del módulo)
            property var monitorAnchor: shellRoot.anchors[monitorName]
            property real worldAnchorX: 16 + (monitorAnchor ? monitorAnchor.mpris : 0)
            property real anchorWidth: monitorAnchor ? monitorAnchor.mprisWidth : 200
            
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
            property string monitorName: modelData.name
            screen: modelData
            visible: (superF2Visible || f2Animating) && monitorName === superF2Monitor
            anchors.top: true; anchors.left: true
            
            // Coordenada X global del reloj
            property var monitorAnchor: shellRoot.anchors[monitorName]
            property real worldClockX: 16 + (monitorAnchor ? monitorAnchor.clock : 0)
            property real clockWidth: monitorAnchor ? monitorAnchor.clockWidth : 350

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
            property string monitorName: modelData.name
            screen: modelData
            visible: (btVisible || btAnimating) && monitorName === btMonitor
            
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
            property string monitorName: modelData.name
            screen: modelData
            visible: (wallpaperVisible || wpAnimating) && monitorName === wallpaperMonitor
            
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
            property string monitorName: modelData.name
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
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: dm.active ? implicitHeight : 0
            
            WlrLayershell.keyboardFocus: dm.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            
            color: "transparent"
            
            DockManager { 
                id: dm
                anchors.fill: parent 
                externalActive: (dockVisible && monitorName === dockMonitor)
            }
        }
    }
}
