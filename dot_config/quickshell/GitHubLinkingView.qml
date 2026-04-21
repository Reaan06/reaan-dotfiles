import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// GitHubLinkingView: Connection screen utilizing GitHub CLI (gh)
// Spawns a terminal to authenticate via web and then fetches the data.

Item {
    id: root
    objectName: "GitHubLinkingView.qml"

    required property var ghManager

    readonly property string font: "JetBrains Mono Nerd Font"
    property color cMauve:   "#cba6f7"
    property color cBlue:    "#89b4fa"
    property color cGreen:   "#a6e3a1"
    property color cRed:     "#f38ba8"
    property color cYellow:  "#f9e2af"
    property color cText:    "#cdd6f4"
    property color cSub:     "#6c7086"
    property color cBg:      Qt.rgba(1, 1, 1, 0.03)

    property bool showError: root.ghManager.errorMessage !== ""
    property bool isLoggingIn: false

    Process {
        id: loginProc
        // This launches Kitty terminal to run gh auth login via web, extracts token/user and saves it.
        command: ["kitty", "--title", "GitHub Login", "-e", "bash", "-c", "echo 'Iniciando autenticación con GitHub...'; sleep 1; gh auth login -w -p https; echo 'Obteniendo usuario devuelto...'; token=$(gh auth token); user=$(gh api user -q .login); printf '%b\\n' \"$user\\n$token\" > ~/.config/quickshell/.github-config; chmod 600 ~/.config/quickshell/.github-config; echo '¡Autenticación completada! Puedes cerrar esta ventana.'; sleep 2"]
        onExited: {
            root.isLoggingIn = false
            root.ghManager.loadSavedConfig() // Recarga config una vez terminamos de hacer login
        }
    }

    ColumnLayout {
        anchors.centerIn: parent; spacing: 40; width: parent.width * 0.55

        // ── Header ──
        ColumnLayout {
            spacing: 14; Layout.alignment: Qt.AlignHCenter

            Rectangle {
                width: 88; height: 88; radius: 26; color: root.cMauve; Layout.alignment: Qt.AlignHCenter

                Text { anchors.centerIn: parent; text: "󰊤"; font.pixelSize: 44; color: "#11111b" }

                // Glow effect
                Rectangle {
                    anchors.fill: parent; anchors.margins: -6; radius: 30; color: "transparent"
                    border.color: Qt.rgba(root.cMauve.r, root.cMauve.g, root.cMauve.b, 0.2); border.width: 2
                }
            }

            Text {
                text: "GITHUB CONNECTION"
                font.family: root.font; font.pixelSize: 24; font.bold: true; font.letterSpacing: 2
                color: root.cMauve; Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Conecta tu cuenta de GitHub directamente desde tu navegador web.\nAl conectarte desbloquearás el historial de actividad, commits y repositorios."
                font.family: root.font; font.pixelSize: 13; lineHeight: 1.5
                color: root.cSub; Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; Layout.fillWidth: true
            }
        }

        // ── Info panel ──
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 70; radius: 16
            color: Qt.rgba(root.cBlue.r, root.cBlue.g, root.cBlue.b, 0.08)
            border.color: Qt.rgba(root.cBlue.r, root.cBlue.g, root.cBlue.b, 0.2)
            
            RowLayout {
                anchors.fill: parent; anchors.margins: 14; spacing: 14
                Text { text: "󰈈"; font.pixelSize: 22; color: root.cBlue }
                ColumnLayout {
                    spacing: 4; Layout.fillWidth: true
                    Text { text: "Autenticación Segura"; font.family: root.font; font.pixelSize: 12; font.bold: true; color: root.cBlue }
                    Text { 
                        text: "Serás redirigido a la web de GitHub de forma automática para autorizar la integración utilizando GitHub CLI." 
                        font.family: root.font; font.pixelSize: 11; color: root.cText; wrapMode: Text.WordWrap; Layout.fillWidth: true 
                    }
                }
            }
        }

        // ── Error message ──
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: errorRow.implicitHeight + 20; radius: 14
            color: Qt.rgba(root.cRed.r, root.cRed.g, root.cRed.b, 0.08)
            border.color: Qt.rgba(root.cRed.r, root.cRed.g, root.cRed.b, 0.2)
            visible: root.showError
            opacity: root.showError ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Row {
                id: errorRow; anchors.centerIn: parent; spacing: 10
                Text { text: "󰅚"; font.pixelSize: 16; color: root.cRed; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: root.ghManager.errorMessage; font.family: root.font; font.pixelSize: 12
                    color: root.cRed; anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // ── Action Buttons ──
        RowLayout {
            Layout.fillWidth: true; spacing: 16

            Rectangle {
                id: connectBtn; Layout.fillWidth: true; Layout.preferredHeight: 60; radius: 18
                color: root.isLoggingIn || root.ghManager.loading ? Qt.darker(root.cMauve, 1.3) : root.cMauve

                Row {
                    anchors.centerIn: parent; spacing: 12
                    Text {
                        text: (root.isLoggingIn || root.ghManager.loading) ? "󰑐" : "󰘍"
                        font.pixelSize: 20; color: "#11111b"; anchors.verticalCenter: parent.verticalCenter
                        RotationAnimation on rotation {
                            running: root.isLoggingIn || root.ghManager.loading
                            from: 0; to: 360; duration: 1000; loops: Animation.Infinite
                        }
                    }
                    Text {
                        text: root.isLoggingIn ? "ESPERANDO NAVEGADOR..." : (root.ghManager.loading ? "CONECTANDO..." : "CONNECT ACCOUNT")
                        font.family: root.font; font.pixelSize: 15; font.bold: true; color: "#11111b"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    enabled: !root.isLoggingIn && !root.ghManager.loading
                    onClicked: {
                        root.isLoggingIn = true
                        loginProc.running = true
                    }
                }
            }
        }

        Item { Layout.preferredHeight: 12 }
    }
}
