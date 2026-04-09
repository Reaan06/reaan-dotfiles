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

    ColumnLayout {
        anchors.centerIn: parent; spacing: 24; width: parent.width * 0.7

        ColumnLayout {
            spacing: 8; Layout.alignment: Qt.AlignHCenter
            Text {
                text: "GITHUB CONNECTION"; font.family: root.font; font.pixelSize: 24; font.bold: true
                color: root.cMauve; Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: "Link your account to track activity and repositories"; font.family: root.font; font.pixelSize: 14
                color: root.cSub; Layout.alignment: Qt.AlignHCenter
            }
        }

        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 56; radius: 16; color: Qt.rgba(1,1,1,0.06)
            border.color: Qt.rgba(1,1,1,0.1); border.width: 1
            TextInput {
                id: userIn; anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 20
                verticalAlignment: TextInput.AlignVCenter; font.family: root.font; font.pixelSize: 16
                color: root.cText; cursorVisible: true; selectByMouse: true
                
                Text {
                    text: "Enter your GitHub username..."; font.family: root.font; font.pixelSize: 16
                    color: root.cSub; visible: !userIn.text && !userIn.focus; anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 16
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 50; radius: 14; color: root.cMauve
                Text { anchors.centerIn: parent; text: "CONNECT ACCOUNT"; font.family: root.font; font.pixelSize: 14; font.bold: true; color: "#11111b" }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: console.log("Connecting " + userIn.text)
                }
            }
            Rectangle {
                Layout.preferredWidth: 140; Layout.preferredHeight: 50; radius: 14; color: Qt.rgba(1,1,1,0.06)
                Text { anchors.centerIn: parent; text: "CANCEL"; font.family: root.font; font.pixelSize: 14; font.bold: true; color: root.cText }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: userIn.text = "" }
            }
        }
    }
}
