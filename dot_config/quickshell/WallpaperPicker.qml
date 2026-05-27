import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "components"

Rectangle {
    id: root
    property bool active: false
    property var wallpapers: []
    
    color: Qt.rgba(shellRoot.cPill.r, shellRoot.cPill.g, shellRoot.cPill.b, 0.85)
    radius: 32; border.color: Qt.rgba(1,1,1,0.1); border.width: 1

    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : 0.98
    visible: opacity > 0

    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

    Timer {
        interval: 5000
        running: root.active
        repeat: true
        onTriggered: listProc.running = true
    }

    Process {
        id: listProc
        command: ["python3", "/home/reaan/.config/scripts/wallpaper_bridge.py", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.wallpapers = JSON.parse(text.trim())
                } catch (e) { console.log("Wallpaper list error: " + e) }
            }
        }
    }
    
    onActiveChanged: if (active) listProc.running = true

    Process { id: applyProc }
    Process { id: hideProc }
    
    Process {
        id: uploadProc
        onExited: listProc.running = true
    }

    Connections {
        target: root
        function onActiveChanged() {
            if (root.active) grid.forceActiveFocus()
        }
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 40; spacing: 24

        RowLayout {
            Layout.fillWidth: true; spacing: 20
            
            Row {
                spacing: 12
                Rectangle { width: 48; height: 48; radius: 14; color: shellRoot.cMauve
                    Text { anchors.centerIn: parent; text: "󰸉"; font.pixelSize: 24; color: "#11111b" }
                }
                ColumnLayout {
                    spacing: 0
                    Text { text: "WALLPAPERS"; font.pixelSize: 20; font.bold: true; color: shellRoot.cText }
                    Text { text: "Select your next aesthetic"; font.pixelSize: 12; color: shellRoot.cSub }
                }
            }

            Item { Layout.fillWidth: true }

            Row {
                spacing: 12
                ActionPill {
                    iconGlyph: "󰈔"; label: "Upload"
                    onClicked: {
                        uploadProc.command = ["sh", "-c", "FILE=$(zenity --file-selection --title='Select Wallpaper' --file-filter='Images | *.jpg *.jpeg *.png *.webp'); [ -n \"$FILE\" ] && python3 /home/reaan/.config/scripts/wallpaper_bridge.py upload \"$FILE\""]
                        uploadProc.running = true
                    }
                }
                ActionPill {
                    iconGlyph: "󰅖"; label: "Close"
                    onClicked: {
                        hideProc.command = ["sh", "-c", "echo 'hidden' > ${XDG_RUNTIME_DIR:-/tmp}/qs-wallpaper-picker"]
                        hideProc.running = true
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1,1,1,0.08) }

        GridView {
            id: grid
            Layout.fillWidth: true; Layout.fillHeight: true
            model: root.wallpapers
            cellWidth: 300; cellHeight: 200
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            focus: true

            delegate: WallpaperCard {
                name: modelData.name
                path: modelData.path
                isActive: GridView.isCurrentItem
                onClicked: applySelected(modelData.path)

                Keys.onEnterPressed: applySelected(modelData.path)
                Keys.onReturnPressed: applySelected(modelData.path)
            }

            function applySelected(path) {
                applyProc.command = ["/home/reaan/.config/scripts/apply-wallpaper.sh", path]
                applyProc.running = true
                hideProc.command = ["sh", "-c", "echo 'hidden' > ${XDG_RUNTIME_DIR:-/tmp}/qs-wallpaper-picker"]
                hideProc.running = true
            }
        }
    }
}
