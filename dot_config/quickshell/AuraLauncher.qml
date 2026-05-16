import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/**
 * AuraLauncher.qml
 * Compact but generous application launcher.
 */
Rectangle {
    id: root
    property bool active: false
    property var allApps: []
    property var pinnedApps: []
    property var activeApps: ({})
    property var usageData: ({})
    property var hiddenApps: []
    property string filter: ""
    
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
    }

    onAllAppsChanged: updateModel()
    onPinnedAppsChanged: updateModel()
    onFilterChanged: updateModel()
    onUsageDataChanged: updateModel()
    
    radius: 24; color: shellRoot.cPill
    border.color: Qt.rgba(1,1,1,0.1); border.width: 1
    
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
            onTextChanged: root.filter = text.toLowerCase()
            
            Connections {
                target: root
                function onActiveChanged() {
                    if (root.active) {
                        searchInput.forceActiveFocus()
                    } else {
                        searchInput.text = ""
                        root.filter = ""
                    }
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
            
            delegate: Item {
                width: appGrid.cellWidth
                height: appGrid.cellHeight
                
                Rectangle {
                    id: appDelegate
                    anchors.centerIn: parent
                    width: 80; height: 100; radius: 12
                    color: ma.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
                    
                    readonly property string appClass: model.class || model.name
                    readonly property bool isPinned: root.pinnedApps.includes(appDelegate.appClass)
                    
                    MouseArea {
                        id: ma; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            var appClass = appDelegate.appClass
                            if (root.activeApps[appClass]) {
                                focusProcess.command = ["/usr/bin/hyprctl", "dispatch", "focuswindow", appClass]
                                focusProcess.running = true
                            } else {
                                var cmd = ["sh", "-c", "/usr/bin/hyprctl dispatch exec " + appClass + " || " + model.exec + " &"]
                                execApp.command = cmd; execApp.running = true
                            }
                            root.active = false
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
                                visible: ma.containsMouse || appDelegate.isPinned
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰐃"
                                    color: "white"
                                    font.pixelSize: 12
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        var appClass = appDelegate.appClass;
                                        // Pin instantáneo en la UI creando un NUEVO array
                                        var currentPinned = Array.from(root.pinnedApps);
                                        var idx = currentPinned.indexOf(appClass);
                                        if (idx === -1) {
                                            currentPinned.push(appClass);
                                        } else {
                                            currentPinned.splice(idx, 1);
                                        }
                                        root.pinnedApps = currentPinned; // Esto dispara la señal onPinnedAppsChanged
                                        
                                        pinProcess.command = ["sh", "-c", "python3 $HOME/.config/scripts/pin_app.py " + appClass]
                                        pinProcess.running = true
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
}
