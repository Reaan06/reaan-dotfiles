import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/**
 * @component WeatherCalendarView
 * @description Optimized master layout for the Weather Dashboard.
 * Rebalanced panel widths to ensure the Center and Right areas are breathable
 * while keeping the Calendar compact and centered.
 */
Item {
    id: root
    anchors.fill: parent

    WeatherManager { id: weatherManager }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 25

        // Left Panel: Shorter and aligned to the top
        WeatherCalendar {
            Layout.preferredWidth: 290
            Layout.preferredHeight: 340
            Layout.fillHeight: false
            Layout.alignment: Qt.AlignTop
            selectedDate: weatherManager.selectedDate
            todayDate: weatherManager.weatherData.current_date || ""
            onDateSelected: (date) => weatherManager.selectedDate = date
        }

        // Center Panel: Widened horizontally, shorter vertically
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 25

            // Compacted but wider Hero Widget
            Rectangle {
                id: heroWidget
                Layout.fillWidth: true
                Layout.preferredHeight: 130
                radius: 40
                color: Qt.rgba(30/255, 30/255, 46/255, 0.4)
                border.color: Qt.rgba(1, 1, 1, 0.05)
                clip: true
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 45
                    anchors.rightMargin: 45
                    spacing: 30

                    // City Info
                    ColumnLayout {
                        spacing: 8
                        Layout.fillWidth: true
                        Text { 
                            text: weatherManager.loading ? "Localizando..." : (weatherManager.weatherData.city || "Clima")
                            font.family: "JetBrains Mono Nerd Font"; font.pixelSize: 34; font.bold: true; color: "#cdd6f4" 
                            elide: Text.ElideRight
                        }
                        Row {
                            spacing: 8
                            Rectangle { width: 4; height: 18; radius: 2; color: "#cba6f7"; anchors.verticalCenter: parent.verticalCenter }
                            Text { 
                                text: weatherManager.selectedDate === weatherManager.weatherData.current_date ? "PRONÓSTICO HOY" : "HISTORIAL: " + weatherManager.selectedDate
                                font.family: "JetBrains Mono Nerd Font"; font.pixelSize: 14; color: "#9399b2"; font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Main Temperature Display
                    RowLayout {
                        spacing: 25
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        
                        Text { 
                            property var dayData: weatherManager.weatherData.days ? weatherManager.weatherData.days[weatherManager.selectedDate] : null
                            text: (dayData && dayData[0]) ? Math.round(dayData[0].temp) + "°C" : "--°C"
                            font.family: "JetBrains Mono Nerd Font"; font.pixelSize: 56; font.bold: true; color: "#cba6f7" 
                        }

                        Rectangle {
                            width: 80; height: 80; radius: 24
                            color: Qt.rgba(203, 166, 247, 0.1)
                            Text { 
                                anchors.centerIn: parent
                                text: "󰖐"; font.pixelSize: 42; color: "#89b4fa" 
                            }
                        }
                    }
                }
            }

            // Timeline
            WeatherTimeline {
                Layout.fillWidth: true
                Layout.preferredHeight: 280
                hourlyData: (weatherManager.weatherData.days && weatherManager.selectedDate) ? weatherManager.weatherData.days[weatherManager.selectedDate] : []
            }
            
            Item { Layout.fillHeight: true } // Balance spacer
        }

        // Right Panel: Shorter and aligned to the top
        WeatherDetails {
            Layout.preferredWidth: 290
            Layout.preferredHeight: 340
            Layout.fillHeight: false
            Layout.alignment: Qt.AlignTop
            currentData: (weatherManager.weatherData.days && weatherManager.selectedDate) ? weatherManager.weatherData.days[weatherManager.selectedDate][0] : null
        }
    }
}
