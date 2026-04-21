import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/**
 * @component WeatherCalendar
 * @description A high-end interactive calendar widget for the weather dashboard.
 * Supports date selection and highlighting the current day.
 */
Rectangle {
    id: root
    property string selectedDate: ""
    property string todayDate: ""
    signal dateSelected(string date)
    
    radius: 30
    color: Qt.rgba(1, 1, 1, 0.03)
    border.color: Qt.rgba(1, 1, 1, 0.05)
    
    readonly property string font: "JetBrains Mono Nerd Font"
    property color accentColor: "#cba6f7"
    property color textColor: "#cdd6f4"
    
    // Internal state
    property date displayDate: new Date()
    property var monthNames: ["ENERO", "FEBRERO", "MARZO", "ABRIL", "MAYO", "JUNIO", "JULIO", "AGOSTO", "SEPTIEMBRE", "OCTUBRE", "NOVIEMBRE", "DICIEMBRE"]
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15
        
        // Header
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: root.monthNames[root.displayDate.getMonth()] + " " + root.displayDate.getFullYear()
                font.family: root.font; font.pixelSize: 16; font.bold: true; color: root.accentColor
            }
            Item { Layout.fillWidth: true }
            Row {
                spacing: 8
                Rectangle {
                    width: 30; height: 30; radius: 10; color: Qt.rgba(1,1,1,0.05)
                    Text { anchors.centerIn: parent; text: "󰁍"; color: root.textColor; rotation: 180 }
                    MouseArea { anchors.fill: parent; onClicked: root.displayDate = new Date(root.displayDate.getFullYear(), root.displayDate.getMonth() - 1, 1) }
                }
                Rectangle {
                    width: 30; height: 30; radius: 10; color: Qt.rgba(1,1,1,0.05)
                    Text { anchors.centerIn: parent; text: "󰁍"; color: root.textColor }
                    MouseArea { anchors.fill: parent; onClicked: root.displayDate = new Date(root.displayDate.getFullYear(), root.displayDate.getMonth() + 1, 1) }
                }
            }
        }
        
        // Grid
        GridLayout {
            columns: 7; Layout.fillWidth: true; Layout.fillHeight: true
            rowSpacing: 2; columnSpacing: 2
            
            Repeater {
                model: ["D", "L", "M", "M", "J", "V", "S"]
                Text {
                    Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                    text: modelData; font.family: root.font; font.pixelSize: 10; font.bold: true; color: root.accentColor; opacity: 0.5
                }
            }
            
            Repeater {
                id: daysRepeater
                model: 42
                delegate: Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 32; radius: 10
                    
                    property date dateValue: {
                        var firstDay = new Date(root.displayDate.getFullYear(), root.displayDate.getMonth(), 1).getDay()
                        return new Date(root.displayDate.getFullYear(), root.displayDate.getMonth(), index - firstDay + 1)
                    }
                    property bool isCurrentMonth: dateValue.getMonth() === root.displayDate.getMonth()
                    property string dateString: dateValue.getFullYear() + "-" + String(dateValue.getMonth() + 1).padStart(2, '0') + "-" + String(dateValue.getDate()).padStart(2, '0')
                    property bool isSelected: root.selectedDate === dateString
                    property bool isToday: root.todayDate === dateString
                    
                    color: isSelected ? root.accentColor : (isToday ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.15) : "transparent")
                    opacity: isCurrentMonth ? 1 : 0.2
                    border.color: isToday && !isSelected ? root.accentColor : "transparent"
                    border.width: 1
                    
                    Text {
                        anchors.centerIn: parent
                        text: dateValue.getDate()
                        font.family: root.font; font.pixelSize: 12; font.bold: isSelected || isToday
                        color: isSelected ? "#11111b" : root.textColor
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.dateSelected(dateString)
                    }
                }
            }
        }
    }
}
