import Quickshell
import Quickshell.Wayland
import QtQuick

// Punto de entrada de Quickshell.
// Variants crea una instancia de PanelWindow por cada monitor conectado.
// Cuando se conecta/desconecta un monitor, Quickshell gestiona el ciclo
// de vida automáticamente.

ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar

            property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            margins {
                top: 6
                left: 16
                right: 16
            }

            exclusionMode: ExclusionMode.Auto
            implicitHeight: 44
            color: "transparent"

            StatusBar {
                anchors.fill: parent
            }
        }
    }
}
