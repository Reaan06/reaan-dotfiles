import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "components"

Item {
    id: root
    objectName: "WeatherCalendarView.qml"

    readonly property string font: "JetBrains Mono Nerd Font"
    property color cMauve: "#cba6f7"
    property color cBlue: "#89b4fa"
    property color cText: "#cdd6f4"
    property color cSub: "#6c7086"
    property color cBg: Qt.rgba(1, 1, 1, 0.03)

    // Data State
    property var weatherData: ({})
    property string selectedDate: new Date().toISOString().split('T')[0]
    property var selectedDayData: []
    property int currentHourIndex: new Date().getHours()

    function updateDayData() {
        if (weatherData.days && weatherData.days[selectedDate]) {
            selectedDayData = weatherData.days[selectedDate]
        }
    }

    Process {
        id: weatherProc
        command: ["python3", Quickshell.configPath + "/../scripts/get_weather.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text)
                    if (!data.error) {
                        root.weatherData = data
                        updateDayData()
                    }
                } catch(e) { console.log("Weather Parse Error: " + e) }
            }
        }
    }
    Component.onCompleted: weatherProc.running = true

    RowLayout {
        anchors.fill: parent; spacing: 40

        // Left Column: Calendar Navigation
        ColumnLayout {
            Layout.preferredWidth: 320; Layout.fillHeight: true; spacing: 20

            Text { 
                text: "CALENDAR"; font.family: root.font; font.pixelSize: 18; font.bold: true; color: root.cMauve 
            }

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; radius: 24; color: root.cBg
                border.color: Qt.rgba(1,1,1,0.06); border.width: 1

                GridView {
                    id: calGrid; anchors.fill: parent; anchors.margins: 20
                    cellWidth: width / 7; cellHeight: height / 6; clip: true
                    model: 31 // Simplified 30-day view
                    delegate: Rectangle {
                        width: calGrid.cellWidth - 8; height: calGrid.cellHeight - 8; radius: 10
                        color: root.selectedDate.includes("-" + (index + 1).toString().padStart(2, '0')) ? root.cMauve : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: index + 1; font.family: root.font; font.pixelSize: 14
                            color: root.selectedDate.includes("-" + (index + 1).toString().padStart(2, '0')) ? "#11111b" : root.cText
                        }
                        MouseArea { 
                            anchors.fill: parent
                            onClicked: {
                                let d = new Date()
                                d.setDate(index + 1)
                                root.selectedDate = d.toISOString().split('T')[0]
                                updateDayData()
                            }
                        }
                    }
                }
            }
        }

        // Center Column: Interactive Hourly Clock/Weather
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
            
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                
                // Circular Layout for Hours
                Repeater {
                    model: root.selectedDayData.length > 0 ? root.selectedDayData : 0
                    delegate: Rectangle {
                        property real angle: (index / 24) * 2 * Math.PI - Math.PI/2
                        x: parent.width/2 + Math.cos(angle) * (parent.height/2.5) - width/2
                        y: parent.height/2 + Math.sin(angle) * (parent.height/2.5) - height/2
                        
                        width: 70; height: 100; radius: 20; color: root.cBg
                        border.color: index === root.currentHourIndex ? root.cMauve : Qt.rgba(1,1,1,0.06)
                        opacity: Math.abs(index - root.currentHourIndex) < 4 ? 1 : 0.4

                        ColumnLayout {
                            anchors.centerIn: parent; spacing: 4
                            Text { text: modelData.hour; font.family: root.font; font.pixelSize: 10; color: root.cSub; Layout.alignment: Qt.AlignHCenter }
                            Text { text: "󰖐"; font.pixelSize: 20; color: root.cMauve; Layout.alignment: Qt.AlignHCenter }
                            Text { text: modelData.temp + "°"; font.family: root.font; font.pixelSize: 14; font.bold: true; color: root.cText; Layout.alignment: Qt.AlignHCenter }
                        }
                    }
                }

                // Center Main Display
                ColumnLayout {
                    anchors.centerIn: parent; spacing: 0
                    Text { 
                        text: root.selectedDayData[root.currentHourIndex] ? root.selectedDayData[root.currentHourIndex].temp + "°" : "--°"
                        font.family: root.font; font.pixelSize: 80; font.bold: true; color: root.cText; Layout.alignment: Qt.AlignHCenter
                    }
                    Text { 
                        text: root.weatherData.city || "Fetching..."; font.family: root.font; font.pixelSize: 18; color: root.cSub; Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }

        // Right Column: Details
        ColumnLayout {
            Layout.preferredWidth: 280; Layout.fillHeight: true; spacing: 20
            
            Text { text: "DETAILS"; font.family: root.font; font.pixelSize: 18; font.bold: true; color: root.cMauve }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 12
                Repeater {
                    model: [
                        { name: "WIND", val: root.selectedDayData[root.currentHourIndex] ? root.selectedDayData[root.currentHourIndex].wind + " km/h" : "0", icon: "󰖝" },
                        { name: "HUMIDITY", val: root.selectedDayData[root.currentHourIndex] ? root.selectedDayData[root.currentHourIndex].humidity + "%" : "0", icon: "󰖉" },
                        { name: "RAIN", val: root.selectedDayData[root.currentHourIndex] ? root.selectedDayData[root.currentHourIndex].rain + "%" : "0", icon: "󰖗" }
                    ]
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 100; radius: 24; color: root.cBg
                        border.color: Qt.rgba(1,1,1,0.06); border.width: 1
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 20; spacing: 16
                            Text { text: modelData.icon; font.pixelSize: 32; color: root.cMauve }
                            ColumnLayout {
                                Text { text: modelData.name; font.family: root.font; font.pixelSize: 12; color: root.cSub }
                                Text { text: modelData.val; font.family: root.font; font.pixelSize: 18; font.bold: true; color: root.cText }
                            }
                        }
                    }
                }
            }
        }
    }
}
