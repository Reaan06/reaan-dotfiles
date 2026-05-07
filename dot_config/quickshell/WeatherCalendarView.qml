import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/**
 * @component WeatherCalendarView
 * @description Optimized master layout for the Weather Dashboard.
 * Now fully dynamic with wallpaper colors and absolute proportionality.
 */
Item {
    id: root
    anchors.fill: parent

    property real scale: (parent && parent.scale) ? parent.scale : 1.0

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
        anchors.fill: parent; anchors.margins: 20 * root.scale; spacing: 25 * root.scale

        WeatherCalendar {
            Layout.preferredWidth: 290 * root.scale; Layout.preferredHeight: 340 * root.scale; Layout.fillHeight: false; Layout.alignment: Qt.AlignTop
            selectedDate: weatherManager.selectedDate; todayDate: weatherManager.weatherData.current_date || ""; onDateSelected: (date) => weatherManager.selectedDate = date
            // Passing scale to child component
            property real scale: root.scale
        }

        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 25 * root.scale

            Rectangle {
                id: heroWidget; Layout.fillWidth: true; Layout.preferredHeight: 130 * root.scale; radius: 40 * root.scale; color: root.cBg; border.color: Qt.rgba(1, 1, 1, 0.05); clip: true
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 45 * root.scale; anchors.rightMargin: 45 * root.scale; spacing: 30 * root.scale
                    ColumnLayout {
                        spacing: 8 * root.scale; Layout.fillWidth: true
                        Text { text: weatherManager.loading ? "Localizando..." : (weatherManager.weatherData.city || "Clima"); font.family: "JetBrains Mono Nerd Font"; font.pixelSize: 34 * root.scale; font.bold: true; color: root.cText; elide: Text.ElideRight }
                        Row {
                            spacing: 8 * root.scale
                            Rectangle { width: 4 * root.scale; height: 18 * root.scale; radius: 2 * root.scale; color: root.cMauve; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: weatherManager.selectedDate === weatherManager.weatherData.current_date ? "PRONÓSTICO HOY" : "HISTORIAL: " + weatherManager.selectedDate; font.family: "JetBrains Mono Nerd Font"; font.pixelSize: 14 * root.scale; color: root.cSub; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    RowLayout {
                        spacing: 25 * root.scale; Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Text { 
                            property var dayData: weatherManager.weatherData.days ? weatherManager.weatherData.days[weatherManager.selectedDate] : null
                            text: (dayData && dayData[0]) ? Math.round(dayData[0].temp) + "°C" : "--°C"
                            font.family: "JetBrains Mono Nerd Font"; font.pixelSize: 56 * root.scale; font.bold: true; color: root.cMauve 
                        }
                        Rectangle {
                            width: 80 * root.scale; height: 80 * root.scale; radius: 24 * root.scale; color: Qt.rgba(root.cMauve.r, root.cMauve.g, root.cMauve.b, 0.1)
                            Text { anchors.centerIn: parent; text: "󰖐"; font.pixelSize: 42 * root.scale; color: root.cBlue }
                        }
                    }
                }
            }

            WeatherTimeline {
                Layout.fillWidth: true; Layout.preferredHeight: 280 * root.scale
                hourlyData: (weatherManager.weatherData.days && weatherManager.selectedDate) ? weatherManager.weatherData.days[weatherManager.selectedDate] : []
                // Passing scale to child component
                property real scale: root.scale
            }
            Item { Layout.fillHeight: true }
        }

        WeatherDetails {
            Layout.preferredWidth: 290 * root.scale; Layout.preferredHeight: 340 * root.scale; Layout.fillHeight: false; Layout.alignment: Qt.AlignTop
            currentData: (weatherManager.weatherData.days && weatherManager.selectedDate) ? weatherManager.weatherData.days[weatherManager.selectedDate][0] : null
            // Passing scale to child component
            property real scale: root.scale
        }
    }
}
