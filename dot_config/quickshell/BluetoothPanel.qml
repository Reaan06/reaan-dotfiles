import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "components"

Item {
    id: root
    RuntimePaths { id: runtimePaths }

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

    Behavior on cBg { ColorAnimation { duration: 600 } }
    Behavior on cBlue { ColorAnimation { duration: 600 } }
    Behavior on cMauve { ColorAnimation { duration: 600 } }
    Behavior on cGreen { ColorAnimation { duration: 600 } }
    Behavior on cText { ColorAnimation { duration: 600 } }
    Behavior on cSub { ColorAnimation { duration: 600 } }
    Behavior on cSurface { ColorAnimation { duration: 600 } }

    function parsePalette(raw) {
        if (!raw || raw.length === 0) return
        var parts = raw.split(" ")
        if (parts.length < 8) return
        try {
            var pc = parts[0]
            if (pc && pc.startsWith("#") && pc.length >= 7) {
                var r = parseInt(pc.substr(1,2),16)/255
                var g = parseInt(pc.substr(3,2),16)/255
                var b = parseInt(pc.substr(5,2),16)/255
                cBg      = Qt.rgba(r, g, b, 0.90)
                cSurface = Qt.rgba(r + 0.05, g + 0.05, b + 0.05, 0.12)
            }
            cBlue   = parts[1] || cBlue
            cGreen  = parts[2] || cGreen
            cMauve  = parts[3] || cMauve
            cText   = parts[6] || cText
            cSub    = parts[7] || cSub
        } catch (e) { console.log("Error parsing palette in BluetoothPanel: " + e) }
    }

    Process {
        id: paletteProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/.palette 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { root.parsePalette(text.trim()) } }
    }
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: paletteProc.running = true }

    function syncGraphTheme() {
        if (!graphLoader.item) return
        graphLoader.item.scale = root.scale
        graphLoader.item.font = root.font
        graphLoader.item.accentColor = root.currentTab === "wifi" ? root.cBlue : root.cMauve
        graphLoader.item.cBg = root.cBg
        graphLoader.item.cText = root.cText
        graphLoader.item.cSub = root.cSub
        graphLoader.item.cSurface = root.cSurface
    }

    Connections {
        target: root
        function onCurrentTabChanged() { syncGraphTheme() }
    }

    // State
    property string currentTab: "wifi"

    // UI Layout
    Rectangle {
        id: container
        anchors.fill: parent
        radius: 32 * root.scale; color: root.cBg
        border.color: Qt.rgba(1,1,1,0.1); border.width: 1.2 * root.scale

        opacity: root.active ? 1.0 : 0.0
        scale: root.active ? 1.0 : 0.98
        Behavior on opacity { NumberAnimation { duration: 350 } }
        Behavior on scale { NumberAnimation { duration: 350; easing.type: Easing.OutBack } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 32 * root.scale
            spacing: 24 * root.scale

            // ── Header ──
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 0
                    Text { 
                        text: root.currentTab.toUpperCase() + " MANAGER"
                        font.family: root.font; font.pixelSize: 22 * root.scale; font.bold: true; color: root.cText 
                    }
                    Text { 
                        text: "Gestión de red interactiva"; font.family: root.font; font.pixelSize: 12 * root.scale; color: root.cSub 
                    }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 44 * root.scale; height: 44 * root.scale; radius: 14 * root.scale; color: root.cSurface
                    Text { anchors.centerIn: parent; text: "󰅖"; font.family: root.font; font.pixelSize: 18 * root.scale; color: root.cText }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { 
                            mProc.command = ["sh", "-c", "printf 'hidden\\n' > \"$1\"", "qs-bt-hide", runtimePaths.runtimeDir + "/qs-bt-panel"]
                            mProc.running = true 
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1.5 * root.scale; color: Qt.rgba(1,1,1,0.08) }

            // ── Main Content Area ──
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                Loader {
                    id: graphLoader
                    anchors.fill: parent
                    source: root.currentTab === "wifi" ? "WifiGraph.qml" : "BluetoothGraph.qml"

                    onLoaded: syncGraphTheme()

                    Binding {
                        target: graphLoader.item
                        property: "scale"
                        value: root.scale
                        when: graphLoader.status === Loader.Ready && graphLoader.item
                    }
                    Binding {
                        target: graphLoader.item
                        property: "font"
                        value: root.font
                        when: graphLoader.status === Loader.Ready && graphLoader.item
                    }
                    Binding {
                        target: graphLoader.item
                        property: "accentColor"
                        value: root.currentTab === "wifi" ? root.cBlue : root.cMauve
                        when: graphLoader.status === Loader.Ready && graphLoader.item
                    }
                    Binding {
                        target: graphLoader.item
                        property: "cBg"
                        value: root.cBg
                        when: graphLoader.status === Loader.Ready && graphLoader.item
                    }
                    Binding {
                        target: graphLoader.item
                        property: "cText"
                        value: root.cText
                        when: graphLoader.status === Loader.Ready && graphLoader.item
                    }
                    Binding {
                        target: graphLoader.item
                        property: "cSub"
                        value: root.cSub
                        when: graphLoader.status === Loader.Ready && graphLoader.item
                    }
                    Binding {
                        target: graphLoader.item
                        property: "cSurface"
                        value: root.cSurface
                        when: graphLoader.status === Loader.Ready && graphLoader.item
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1.5 * root.scale; color: Qt.rgba(1,1,1,0.08) }

            // ── Tabs (Bottom) ──
            RowLayout {
                Layout.fillWidth: true; spacing: 16 * root.scale
                
                Repeater {
                    model: [
                        { id: "wifi", name: "WIFI", icon: "󰖩", accent: root.cBlue },
                        { id: "bluetooth", name: "BLUETOOTH", icon: "󰂯", accent: root.cMauve }
                    ]
                    
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 54 * root.scale; radius: 16 * root.scale
                        color: root.currentTab === modelData.id ? modelData.accent : root.cSurface
                        
                        Row {
                            anchors.centerIn: parent; spacing: 10 * root.scale
                            Text { 
                                text: modelData.icon; font.family: root.font; font.pixelSize: 18 * root.scale
                                color: root.currentTab === modelData.id ? "#11111b" : modelData.accent
                            }
                            Text { 
                                text: modelData.name; font.family: root.font; font.pixelSize: 13 * root.scale; font.bold: true
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
