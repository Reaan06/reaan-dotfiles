import QtQuick
import QtQuick.Controls

ApplicationWindow {
    visible: true
    width: 400
    height: 300
    title: "Minimal Test"

    property string output: "Waiting for output..."

    Column {
        anchors.centerIn: parent
        Text {
            text: "Network Test Output:"
            font.bold: true
        }
        Text {
            id: outputText
            text: parent.parent.output
            wrapMode: Text.WordWrap
            width: 300
        }
    }

    Component.onCompleted: {
        // Ejecutar el script con el argumento "info"
        Quickshell.spawn(["/home/reaan/reaan-dotfiles/dot_config/scripts/network-manager.sh", "info"], {
            onStdout: (data) => {
                output = data
            },
            onStderr: (data) => {
                output = "Error: " + data
            }
        })
    }
}
