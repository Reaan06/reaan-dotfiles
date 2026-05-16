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
    property string filter: ""
    
    radius: 24; color: shellRoot.cPill
    border.color: Qt.rgba(1,1,1,0.1); border.width: 1
    
    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : 0.9
    Behavior on opacity { NumberAnimation { duration: 300 } }
    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
    
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
            
            model: {
                if (!root.filter) return root.allApps;
                return root.allApps.filter(function(app) {
                    var f = root.filter.toLowerCase();
                    var nameMatch = app.name && app.name.toLowerCase().indexOf(f) !== -1;
                    var classMatch = app.class && app.class.toLowerCase().indexOf(f) !== -1;
                    var execMatch = app.exec && app.exec.toLowerCase().indexOf(f) !== -1;
                    return nameMatch || classMatch || execMatch;
                });
            }
            
            delegate: Item {
                width: appGrid.cellWidth
                height: appGrid.cellHeight
                
                Rectangle {
                    id: appDelegate
                    anchors.centerIn: parent
                    width: 80; height: 100; radius: 12
                    color: ma.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
                    
                    readonly property string appClass: modelData.class || modelData.name
                    readonly property bool isPinned: root.pinnedApps.includes(appDelegate.appClass)
                    
                    MouseArea {
                        id: ma; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            var appClass = appDelegate.appClass
                            if (root.activeApps[appClass]) {
                                focusProcess.command = ["/usr/bin/hyprctl", "dispatch", "focuswindow", appClass]
                                focusProcess.running = true
                            } else {
                                var cmd = ["sh", "-c", "/usr/bin/hyprctl dispatch exec " + appClass + " || " + modelData.exec + " &"]
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
                                source: "image://icon/" + (modelData.icon || "application-x-executable")
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
                                        pinProcess.command = ["sh", "-c", "python3 /home/reaan/reaan-dotfiles/dot_config/scripts/pin_app.py " + appDelegate.appClass]
                                        pinProcess.running = true
                                    }
                                }
                            }
                        }
                        
                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
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
