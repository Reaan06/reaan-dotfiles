import QtQuick
import Quickshell
ShellRoot {
    Component.onCompleted: {
        console.log("HOME is " + Quickshell.env("HOME"))
        Qt.quit()
    }
}
