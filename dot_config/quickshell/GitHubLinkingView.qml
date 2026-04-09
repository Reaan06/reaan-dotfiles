import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    objectName: "GitHubLinkingView.qml"
    
    readonly property string font: "JetBrains Mono Nerd Font"
    property color cMauve: "#cba6f7"
    property color cText: "#cdd6f4"
    property color cSub: "#6c7086"
    property color cBg: Qt.rgba(1, 1, 1, 0.03)

    ColumnLayout {
        anchors.centerIn: parent; spacing: 40; width: parent.width * 0.6

        ColumnLayout {
            spacing: 12; Layout.alignment: Qt.AlignHCenter
            Rectangle { width: 80; height: 80; radius: 24; color: root.cMauve; Layout.alignment: Qt.AlignHCenter
                Text { anchors.centerIn: parent; text: "󰊤"; font.pixelSize: 40; color: "#11111b" }
            }
            Text {
                text: "GITHUB CONNECTION"; font.family: root.font; font.pixelSize: 26; font.bold: true
                color: root.cMauve; Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: "Connect your GitHub account to enable real-time tracking of commits, PRs, and repository activity directly on your dashboard."; font.family: root.font; font.pixelSize: 14
                color: root.cSub; Layout.alignment: Qt.AlignHCenter; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; Layout.fillWidth: true
            }
        }

        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 64; radius: 20; color: root.cBg
            border.color: Qt.rgba(1,1,1,0.08); border.width: 1
            
            RowLayout {
                anchors.fill: parent; anchors.margins: 4
                Rectangle { width: 56; height: 56; radius: 16; color: Qt.rgba(1,1,1,0.03)
                    Text { anchors.centerIn: parent; text: "󰊤"; font.pixelSize: 20; color: root.cSub }
                }
                TextInput {
                    id: userIn; Layout.fillWidth: true; Layout.leftMargin: 10; Layout.rightMargin: 20
                    verticalAlignment: TextInput.AlignVCenter; font.family: root.font; font.pixelSize: 16
                    color: root.cText; cursorVisible: true; selectByMouse: true
                    
                    Text {
                        text: "Enter your GitHub username or token..."; font.family: root.font; font.pixelSize: 16
                        color: root.cSub; opacity: 0.5; visible: !userIn.text && !userIn.focus; anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 20
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 60; radius: 20; color: root.cMauve
                Text { anchors.centerIn: parent; text: "CONNECT ACCOUNT"; font.family: root.font; font.pixelSize: 14; font.bold: true; color: "#11111b" }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: console.log("Connecting " + userIn.text)
                }
            }
            Rectangle {
                Layout.preferredWidth: 160; Layout.preferredHeight: 60; radius: 20; color: root.cBg; border.color: Qt.rgba(1,1,1,0.06)
                Text { anchors.centerIn: parent; text: "CANCEL"; font.family: root.font; font.pixelSize: 14; font.bold: true; color: root.cText }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: userIn.text = "" }
            }
        }
        
        Item { Layout.preferredHeight: 20 }
    }
}
