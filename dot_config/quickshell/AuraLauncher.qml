import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/**
 * AuraLauncher.qml
 * Compact but generous application launcher.
 */
FocusScope {
    id: root
    property bool active: false
    property var allApps: []
    property var pinnedApps: []
    property var activeApps: ({})
    property var usageData: ({})
    property var hiddenApps: []
    property string filter: ""
    
    focus: root.active

    onActiveChanged: {
        if (active) {
            focusTimer.start();
        } else {
            searchInput.text = "";
            root.filter = "";
        }
    }

    Timer {
        id: focusTimer
        interval: 10
        onTriggered: {
            appGrid.currentIndex = 0;
            appGrid.forceActiveFocus();
        }
    }

    function launchApp(model) {
        if (!model) return;
        var appClass = model.class || model.name;
        if (root.activeApps[appClass]) {
            focusProcess.command = ["/usr/bin/hyprctl", "dispatch", "focuswindow", appClass];
            focusProcess.running = true;
        } else {
            var cmd = ["sh", "-c", "/usr/bin/hyprctl dispatch exec " + appClass + " || " + model.exec + " &"];
            execApp.command = cmd;
            execApp.running = true;
        }
        root.active = false;
        hidePanelProc.command = ["sh", "-c", "~/.config/scripts/dock-toggle.sh hide"];
        hidePanelProc.running = true;
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
        pinProcess.command = ["sh", "-c", "python3 $HOME/.config/scripts/pin_app.py " + appClass];
        pinProcess.running = true;
    }
    
    // Modelo interno para evitar saltos de scroll
    ListModel { id: filteredModel }
    
    function updateModel() {
        var apps = Array.from(root.allApps);
        apps.sort(function(a, b) {
            var usageA = (root.usageData[a.class] || root.usageData[a.name] || {time: 0}).time || 0;
            var usageB = (root.usageData[b.class] || root.usageData[b.name] || {time: 0}).time || 0;
            return usageB - usageA;
        });

        var result = apps.filter(function(app) {
            var appClass = app.class || app.name;
            // Volver a ocultar si está fijada en el dock (el usuario cambió de opinión)
            if (root.pinnedApps.indexOf(appClass) !== -1) return false;
            
            if (!root.filter) return true;
            var f = root.filter.toLowerCase();
            return (app.name && app.name.toLowerCase().indexOf(f) !== -1) || 
                   (app.class && app.class.toLowerCase().indexOf(f) !== -1) ||
                   (app.exec && app.exec.toLowerCase().indexOf(f) !== -1);
        });

        // Actualización inteligente del modelo
        if (filteredModel.count !== result.length) {
            filteredModel.clear();
            for (var i = 0; i < result.length; i++) filteredModel.append(result[i]);
        } else {
            for (var j = 0; j < result.length; j++) {
                var current = filteredModel.get(j);
                if (current.name !== result[j].name) {
                    filteredModel.set(j, result[j]);
                }
            }
        }
        
        if (appGrid.currentIndex === -1 && filteredModel.count > 0) {
            appGrid.currentIndex = 0;
        }
    }

    onAllAppsChanged: updateModel()
    onPinnedAppsChanged: updateModel()
    onFilterChanged: updateModel()
    onUsageDataChanged: updateModel()
    
    Rectangle {
        anchors.fill: parent
        radius: 24; color: shellRoot.cPill
        border.color: Qt.rgba(1,1,1,0.1); border.width: 1
    }
    
    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : 0.95
    Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 40
        anchors.leftMargin: 25
        anchors.rightMargin: 25
        anchors.bottomMargin: 20
        spacing: 20
        
        // Search Bar
        TextField {
            id: searchInput
            Layout.fillWidth: true
            Layout.preferredHeight: 45
            placeholderText: "Buscar aplicaciones..."
            font.family: "JetBrains Mono Nerd Font"
            font.pixelSize: 14
            color: "white"
            verticalAlignment: TextInput.AlignVCenter
            leftPadding: 15
            placeholderTextColor: Qt.rgba(1,1,1,0.5)
            
            background: Rectangle { 
                radius: 12; 
                color: Qt.rgba(1,1,1,0.15)
                border.color: Qt.rgba(1,1,1,0.2)
                border.width: 1
            }
            onTextChanged: {
                root.filter = text.toLowerCase();
                appGrid.currentIndex = 0;
            }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Down) {
                    appGrid.forceActiveFocus();
                    appGrid.moveCurrentIndexDown();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (appGrid.count > 0) {
                        var idx = appGrid.currentIndex >= 0 ? appGrid.currentIndex : 0;
                        root.launchApp(filteredModel.get(idx));
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    root.active = false;
                    event.accepted = true;
                }
            }
        }
        
        // Info Text
        Text {
            Layout.fillWidth: true
            visible: appGrid.count === 0
            text: root.allApps.length === 0 ? "Cargando aplicaciones..." : "No se encontraron coincidencias"
            color: "#6c7086"
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 12
        }

        // App Grid
        GridView {
            id: appGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: 90
            cellHeight: 110
            
            model: filteredModel
            currentIndex: 0
            highlightFollowsCurrentItem: true
            keyNavigationEnabled: true
            focus: true

            Keys.onPressed: (event) => {
                var columns = Math.max(1, Math.floor(appGrid.width / appGrid.cellWidth));
                if (event.key === Qt.Key_Up && appGrid.currentIndex < columns) {
                    searchInput.forceActiveFocus();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (appGrid.currentIndex >= 0) {
                        root.launchApp(filteredModel.get(appGrid.currentIndex));
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Space) {
                    if (appGrid.currentIndex >= 0) {
                        var item = filteredModel.get(appGrid.currentIndex);
                        root.togglePin(item.class || item.name);
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    root.active = false;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Backspace) {
                    searchInput.forceActiveFocus();
                    if (searchInput.text.length > 0) {
                        searchInput.text = searchInput.text.substring(0, searchInput.text.length - 1);
                    }
                    event.accepted = true;
                } else if (event.text.length > 0 && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space && event.key !== Qt.Key_Escape && event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backspace) {
                    searchInput.forceActiveFocus();
                    searchInput.text += event.text;
                    event.accepted = true;
                }
            }
            
            delegate: Item {
                width: appGrid.cellWidth
                height: appGrid.cellHeight
                
                Rectangle {
                    id: appDelegate
                    anchors.centerIn: parent
                    width: 80; height: 100; radius: 12
                    
                    property bool isFocused: GridView.isCurrentItem
                    color: (ma.containsMouse || isFocused) ? Qt.rgba(1,1,1,0.15) : "transparent"
                    border.color: isFocused ? shellRoot.cMauve : "transparent"
                    border.width: isFocused ? 2 : 0
                    
                    readonly property string appClass: model.class || model.name
                    readonly property bool isPinned: root.pinnedApps.includes(appDelegate.appClass)
                    
                    MouseArea {
                        id: ma; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            root.launchApp(model);
                        }
                    }
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4
                        
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            
                            Image {
                                anchors.centerIn: parent
                                width: 42; height: 42
                                source: {
                                    var iconName = model.icon || "application-x-executable";
                                    // Prioridad absoluta a mapeos manuales correctos
                                    if (model.name === "Obsidian" || (model.class || "").toLowerCase() === "obsidian") iconName = "obsidian";
                                    // Sober usa ruta absoluta porque está en Flatpak fuera del tema de iconos
                                    if (model.name === "Sober" || iconName === "org.vinegarhq.Sober") 
                                        return "file:///var/lib/flatpak/appstream/flathub/x86_64/fe3c325c6b3b62554b14d1bc4e86ed91546c79a3795939ba8267336264a50a3a/icons/128x128/org.vinegarhq.Sober.png";
                                    
                                    if (iconName.startsWith("/")) return "file://" + iconName;
                                    return "image://icon/" + iconName;
                                }
                                fillMode: Image.PreserveAspectFit
                            }
                            
                            Rectangle {
                                anchors.top: parent.top; anchors.right: parent.right
                                width: 22; height: 22; radius: 11
                                color: appDelegate.isPinned ? shellRoot.cMauve : Qt.rgba(0,0,0,0.3)
                                border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                                visible: ma.containsMouse || appDelegate.isPinned || appDelegate.isFocused
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰐃"
                                    color: "white"
                                    font.pixelSize: 12
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        root.togglePin(appDelegate.appClass);
                                    }
                                }
                            }
                        }
                        
                        Text {
                            Layout.fillWidth: true
                            text: model.name
                            color: "white"
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
    
    Process { id: execApp }
    Process { id: pinProcess }
    Process { id: focusProcess }
    Process { id: hidePanelProc }
}
