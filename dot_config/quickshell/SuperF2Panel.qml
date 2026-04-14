import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string font: "JetBrains Mono Nerd Font"
    
    property color cBg: Qt.rgba(0.07, 0.07, 0.1, 0.98)
    property color cMauve: "#cba6f7"
    property color cBlue: "#89b4fa"
    property color cGreen: "#a6e3a1"
    property color cText: "#cdd6f4"
    property color cSub: "#6c7086"
    property color cSurface: Qt.rgba(1, 1, 1, 0.05)

    // ── State ──
    property string currentTab: "WeatherCalendarView.qml"   // "SystemMonitor.qml" | "WeatherCalendarView.qml" | "github"
    property bool isGithubTab: currentTab === "github"

    // ── GitHub Manager (shared across views) ──
    GitHubManager { id: ghManager }

    Rectangle {
        id: container
        anchors.fill: parent; radius: 40; color: root.cBg
        border.color: Qt.rgba(1,1,1,0.08); border.width: 1

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 40; spacing: 24

            // ── Header ──
            RowLayout {
                Layout.fillWidth: true; spacing: 20
                Row {
                    spacing: 12
                    Rectangle { width: 48; height: 48; radius: 14; color: root.cMauve
                        Text { anchors.centerIn: parent; text: "󰍛"; font.pixelSize: 24; color: "#11111b" }
                    }
                    ColumnLayout {
                        spacing: 0
                        Text { text: "DASHBOARD"; font.family: root.font; font.pixelSize: 20; font.bold: true; color: root.cText }
                        Text { text: "System Overview & Monitoring"; font.family: root.font; font.pixelSize: 12; color: root.cSub }
                    }
                }
                Item { Layout.fillWidth: true }
                
                // GitHub connection indicator dot
                Rectangle {
                    width: 10; height: 10; radius: 5
                    color: ghManager.connected ? root.cGreen : root.cSub
                    opacity: ghManager.connected ? 1 : 0.4
                    Behavior on color { ColorAnimation { duration: 300 } }

                    MouseArea {
                        id: ghDotMA; anchors.fill: parent; hoverEnabled: true
                    }
                    ToolTip.visible: ghDotMA.containsMouse
                    ToolTip.text: ghManager.connected ? "GitHub: " + ghManager.profile.login : "GitHub: Not connected"
                }

                // Close button
                Rectangle {
                    width: 44; height: 44; radius: 14; color: root.cSurface
                    Text { anchors.centerIn: parent; text: "󰅖"; font.family: root.font; font.pixelSize: 18; color: root.cText }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            mProc.command = ["sh", "-c", "echo 'hidden' > ${XDG_RUNTIME_DIR:-/tmp}/qs-super-f2"]
                            mProc.running = true
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1,1,1,0.06) }

            // ── Content Area ──
            Item {
                id: contentArea
                Layout.fillWidth: true; Layout.fillHeight: true

                // Loader for SystemMonitor and WeatherCalendar views
                Loader {
                    id: mainLoader
                    anchors.fill: parent
                    active: !root.isGithubTab
                    visible: active
                    source: root.isGithubTab ? "" : root.currentTab
                    onStatusChanged: {
                        if (status == Loader.Error) console.log("Loader ERROR: " + sourceError)
                    }
                }

                // GitHub Linking View (shown when GitHub tab active + not connected)
                GitHubLinkingView {
                    anchors.fill: parent
                    ghManager: ghManager
                    visible: root.isGithubTab && !ghManager.connected
                }

                // GitHub Dashboard View (shown when GitHub tab active + connected)
                GitHubDashboardView {
                    anchors.fill: parent
                    ghManager: ghManager
                    visible: root.isGithubTab && ghManager.connected
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1,1,1,0.06) }

            // ── Tab Bar ──
            RowLayout {
                Layout.fillWidth: true; spacing: 16; Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: [
                        { name: "SYSTEM",  icon: "󰍛", tab: "SystemMonitor.qml" },
                        { name: "CLIMA",   icon: "󰖐", tab: "WeatherCalendarView.qml" },
                        { name: "GITHUB",  icon: "󰊤", tab: "github" }
                    ]

                    Rectangle {
                        id: tabBtn
                        Layout.preferredWidth: 160; Layout.preferredHeight: 50; radius: 16

                        property bool isActive: root.currentTab === modelData.tab

                        color: isActive ? root.cMauve : root.cSurface
                        Behavior on color { ColorAnimation { duration: 200 } }
                        
                        Row {
                            anchors.centerIn: parent; spacing: 10
                            Text { 
                                text: modelData.icon; font.family: root.font; font.pixelSize: 18
                                color: tabBtn.isActive ? "#11111b" : root.cMauve
                            }
                            Text {
                                text: modelData.name; font.family: root.font; font.pixelSize: 13; font.bold: true
                                color: tabBtn.isActive ? "#11111b" : root.cText
                            }
                            // Connected dot on GitHub tab
                            Rectangle {
                                width: 7; height: 7; radius: 3.5
                                color: root.cGreen
                                visible: modelData.tab === "github" && ghManager.connected
                                anchors.verticalCenter: parent.verticalCenter
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
    Process { id: mProc }
}
