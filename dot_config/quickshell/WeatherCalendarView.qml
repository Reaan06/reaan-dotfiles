import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/**
 * @component WeatherCalendarView
 * @description Optimized master layout for the Weather Dashboard.
 * Now fully dynamic with wallpaper colors.
 */
Item {
    id: root
    anchors.fill: parent

    // ═══════════════════════════════════════════════
    // THEME — Dinámico
    // ═══════════════════════════════════════════════
    property color cMauve: "#cba6f7"
    property color cBlue: "#89b4fa"
    property color cText: "#cdd6f4"
    property color cSub: "#6c7086"
    property color cBg: Qt.rgba(30/255, 30/255, 46/255, 0.4)

    Behavior on cMauve { ColorAnimation { duration: 600 } }
    Behavior on cBlue { ColorAnimation { duration: 600 } }
    Behavior on cText { ColorAnimation { duration: 600 } }
    Behavior on cSub { ColorAnimation { duration: 600 } }
    Behavior on cBg { ColorAnimation { duration: 600 } }

    function parsePalette(raw) {
        if (!raw || raw.length === 0) return
        var parts = raw.split(" ")
        if (parts.length < 8) return
        try {
            var pc = parts[0]
            if (pc && pc.startsWith("#") && pc.length >= 7) {
                cBg = Qt.rgba(parseInt(pc.substr(1,2),16)/255, parseInt(pc.substr(3,2),16)/255, parseInt(pc.substr(5,2),16)/255, 0.4)
            }
            cBlue  = parts[1] || cBlue
            cMauve = parts[3] || cMauve
            cText  = parts[6] || cText
            cSub   = parts[7] || cSub
        } catch (e) {
            console.log("Error parsing palette in WeatherCalendarView: " + e)
        }
    }

    Process {
        id: paletteProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/.palette 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { root.parsePalette(text.trim()) } }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: paletteProc.running = true }

    WeatherManager { id: weatherManager }

    RowLayout {
        anchors.fill: parent; anchors.margins: 20; spacing: 25

        WeatherCalendar {
            Layout.preferredWidth: 290; Layout.preferredHeight: 340; Layout.fillHeight: false; Layout.alignment: Qt.AlignTop
            selectedDate: weatherManager.selectedDate; todayDate: weatherManager.weatherData.current_date || ""; onDateSelected: (date) => weatherManager.selectedDate = date
        }

        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 25

            Rectangle {
                id: heroWidget; Layout.fillWidth: true; Layout.preferredHeight: 130; radius: 40; color: root.cBg; border.color: Qt.rgba(1, 1, 1, 0.05); clip: true
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 45; anchors.rightMargin: 45; spacing: 30
                    ColumnLayout {
                        spacing: 8; Layout.fillWidth: true
                        Text { text: weatherManager.loading ? "Localizando..." : (weatherManager.weatherData.city || "Clima"); font.family: "JetBrains Mono Nerd Font"; font.pixelSize: 34; font.bold: true; color: root.cText; elide: Text.ElideRight }
                        Row {
                            spacing: 8
                            Rectangle { width: 4; height: 18; radius: 2; color: root.cMauve; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: weatherManager.selectedDate === weatherManager.weatherData.current_date ? "PRONÓSTICO HOY" : "HISTORIAL: " + weatherManager.selectedDate; font.family: "JetBrains Mono Nerd Font"; font.pixelSize: 14; color: root.cSub; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    RowLayout {
                        spacing: 25; Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Text { 
                            property var dayData: weatherManager.weatherData.days ? weatherManager.weatherData.days[weatherManager.selectedDate] : null
                            text: (dayData && dayData[0]) ? Math.round(dayData[0].temp) + "°C" : "--°C"
                            font.family: "JetBrains Mono Nerd Font"; font.pixelSize: 56; font.bold: true; color: root.cMauve 
                        }
                        Rectangle {
                            width: 80; height: 80; radius: 24; color: Qt.rgba(root.cMauve.r, root.cMauve.g, root.cMauve.b, 0.1)
                            Text { anchors.centerIn: parent; text: "󰖐"; font.pixelSize: 42; color: root.cBlue }
                        }
                    }
                }
            }

            WeatherTimeline {
                Layout.fillWidth: true; Layout.preferredHeight: 280
                hourlyData: (weatherManager.weatherData.days && weatherManager.selectedDate) ? weatherManager.weatherData.days[weatherManager.selectedDate] : []
            }
            Item { Layout.fillHeight: true }
        }

        WeatherDetails {
            Layout.preferredWidth: 290; Layout.preferredHeight: 340; Layout.fillHeight: false; Layout.alignment: Qt.AlignTop
            currentData: (weatherManager.weatherData.days && weatherManager.selectedDate) ? weatherManager.weatherData.days[weatherManager.selectedDate][0] : null
        }
    }
}
