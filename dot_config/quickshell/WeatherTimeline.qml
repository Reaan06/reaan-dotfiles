import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

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
                color: "#cba6f7"
                
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
            color: "#89b4fa"
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
                border.color: hourMouse.containsMouse ? "#cba6f7" : Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                
                Behavior on color { ColorAnimation { duration: 150 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    
                    Text { 
                        text: modelData.hour || "--:--"
                        font.family: root.font
                        font.pixelSize: 11
                        color: "#6c7086"
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
                        color: modelData.rain > 30 ? "#89b4fa" : (modelData.temp > 22 ? "#f9e2af" : "#cdd6f4")
                        Layout.alignment: Qt.AlignHCenter 
                    }
                    
                    Text { 
                        text: Math.round(modelData.temp || 0) + "°"
                        font.family: root.font
                        font.pixelSize: 18
                        font.bold: true
                        color: "#cdd6f4"
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
                            color: "#94e2d5"
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
