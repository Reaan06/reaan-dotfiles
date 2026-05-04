import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import "components"

Item {
    id: root

    property bool active: false
    property real neckOffset: 0
    readonly property string font: "JetBrains Mono Nerd Font"
    
    // ═══════════════════════════════════════════════
    // THEME — 100% Dinámico con Animaciones
    // ═══════════════════════════════════════════════
    property color cBg:      Qt.rgba(0.07, 0.07, 0.1, 0.90)
    property color cMauve:   "#cba6f7"
    property color cBlue:    "#89b4fa"
    property color cGreen:   "#a6e3a1"
    property color cText:    "#cdd6f4"
    property color cSub:     "#6c7086"
    property color cSurface: Qt.rgba(1, 1, 1, 0.05)

    Behavior on cBg { ColorAnimation { duration: 600 } }
    Behavior on cMauve { ColorAnimation { duration: 600 } }
    Behavior on cBlue { ColorAnimation { duration: 600 } }
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
        } catch (e) {
            console.log("Error parsing palette in SuperF2Panel: " + e)
        }
    }

    Process {
        id: paletteProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/.palette 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { root.parsePalette(text.trim()) } }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: paletteProc.running = true }

    // ── State ──
    property string currentTab: "WeatherCalendarView.qml"
    property bool isGithubTab: currentTab === "github"

    GitHubManager { id: ghManager }

    // ── UI ──
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        opacity: root.active ? 1.0 : 0.0
        scale: root.active ? 1.0 : 0.99
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 350; easing.type: Easing.OutBack } }

        // Conector curvo centrado (alineado con Reloj/Clima)
        PanelConnector {
            Layout.alignment: Qt.AlignHCenter
            color: root.cBg
            barWidth: 350 // Ancho manual estable
            neckOffset: root.neckOffset
        }

        Rectangle {
            id: container
            Layout.fillWidth: true; 
            Layout.fillHeight: true; 
            radius: 40; color: root.cBg
            border.color: Qt.rgba(1,1,1,0.1); border.width: 1.5

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 40; spacing: 24

                // ── Header ──
                RowLayout {
                    Layout.fillWidth: true; spacing: 20
                    Row {
                        spacing: 12
                        Rectangle { width: 48; height: 48; radius: 14; color: root.cMauve
                            Text { anchors.centerIn: parent; text: "󰍛"; font.pixelSize: 24; color: "#11111b" }
                            Behavior on color { ColorAnimation { duration: 600 } }
                        }
                        ColumnLayout {
                            spacing: 0
                            Text { text: "DASHBOARD"; font.family: root.font; font.pixelSize: 20; font.bold: true; color: root.cText }
                            Text { text: "System Overview & Monitoring"; font.family: root.font; font.pixelSize: 12; color: root.cSub }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    
                    Rectangle {
                        width: 10; height: 10; radius: 5
                        color: ghManager.connected ? root.cGreen : root.cSub
                        Behavior on color { ColorAnimation { duration: 400 } }
                        MouseArea { id: ghDotMA; anchors.fill: parent; hoverEnabled: true }
                        ToolTip.visible: ghDotMA.containsMouse
                        ToolTip.text: ghManager.connected ? "GitHub: " + ghManager.profile.login : "GitHub: Not connected"
                    }

                    Rectangle {
                        width: 44; height: 44; radius: 14; color: root.cSurface
                        Text { anchors.centerIn: parent; text: "󰅖"; font.family: root.font; font.pixelSize: 18; color: root.cText }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { mProc.command = ["sh", "-c", "echo 'hidden' > ${XDG_RUNTIME_DIR:-/tmp}/qs-super-f2"]; mProc.running = true }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1,1,1,0.08) }

                // ── Content Area ──
                Item {
                    id: contentArea; Layout.fillWidth: true; Layout.fillHeight: true
                    Loader { id: mainLoader; anchors.fill: parent; active: !root.isGithubTab && root.currentTab !== "AppUsageView.qml"; visible: active; source: (root.isGithubTab || root.currentTab === "AppUsageView.qml") ? "" : root.currentTab }
                    GitHubLinkingView { anchors.fill: parent; ghManager: ghManager; visible: root.isGithubTab && !ghManager.connected }
                    GitHubDashboardView { anchors.fill: parent; ghManager: ghManager; visible: root.isGithubTab && ghManager.connected }
                    AppUsageView { anchors.fill: parent; visible: root.currentTab === "AppUsageView.qml" }
                }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1,1,1,0.08) }

                // ── Tab Bar ──
                RowLayout {
                    Layout.fillWidth: true; spacing: 16; Layout.alignment: Qt.AlignHCenter

                    Repeater {
                        model: [
                            { name: "SYSTEM",  icon: "󰍛", tab: "SystemMonitor.qml",      accent: root.cBlue },
                            { name: "CLIMA",   icon: "󰖐", tab: "WeatherCalendarView.qml", accent: root.cMauve },
                            { name: "GITHUB",  icon: "󰊤", tab: "github",                 accent: root.cGreen },
                            { name: "Uso de Apps", icon: "󰣆", tab: "AppUsageView.qml", accent: "#f38ba8" }
                        ]

                        Rectangle {
                            id: tabBtn
                            Layout.preferredWidth: 160; Layout.preferredHeight: 50; radius: 16
                            property bool isActive: root.currentTab === modelData.tab
                            
                            color: isActive ? modelData.accent : root.cSurface
                            border.color: isActive ? Qt.rgba(1,1,1,0.2) : "transparent"
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 500 } }
                            
                            Row {
                                anchors.centerIn: parent; spacing: 10
                                Text { 
                                    text: modelData.icon; font.family: root.font; font.pixelSize: 18
                                    color: tabBtn.isActive ? "#11111b" : modelData.accent
                                    Behavior on color { ColorAnimation { duration: 400 } }
                                }
                                Text {
                                    text: modelData.name; font.family: root.font; font.pixelSize: 13; font.bold: true
                                    color: tabBtn.isActive ? "#11111b" : root.cText
                                    Behavior on color { ColorAnimation { duration: 400 } }
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentTab = modelData.tab
                            }
                        }
                    }
                }
            }
        }
    }
    Process { id: mProc }
}
