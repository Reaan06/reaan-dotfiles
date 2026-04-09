import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Super F2 Panel — Reimagined Modern UI (Ultra Stable)
Item {
    id: root

    readonly property string font: "JetBrains Mono Nerd Font"
    
    // Theme - Catppuccin Mocha inspired
    property color cBg: Qt.rgba(0.07, 0.07, 0.1, 0.98)
    property color cMauve: "#cba6f7"
    property color cBlue: "#89b4fa"
    property color cText: "#cdd6f4"
    property color cSub: "#6c7086"
    property color cSurface: Qt.rgba(1, 1, 1, 0.05)

    Rectangle {
        id: container
        anchors.fill: parent; radius: 40; color: root.cBg
        border.color: Qt.rgba(1,1,1,0.08); border.width: 1

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 40; spacing: 24

            // Top Header
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
                
                // Close Button
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

            // Main Content Area
            Loader {
                id: mainLoader
                Layout.fillWidth: true; Layout.fillHeight: true
                source: "/home/reaan/reaan-dotfiles/dot_config/quickshell/WeatherCalendarView.qml"
                onStatusChanged: {
                    if (status == Loader.Error) console.log("CRITICAL: Loader error: " + source + " -> " + sourceError)
                    else if (status == Loader.Ready) console.log("SUCCESS: Loaded " + source)
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1,1,1,0.06) }

            // Navigation Bar
            RowLayout {
                Layout.fillWidth: true; spacing: 16; Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: [
                        { name: "SYSTEM", icon: "󰍛", file: "SystemMonitor.qml" },
                        { name: "CLIMA", icon: "󰖐", file: "WeatherCalendarView.qml" },
                        { name: "GITHUB", icon: "󰊤", file: "GitHubLinkingView.qml" }
                    ]
                    Rectangle {
                        Layout.preferredWidth: 160; Layout.preferredHeight: 50; radius: 16
                        color: mainLoader.source.toString().includes(modelData.file) ? root.cMauve : root.cSurface
                        
                        Row {
                            anchors.centerIn: parent; spacing: 10
                            Text { 
                                text: modelData.icon; font.family: root.font; font.pixelSize: 18
                                color: mainLoader.source.toString().includes(modelData.file) ? "#11111b" : root.cMauve
                            }
                            Text {
                                text: modelData.name; font.family: root.font; font.pixelSize: 13; font.bold: true
                                color: mainLoader.source.toString().includes(modelData.file) ? "#11111b" : root.cText
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: mainLoader.source = Qt.resolvedUrl(modelData.file)
                        }
                    }
                }
            }
        }
    }
    Process { id: mProc }
}
