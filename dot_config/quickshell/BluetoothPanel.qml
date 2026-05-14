import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "components"

Item {
    id: root

    property bool active: false
    property real neckOffset: 0
    property real anchorWidth: 350
    property real scale: 1.0
    readonly property string font: "JetBrains Mono Nerd Font"

    // ═══════════════════════════════════════════════
    // THEME (Sync with SuperF2Panel)
    // ═══════════════════════════════════════════════
    property color cBg:      Qt.rgba(0.07, 0.07, 0.1, 0.90)
    property color cBlue:    "#89b4fa"
    property color cMauve:   "#cba6f7"
    property color cGreen:   "#a6e3a1"
    property color cText:    "#cdd6f4"
    property color cSub:     "#6c7086"
    property color cSurface: Qt.rgba(1, 1, 1, 0.05)

    // State
    property string currentTab: "wifi"

    // UI Layout
    Rectangle {
        id: container
        anchors.fill: parent
        radius: 32; color: root.cBg
        border.color: Qt.rgba(1,1,1,0.1); border.width: 1.2

        opacity: root.active ? 1.0 : 0.0
        scale: root.active ? 1.0 : 0.98
        Behavior on opacity { NumberAnimation { duration: 350 } }
        Behavior on scale { NumberAnimation { duration: 350; easing.type: Easing.OutBack } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 20

            // ── Header ──
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 0
                    Text { 
                        text: root.currentTab.toUpperCase() + " MANAGER"
                        font.family: root.font; font.pixelSize: 22; font.bold: true; color: root.cText 
                    }
                    Text { 
                        text: "Gestión de red interactiva"; font.family: root.font; font.pixelSize: 12; color: root.cSub 
                    }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 40; height: 40; radius: 12; color: root.cSurface
                    Text { anchors.centerIn: parent; text: "󰅖"; font.family: root.font; font.pixelSize: 18; color: root.cText }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { 
                            mProc.command = ["sh", "-c", "echo 'hidden' > ${XDG_RUNTIME_DIR:-/tmp}/qs-bt-panel"]
                            mProc.running = true 
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1,1,1,0.08) }

            // ── Main Graph Area ──
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                Loader {
                    id: graphLoader
                    anchors.fill: parent
                    source: root.currentTab === "wifi" ? "WifiGraph.qml" : "BluetoothGraph.qml"
                    
                    onLoaded: {
                        if (item) {
                            item.accentColor = root.currentTab === "wifi" ? root.cBlue : root.cMauve
                            item.cBg = root.cBg
                            item.cText = root.cText
                            item.cSub = root.cSub
                            item.font = root.font
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1,1,1,0.08) }

            // ── Tabs (Bottom) ──
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                
                Repeater {
                    model: [
                        { id: "wifi", name: "WIFI", icon: "󰖩", accent: root.cBlue },
                        { id: "bluetooth", name: "BLUETOOTH", icon: "󰂯", accent: root.cMauve }
                    ]
                    
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 50; radius: 16
                        color: root.currentTab === modelData.id ? modelData.accent : root.cSurface
                        
                        Row {
                            anchors.centerIn: parent; spacing: 8
                            Text { 
                                text: modelData.icon; font.family: root.font; font.pixelSize: 18
                                color: root.currentTab === modelData.id ? "#11111b" : modelData.accent
                            }
                            Text { 
                                text: modelData.name; font.family: root.font; font.pixelSize: 13; font.bold: true
                                color: root.currentTab === modelData.id ? "#11111b" : root.cText
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentTab = modelData.id
                        }
                    }
                }
            }
        }
    }
    Process { id: mProc }
}
