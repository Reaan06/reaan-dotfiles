import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/**
 * DockManager.qml
 * Main orchestration for the Antigravity Dock.
 */
FocusScope {
    id: root
    property bool active: false // Desplegado
    property bool externalActive: false
    
    onExternalActiveChanged: {
        if (externalActive) {
            root.active = true;
            showTimer.stop();
            hideTimer.stop();
        } else if (!isHovered && !launcherOpen) {
            root.active = false;
        }
    }

    property var pinnedApps: []
    property var hiddenApps: []
    property var activeApps: ({})
    property var rawUsage: ({})
    
    // Keyboard navigation
    property int focusedIndex: -1
    readonly property int totalItems: 1 + topAppsCount + pinnedApps.length + activeAppsCount
    property int topAppsCount: 0
    property int activeAppsCount: 0

    focus: true

    Keys.onPressed: (event) => {
        if (!root.active || launcher.active) return;
        
        if (event.key === Qt.Key_Left) {
            if (focusedIndex > 0) focusedIndex--;
            else focusedIndex = totalItems - 1;
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            if (focusedIndex < totalItems - 1) focusedIndex++;
            else focusedIndex = 0;
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            triggerIndex(focusedIndex);
            event.accepted = true;
        } else if (event.key === Qt.Key_Space) {
            togglePinAtIndex(focusedIndex);
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            root.hideDock();
            event.accepted = true;
        }
    }

    function hideDock() {
        root.active = false;
        mProc.command = ["sh", "-c", "~/.config/scripts/dock-toggle.sh hide"];
        mProc.running = true;
    }

    function triggerIndex(idx) {
        if (idx === 0) {
            launcher.active = !launcher.active;
            if (launcher.active) launcher.forceActiveFocus();
        } else {
            root.executeIndex(idx);
        }
    }

    signal executeIndex(int idx)
    signal pinIndex(int idx)

    onActiveChanged: {
        if (active) {
            focusedIndex = 0;
            root.forceActiveFocus();
        } else {
            focusedIndex = -1;
        }
    }

    onLauncherOpenChanged: {
        if (launcherOpen) {
            hideTimer.stop()
            root.active = true
            // Solicitar foco para la ventana del panel para permitir escritura
            if (root.Window.window) root.Window.window.requestActivate()
            launcher.forceActiveFocus()
        } else {
            if (!isHovered) hideTimer.start()
            root.forceActiveFocus()
        }
    }

    MouseArea {
        id: mouseCollector
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.launcherOpen ? (launcher.height + 200) : (root.active ? 120 : 10)
        hoverEnabled: true
        acceptedButtons: Qt.NoButton 
    }
    
    // Propiedades necesarias para la lógica del Dock
    property real dockWidth: dockBg.width
    property bool launcherOpen: launcher.active
    
    property color cBg: shellRoot.cPill
    
    // Top Apps logic (moved from StatusBar)
    ListModel { id: topAppsModel }
    Process {
        id: topAppsReader
        command: ["sh", "-c", "cat $HOME/.cache/app_usage.json 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim().length > 0) {
                    root.parseTopApps(text);
                } else {
                    // console.log("topAppsReader returned empty");
                }
            }
        }
    }
    Timer {
        interval: 30000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { topAppsReader.running = false; topAppsReader.running = true }
    }

    function parseTopApps(jsonStr) {
        try {
            if (!jsonStr || jsonStr.trim() === "") return
            var data = JSON.parse(jsonStr)
            var usage = data["weekly"] || data["monthly"] || data["daily"]
            if (!usage) return
            var sorted = []
            for (var key in usage) {
                if (key === "_total_" || key === "" || key.startsWith("_")) continue
                if (usage[key].time > 10) sorted.push({ name: key, time: usage[key].time })
            }
            sorted.sort(function(a, b) { return b.time - a.time })
            var top20 = sorted.slice(0, 20)
            var changed = (top20.length !== topAppsModel.count)
            if (!changed) {
                for (var i = 0; i < top20.length; i++) {
                    if (topAppsModel.get(i).name !== top20[i].name) { changed = true; break }
                }
            }
            if (changed) {
                topAppsModel.clear()
                for (var j = 0; j < top20.length; j++) {
                    var appName = top20[j].name;
                    var appIcon = appName.toLowerCase();
                    // Intentar buscar el icono real en allApps
                    for (var k = 0; k < root.allApps.length; k++) {
                        if (root.allApps[k].class === appName || root.allApps[k].name === appName) {
                            appIcon = root.allApps[k].icon;
                            break;
                        }
                    }
                    topAppsModel.append({ name: appName, time: top20[j].time, icon: appIcon });
                }
            }
            root.rawUsage = usage
            
            // Update counts for navigation
            updateNavigationCounts();
        } catch(e) { console.log("Dock topApps error: " + e) }
    }

    function updateNavigationCounts() {
        var tc = 0;
        for (var i = 0; i < topAppsModel.count; i++) {
            var item = topAppsModel.get(i)
            if (root.pinnedApps.indexOf(item.name) === -1 && root.hiddenApps.indexOf(item.name) === -1) {
                tc++;
                if (tc >= 7) break;
            }
        }
        root.topAppsCount = tc;
        
        var ac = Object.keys(root.activeApps).filter(a => {
            if (root.pinnedApps.includes(a)) return false;
            for (var i = 0; i < topAppsModel.count; i++) {
                if (topAppsModel.get(i).name === a) return false;
            }
            return true;
        }).length;
        root.activeAppsCount = ac;
    }

    onPinnedAppsChanged: updateNavigationCounts()
    onActiveAppsChanged: updateNavigationCounts()

    function togglePinAtIndex(idx) {
        root.pinIndex(idx);
    }

    Process { id: appLauncher }

    // Notch state
    property bool isHovered: mouseCollector.containsMouse
    
    onIsHoveredChanged: {
        if (isHovered) {
            hideTimer.stop()
            showTimer.start()
        } else {
            showTimer.stop()
            if (!root.launcherOpen) hideTimer.start()
        }
    }
    
    Timer { id: showTimer; interval: 50; onTriggered: root.active = true }
    Timer { id: hideTimer; interval: 1000; onTriggered: if (!root.launcherOpen && !root.isHovered) root.active = false }

    function loadPinned() {
        var path = Quickshell.env["HOME"] + "/.config/scripts/pinned_apps.json"
        try {
            var content = Quickshell.readFile(path)
            if (content) root.pinnedApps = JSON.parse(content)
        } catch(e) { root.pinnedApps = [] }
    }
    
    function loadHidden() {
        var path = Quickshell.env["HOME"] + "/.config/scripts/hidden_apps.json"
        try {
            var content = Quickshell.readFile(path)
            if (content) root.hiddenApps = JSON.parse(content)
        } catch(e) { root.hiddenApps = [] }
    }
    
    function togglePin(appClass) {
        var currentPinned = Array.from(root.pinnedApps);
        var idx = currentPinned.indexOf(appClass);
        if (idx === -1) {
            currentPinned.push(appClass);
        } else {
            currentPinned.splice(idx, 1);
        }
        root.pinnedApps = currentPinned; 
        pinProcess.command = ["sh", "-c", "python3 $HOME/.config/scripts/pin_app.py " + appClass]
        pinProcess.running = true
    }
    
    function toggleHide(appClass) {
        var currentHidden = Array.from(root.hiddenApps);
        var idx = currentHidden.indexOf(appClass);
        if (idx === -1) {
            currentHidden.push(appClass);
        } else {
            currentHidden.splice(idx, 1);
        }
        root.hiddenApps = currentHidden;
        hideProcess.command = ["sh", "-c", "python3 $HOME/.config/scripts/hide_app.py " + appClass]
        hideProcess.running = true
    }
    
    function getIconForClass(className) {
        if (!className) return "application-x-executable";
        var lowerClass = className.toLowerCase();
        
        // 1. Mapeos manuales exactos (Alta prioridad)
        if (lowerClass === "sober" || lowerClass === "org.vinegarhq.sober") 
            return "/var/lib/flatpak/appstream/flathub/x86_64/fe3c325c6b3b62554b14d1bc4e86ed91546c79a3795939ba8267336264a50a3a/icons/128x128/org.vinegarhq.Sober.png";
        if (lowerClass === "llauncher") return "legacy-launcher";
        if (lowerClass === "obsidian") return "obsidian";
        if (lowerClass === "obs") return "obs";

        // 2. Buscar coincidencia exacta en allApps
        for (var i = 0; i < root.allApps.length; i++) {
            var app = root.allApps[i];
            if ((app.class && app.class.toLowerCase() === lowerClass) || 
                (app.name && app.name.toLowerCase() === lowerClass)) {
                return app.icon;
            }
        }

        // 3. Búsqueda difusa (Solo como último recurso)
        for (var j = 0; j < root.allApps.length; j++) {
            var a = root.allApps[j];
            var appExec = (a.exec || "").toLowerCase();
            // Evitar coincidencias falsas con nombres cortos como "obs"
            if (appExec.indexOf(lowerClass) !== -1 && lowerClass.length > 3) {
                return a.icon;
            }
        }
        
        return lowerClass;
    }

    Process {
        id: dockBridge
        command: ["sh", "-c", "python3 $HOME/.config/scripts/dock_bridge.py"]
    }

    Process {
        id: dockStateReader
        command: ["sh", "-c", "cat /tmp/qs-dock-state.json 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim() === "") return;
                try {
                    var data = JSON.parse(text.trim())
                    var newPinned = data.pinned || []
                    var newActive = data.active || ({})
                    
                    if (JSON.stringify(root.pinnedApps) !== JSON.stringify(newPinned)) {
                        root.pinnedApps = newPinned
                    }
                    if (JSON.stringify(root.activeApps) !== JSON.stringify(newActive)) {
                        root.activeApps = newActive
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { 
            if (dockStateReader.running) dockStateReader.running = false;
            dockStateReader.running = true; 
        }
    }

    // Aura Launcher Data
    property var allApps: []
    Process {
        id: auraData
        command: ["sh", "-c", "python3 $HOME/.config/scripts/app_launcher_data.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim() === "") return;
                try { 
                    var parsed = JSON.parse(text.trim());
                    if (parsed && parsed.length > 0) {
                        root.allApps = parsed;
                        // console.log("AuraLauncher: Loaded " + parsed.length + " apps");
                    }
                } catch(e) {
                    // console.log("Error parsing apps: " + e);
                }
            }
        }
    }

    Component.onCompleted: {
        dockBridge.running = true
        auraData.running = true
        loadPinned()
        loadHidden()
    }

    // Visual Dock
    Rectangle {
        id: dockBg
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.active ? 16 : -height + 10
        anchors.horizontalCenter: parent.horizontalCenter
        
        height: 60; radius: 30; color: root.cBg
        border.color: Qt.rgba(1,1,1,0.08); border.width: 1
        
        width: contentRow.implicitWidth + 40
        
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        
        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: 12
            
            // Launcher Button
            Rectangle {
                width: 44; height: 44; radius: 22; color: Qt.rgba(1,1,1,0.05)
                property bool isFocused: root.focusedIndex === 0
                border.color: isFocused ? shellRoot.cMauve : "transparent"
                border.width: isFocused ? 2 : 0
                Text { anchors.centerIn: parent; text: "󰀻"; color: shellRoot.cMauve; font.pixelSize: 20 }
                MouseArea { anchors.fill: parent; onClicked: launcher.active = !launcher.active }
            }
            
            Rectangle { width: 1; height: 28; color: Qt.rgba(1,1,1,0.08) }
            
            // TOP APPS (Las más usadas)
            Repeater {
                model: {
                    var filtered = []
                    for (var i = 0; i < topAppsModel.count; i++) {
                        var item = topAppsModel.get(i)
                        // No mostrar si está fijada (para evitar duplicados) o si está oculta
                        if (root.pinnedApps.indexOf(item.name) === -1 && root.hiddenApps.indexOf(item.name) === -1) {
                            filtered.push(item)
                            if (filtered.length >= 7) break;
                        }
                    }
                    return filtered
                }
                DockItem {
                    id: topItem
                    name: modelData.name
                    iconName: modelData.icon
                    execCmd: modelData.name
                    isActive: !!root.activeApps[modelData.name]
                    appClass: modelData.name
                    isPinned: false // Son apps por uso
                    accentColor: shellRoot.cTeal
                    onPinToggled: root.toggleHide(appClass) // Para apps de uso, el botón las oculta
                    
                    isFocused: root.focusedIndex === (1 + index)
                    onActionExecuted: {
                        root.active = false;
                        mProc.command = ["sh", "-c", "~/.config/scripts/dock-toggle.sh hide"];
                        mProc.running = true;
                    }
                    
                    Connections {
                        target: root
                        function onExecuteIndex(idx) { if (idx === (1 + index)) topItem.triggerAction() }
                        function onPinIndex(idx) { if (idx === (1 + index)) root.toggleHide(appClass) }
                    }
                }
            }

            Rectangle { width: 1; height: 28; color: Qt.rgba(1,1,1,0.08); visible: root.topAppsCount > 0 }

            // Pinned & Active Apps
            Repeater {
                model: root.pinnedApps
                DockItem {
                    id: pinnedItem
                    appClass: modelData
                    iconName: root.getIconForClass(modelData)
                    execCmd: modelData
                    isActive: !!root.activeApps[modelData]
                    isPinned: true
                    accentColor: shellRoot.cBlue
                    onPinToggled: root.togglePin(appClass)
                    
                    isFocused: root.focusedIndex === (1 + root.topAppsCount + index)
                    onActionExecuted: {
                        root.active = false;
                        mProc.command = ["sh", "-c", "~/.config/scripts/dock-toggle.sh hide"];
                        mProc.running = true;
                    }
                    
                    Connections {
                        target: root
                        function onExecuteIndex(idx) { if (idx === (1 + root.topAppsCount + index)) pinnedItem.triggerAction() }
                        function onPinIndex(idx) { if (idx === (1 + root.topAppsCount + index)) root.togglePin(appClass) }
                    }
                }
            }

            Rectangle { 
                width: 1; height: 28; color: Qt.rgba(1,1,1,0.08)
                visible: root.pinnedApps.length > 0 && root.activeAppsCount > 0
            }

            Repeater {
                model: Object.keys(root.activeApps).filter(a => {
                    // Evitar duplicados si ya está en pinned o en top apps
                    if (root.pinnedApps.includes(a)) return false;
                    for (var i = 0; i < topAppsModel.count; i++) {
                        if (topAppsModel.get(i).name === a) return false;
                    }
                    return true;
                })
                DockItem {
                    id: activeItem
                    appClass: modelData
                    iconName: root.getIconForClass(modelData)
                    isActive: true
                    isPinned: false
                    accentColor: shellRoot.cMauve
                    onPinToggled: root.togglePin(appClass)
                    
                    isFocused: root.focusedIndex === (1 + root.topAppsCount + root.pinnedApps.length + index)
                    onActionExecuted: {
                        root.active = false;
                        mProc.command = ["sh", "-c", "~/.config/scripts/dock-toggle.sh hide"];
                        mProc.running = true;
                    }
                    
                    Connections {
                        target: root
                        function onExecuteIndex(idx) { if (idx === (1 + root.topAppsCount + root.pinnedApps.length + index)) activeItem.triggerAction() }
                        function onPinIndex(idx) { if (idx === (1 + root.topAppsCount + root.pinnedApps.length + index)) root.togglePin(appClass) }
                    }
                }
            }
        }
    }
    
    // Notch Indicador (más sutil)
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        width: 60; height: 3; radius: 1.5; color: Qt.rgba(1,1,1,0.2)
        opacity: root.active ? 0.0 : 0.8
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }
    
    
    AuraLauncher {
        id: launcher
        anchors.bottom: dockBg.top
        anchors.bottomMargin: 15
        anchors.horizontalCenter: parent.horizontalCenter
        width: 500; height: 400
        allApps: root.allApps
        pinnedApps: root.pinnedApps
        activeApps: root.activeApps
        usageData: root.rawUsage
        hiddenApps: root.hiddenApps
        
        onActiveChanged: {
            if (!active) {
                root.forceActiveFocus();
            }
        }
    }
    
    Process { id: pinProcess }
    Process { id: hideProcess }
    Process { id: focusProcess }
    Process { id: mProc }
}
