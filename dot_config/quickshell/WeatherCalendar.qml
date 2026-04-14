import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/**
 * @component WeatherCalendar
 * @description Corrected interactive calendar with balanced centering.
 * Reduced item sizes to fit perfectly within the left sidebar without stretching.
 */
Rectangle {
    id: root
    
    property string selectedDate: ""
    property string todayDate: ""
    signal dateSelected(string date)
    
    color: Qt.rgba(30/255, 30/255, 46/255, 0.4)
    radius: 32
    border.color: Qt.rgba(1, 1, 1, 0.05)
    
    readonly property string font: "JetBrains Mono Nerd Font"
    
    function getDateString(day) {
        if (!day) return "";
        let d = day < 10 ? "0" + day : day;
        return "2026-04-" + d;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 15

        // Compact Header
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "ABRIL 2026"
                font.family: root.font; font.pixelSize: 18; font.bold: true
                color: "#cba6f7"
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                width: 30; height: 30; radius: 8; color: Qt.rgba(1, 1, 1, 0.05)
                Text { anchors.centerIn: parent; text: "󰸗"; color: "#cba6f7"; font.pixelSize: 15 }
            }
        }

        // Perfectly centered grid of days
        GridLayout {
            columns: 7
            columnSpacing: 6
            rowSpacing: 6
            Layout.alignment: Qt.AlignHCenter // Forces the grid to the center of the ColumnLayout

            Repeater {
                model: ["LU", "MA", "MI", "JU", "VI", "SA", "DO"]
                Text {
                    text: modelData
                    font.family: root.font; font.pixelSize: 11; font.bold: true
                    color: "#585b70"
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            Repeater {
                model: 30
                delegate: Rectangle {
                    id: dayRect
                    Layout.preferredWidth: 32 // Compact size
                    Layout.preferredHeight: 32
                    radius: 10
                    Layout.alignment: Qt.AlignHCenter
                    
                    readonly property string dateStr: root.getDateString(index + 1)
                    readonly property bool isToday: dateStr === root.todayDate
                    readonly property bool isSelected: dateStr === root.selectedDate
                    
                    color: isSelected ? "#cba6f7" : (dayMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                    border.color: isToday ? "#cba6f7" : "transparent"
                    border.width: isToday ? 1 : 0

                    Text {
                        anchors.centerIn: parent
                        text: index + 1
                        font.family: root.font; font.pixelSize: 12; font.bold: isSelected || isToday
                        color: isSelected ? "#11111b" : (isToday ? "#cba6f7" : "#cdd6f4")
                    }

                    MouseArea {
                        id: dayMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.dateSelected(dayRect.dateStr)
                    }
                    
                    // Selected indicator
                    Rectangle {
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 3; anchors.horizontalCenter: parent.horizontalCenter
                        width: 3; height: 3; radius: 1.5; color: "#11111b"; visible: isSelected
                    }
                }
            }
        }
        
        Item { Layout.fillHeight: true }
    }
}
