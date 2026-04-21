import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/**
 * @component WeatherTimeline
 * @description Horizontal forecast timeline with high-performance scrolling.
 * Implements vertical-to-horizontal wheel mapping to ensure desktop compatibility.
 */
Item {
    id: root
    
    /** @property hourlyData: Full 24-hour forecast array from WeatherManager */
    property var hourlyData: []
    
    implicitHeight: 200
    
    readonly property string font: "JetBrains Mono Nerd Font"
    property color cBlue: "#89b4fa"
    property color cMauve: "#cba6f7"
    property color cText: "#cdd6f4"
    property color cSub: "#6c7086"
    property color cTeal: "#94e2d5"
    property color cBg: Qt.rgba(0.1, 0.1, 0.15, 0.3)

    function parsePalette(raw) {
        if (!raw || raw.length === 0) return
        var parts = raw.split(" ")
        if (parts.length < 8) return
        try {
            cBlue  = parts[1] || cBlue
            cTeal  = parts[2] || cTeal
            cMauve = parts[3] || cMauve
            cText  = parts[6] || cText
            cSub   = parts[7] || cSub
        } catch (e) {
            console.log("Error parsing palette in WeatherTimeline: " + e)
        }
    }

    Process {
        id: paletteProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/.palette 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { root.parsePalette(text.trim()) } }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: paletteProc.running = true }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12
        
        // Custom top-aligned scrollbar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 3
            color: Qt.rgba(1, 1, 1, 0.05)
            radius: 1.5
            
            Rectangle {
                id: scrollThumb
                height: parent.height
                radius: parent.radius
                color: root.cMauve
                
                // Logic to calculate width and position
                width: Math.max(40, (listView.width / listView.contentWidth) * listView.width)
                x: (listView.contentX / (listView.contentWidth - listView.width)) * (parent.width - width)
                
                visible: listView.contentWidth > listView.width
            }
        }

        Text { 
            text: "PRONÓSTICO PRÓXIMAS 24 HORAS"
            font.family: root.font
            font.pixelSize: 13
            font.bold: true
            color: root.cBlue
            opacity: 0.9
        }

        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: ListView.Horizontal
            spacing: 14
            clip: true
            model: root.hourlyData
            boundsBehavior: Flickable.StopAtBounds
            snapMode: ListView.SnapToItem
            
            // Senior UX: Map vertical mouse wheel to horizontal scrolling
            WheelHandler {
                id: wheelHandler
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    if (event.angleDelta.y !== 0) {
                        let scrollAmount = event.angleDelta.y * 1.5;
                        listView.contentX = Math.max(0, 
                            Math.min(listView.contentX - scrollAmount, 
                                     listView.contentWidth - listView.width));
                    }
                }
            }

            delegate: Rectangle {
                width: 95
                height: 150
                radius: 20
                color: hourMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)
                border.color: hourMouse.containsMouse ? root.cMauve : Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                
                Behavior on color { ColorAnimation { duration: 150 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    
                    Text { 
                        text: modelData.hour || "--:--"
                        font.family: root.font
                        font.pixelSize: 11
                        color: root.cSub
                        Layout.alignment: Qt.AlignHCenter 
                    }
                    
                    Text { 
                        // Intelligent icon selection based on forecast conditions
                        text: {
                            if (modelData.rain > 30) return "󰖓"; 
                            if (modelData.temp > 22) return "󰖨";
                            return "󰖐"; 
                        }
                        font.pixelSize: 30
                        color: modelData.rain > 30 ? root.cBlue : (modelData.temp > 22 ? "#f9e2af" : root.cText)
                        Layout.alignment: Qt.AlignHCenter 
                    }
                    
                    Text { 
                        text: Math.round(modelData.temp || 0) + "°"
                        font.family: root.font
                        font.pixelSize: 18
                        font.bold: true
                        color: root.cText
                        Layout.alignment: Qt.AlignHCenter 
                    }
                    
                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4
                        Text { text: "󰖖"; font.pixelSize: 10; color: "#94e2d5" }
                        Text { 
                            text: (modelData.rain || 0) + "%"
                            font.family: root.font
                            font.pixelSize: 10
                                 color: root.cTeal
                        }
                    }
                }
                
                MouseArea { 
                    id: hourMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    // MouseArea on delegate must allow WheelHandler on ListView to see events
                    propagateComposedEvents: true
                    onWheel: (wheel) => wheel.accepted = false 
                }
            }
        }
    }
}
