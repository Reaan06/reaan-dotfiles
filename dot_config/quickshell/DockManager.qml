import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/**
 * DockManager.qml
 * Main orchestration for the Antigravity Dock.
 */
Item {
    id: root
    property bool active: false // Desplegado
    property var pinnedApps: []
    property var activeApps: ({})
    
    MouseArea {
        id: mouseCollector
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.launcherOpen ? (launcher.height + 200) : 120
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
        command: ["sh", "-c", "cat /home/reaan/.cache/app_usage.json 2>/dev/null || echo '{}'"]
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
            var daily = data["daily"]
            if (!daily) return
            var sorted = []
            for (var key in daily) {
                if (key === "_total_" || key === "" || key.startsWith("_")) continue
                if (daily[key].time > 10) sorted.push({ name: key, time: daily[key].time })
            }
            sorted.sort(function(a, b) { return b.time - a.time })
            var top7 = sorted.slice(0, 7)
            var changed = (top7.length !== topAppsModel.count)
            if (!changed) {
                for (var i = 0; i < top7.length; i++) {
                    if (topAppsModel.get(i).name !== top7[i].name) { changed = true; break }
                }
            }
            if (changed) {
                topAppsModel.clear()
                for (var j = 0; j < top7.length; j++) topAppsModel.append(top7[j])
            }
        } catch(e) { console.log("Dock topApps error: " + e) }
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
    
    // Mantener activo si el launcher está abierto
    onLauncherOpenChanged: {
        if (launcherOpen) {
            hideTimer.stop()
            root.active = true
            // Solicitar foco para la ventana del panel para permitir escritura
            if (root.Window.window) root.Window.window.requestActivate()
        } else {
            if (!isHovered) hideTimer.start()
        }
    }
    
    Timer { id: showTimer; interval: 50; onTriggered: root.active = true }
    Timer { id: hideTimer; interval: 1000; onTriggered: if (!root.launcherOpen && !root.isHovered) root.active = false }

    Process {
        id: dockBridge
        command: ["sh", "-c", "python3 /home/reaan/reaan-dotfiles/dot_config/scripts/dock_bridge.py"]
    }

    Process {
        id: dockStateReader
        command: ["sh", "-c", "cat /tmp/qs-dock-state.json 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim() === "") return;
                try {
                    var data = JSON.parse(text.trim())
                    root.pinnedApps = data.pinned || []
                    root.activeApps = data.active || ({})
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
        command: ["sh", "-c", "python3 /home/reaan/reaan-dotfiles/dot_config/scripts/app_launcher_data.py"]
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
        
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        
        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: 12
            
            // Launcher Button
            Rectangle {
                width: 44; height: 44; radius: 22; color: Qt.rgba(1,1,1,0.05)
                Text { anchors.centerIn: parent; text: "󰀻"; color: shellRoot.cMauve; font.pixelSize: 20 }
                MouseArea { anchors.fill: parent; onClicked: launcher.active = !launcher.active }
            }
            
            Rectangle { width: 1; height: 28; color: Qt.rgba(1,1,1,0.08) }
            
            // TOP APPS (Las más usadas)
            Repeater {
                model: topAppsModel
                DockItem {
                    name: model.name
                    iconName: model.name.toLowerCase()
                    execCmd: model.name
                    isActive: !!root.activeApps[model.name]
                    appClass: model.name
                    accentColor: shellRoot.cTeal
                }
            }

            Rectangle { width: 1; height: 28; color: Qt.rgba(1,1,1,0.08); visible: topAppsModel.count > 0 }

            // Pinned & Active Apps
            Repeater {
                model: root.pinnedApps
                DockItem {
                    appClass: modelData
                    iconName: modelData.toLowerCase()
                    execCmd: modelData
                    isActive: !!root.activeApps[modelData]
                    isPinned: true
                    accentColor: shellRoot.cBlue
                }
            }

            Rectangle { 
                width: 1; height: 28; color: Qt.rgba(1,1,1,0.08)
                visible: root.pinnedApps.length > 0 && Object.keys(root.activeApps).filter(a => !root.pinnedApps.includes(a)).length > 0
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
                    appClass: modelData
                    iconName: modelData.toLowerCase()
                    isActive: true
                    isPinned: false
                    accentColor: shellRoot.cMauve
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
    }
}
