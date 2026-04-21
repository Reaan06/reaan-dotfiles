import QtQuick
import Quickshell.Io

/**
 * @component WeatherManager
 * @description State machine for weather data orchestration.
 * Manages both data fetching and the currently active date context for the UI.
 */
Item {
    id: root
    property var weatherData: ({})
    property bool loading: true
    
    // The date currently being viewed in the Dashboard (defaults to today)
    property string selectedDate: ""
    
    // Background fetch from the Python script
    Process {
        id: fetchProc
        command: ["sh", "-c", "python3 ~/.config/scripts/get_weather.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text);
                    root.weatherData = data;
                    if (root.selectedDate === "") {
                        root.selectedDate = data.current_date;
                    }
                    root.loading = false;
                } catch (e) { root.loading = false; }
            }
        }
    }

    // Fast local cache hydration
    Process {
        id: cacheLoader
        command: ["sh", "-c", "cat ~/.cache/weather.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text);
                    root.weatherData = data;
                    if (root.selectedDate === "") {
                        root.selectedDate = data.current_date;
                    }
                    root.loading = false;
                } catch (e) { }
            }
        }
    }

    Timer {
        interval: 900000 
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: { root.loading = true; fetchProc.running = true; }
    }

    Component.onCompleted: cacheLoader.running = true;
}
