import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "components"

// Super F2 Panel — Integrated Stats, Temp & GitHub
Item {
    id: root

    readonly property string font: "JetBrains Mono Nerd Font"
    
    // Theme (Matching AudioManager)
    property color cPill: Qt.rgba(0.08, 0.08, 0.12, 0.99)
    property color cMauve: "#cba6f7"
    property color cText: "#cdd6f4"
    property color cSub: "#6c7086"

    Rectangle {
        anchors.fill: parent; radius: 36; color: root.cPill
        border.color: Qt.rgba(1,1,1,0.06); border.width: 1

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 32; spacing: 20

            // Top Header
            RowLayout {
                Layout.fillWidth: true; spacing: 20
                Text {
                    text: "SUPER F2 PANEL"; font.family: root.font; font.pixelSize: 22; font.bold: true
                    color: root.cMauve; Layout.alignment: Qt.AlignVCenter
                }
                Item { Layout.fillWidth: true }
                // Close button mimic
                Rectangle {
                    width: 40; height: 40; radius: 12; color: Qt.rgba(1,1,1,0.06)
                    Text { anchors.centerIn: parent; text: "󰅖"; font.family: root.font; font.pixelSize: 18; color: root.cText }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Trigger toggle-off via script
                            mProc.command = ["~/.config/scripts/super-f2-toggle.sh", "hide"]
                            mProc.running = true
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1,1,1,0.04) }

            // Content Area (StackView replacement with simple toggle for now to avoid StackView overhead if not needed)
            // But StackView is more flexible for "next/prev" feel.
            StackView {
                id: stackView; Layout.fillWidth: true; Layout.fillHeight: true
                initialItem: "SystemMonitor.qml"
                clip: true
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1,1,1,0.04) }

            // Bottom Navigation (Mimic presets bar)
            RowLayout {
                Layout.fillWidth: true; spacing: 14; Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: [
                        { name: "SYSTEM", icon: "󰍛", source: "SystemMonitor.qml" },
                        { name: "TEMP", icon: "󰔏", source: "TemperatureHistoryView.qml" },
                        { name: "GITHUB", icon: "󰊤", source: "GitHubLinkingView.qml" }
                    ]
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 14
                        color: stackView.currentItem && stackView.currentItem.objectName === modelData.source ? root.cMauve : Qt.rgba(1,1,1,0.06)
                        Row {
                            anchors.centerIn: parent; spacing: 8
                            Text { 
                                text: modelData.icon; font.family: root.font; font.pixelSize: 16
                                color: stackView.currentItem && stackView.currentItem.objectName === modelData.source ? "#11111b" : root.cMauve
                            }
                            Text {
                                text: modelData.name; font.family: root.font; font.pixelSize: 13; font.bold: true
                                color: stackView.currentItem && stackView.currentItem.objectName === modelData.source ? "#11111b" : root.cText
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: stackView.replace(modelData.source)
                        }
                    }
                }
            }
        }
    }
    Process { id: mProc }
}
