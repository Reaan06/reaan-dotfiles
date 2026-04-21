import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string fontFamily: "JetBrains Mono Nerd Font"
    property color cText:    "#cdd6f4"
    property color cSub:     "#6c7086"
    property color cSurface: Qt.rgba(1, 1, 1, 0.05)
    property color cAccent:  "#f38ba8"
    property color cGreen:   "#a6e3a1"
    property color cBlue:    "#89b4fa"
    property string currentMonth: ""
    property string currentView: "daily"
    property var lastData: ({})
    property real totalTime: 0

    ListModel { id: appModel }

    function formatTime(seconds) {
        var hrs  = Math.floor(seconds / 3600)
        var mins = Math.floor((seconds % 3600) / 60)
        var secs = Math.floor(seconds % 60)
        if (hrs > 0) return hrs + "h " + mins + "m"
        if (mins > 0) return mins + "m " + secs + "s"
        return secs + "s"
    }

    function loadData(jsonStr) {
        try {
            if (!jsonStr || jsonStr.trim() === "") return
            var data = JSON.parse(jsonStr)
            root.lastData = data
            refreshView()
        } catch(e) {
            console.log("AppUsageView JSON parse error: " + e)
        }
    }

    function refreshView() {
        if (!root.lastData || !root.lastData[root.currentView]) return
        var targetData = root.lastData[root.currentView]
        var sorted = []
        var tTime = 0
        for (var key in targetData) {
            if (key === "_total_") {
                tTime = targetData[key].time
                continue
            }
            if (key === "" || key.startsWith("_")) continue
            if (targetData[key].time > 5) {
                sorted.push({
                    name:  key,
                    time:  targetData[key].time,
                    opens: targetData[key].opens || 1
                })
            }
        }
        
        // Fallback: si no hay _total_, suma el uso de las apps
        if (tTime === 0) {
            for (var j = 0; j < sorted.length; j++) tTime += sorted[j].time
        }
        root.totalTime = tTime

        sorted.sort(function(a, b) { return b.time - a.time })
        appModel.clear()
        for (var i = 0; i < sorted.length; i++) {
            appModel.append(sorted[i])
        }
    }

    Process {
        id: reader
        command: ["cat", Qt.resolvedUrl("~/.cache/app_usage.json").toString().replace("file://", "")]
        onRunningChanged: {}
        stdout: StdioCollector {
            onStreamFinished: root.loadData(text)
        }
    }

    // Fallback usando sh para expandir ~
    Process {
        id: readerSh
        command: ["sh", "-c", "cat $HOME/.cache/app_usage.json 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: root.loadData(text)
        }
    }

    Timer {
        interval: 1200; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { readerSh.running = false; readerSh.running = true }
    }

    // ─── UI ───────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
                width: 44; height: 44; radius: 12
                color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.15)
                Text {
                    anchors.centerIn: parent
                    text: "󰣆"; font.family: root.fontFamily
                    font.pixelSize: 22; color: root.cAccent
                }
            }
            ColumnLayout {
                spacing: 2
                Text {
                    text: "USO DE APLICACIONES"
                    font.family: root.fontFamily; font.pixelSize: 16; font.bold: true
                    color: root.cText
                }
                RowLayout {
                    spacing: 12
                    Repeater {
                        model: [
                            { id: "daily", label: "HOY" },
                            { id: "weekly", label: "SEMANA" },
                            { id: "monthly", label: "MES" }
                        ]
                        Rectangle {
                            width: btnTxt.implicitWidth + 16; height: 20; radius: 10
                            color: root.currentView === modelData.id ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.2) : (btnMA.containsMouse ? Qt.rgba(1,1,1,0.05) : "transparent")
                            border.width: root.currentView === modelData.id ? 1 : 0
                            border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.5)
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                id: btnTxt; anchors.centerIn: parent
                                text: modelData.label
                                font.family: root.fontFamily; font.pixelSize: 10
                                color: root.currentView === modelData.id ? root.cAccent : root.cSub
                                font.bold: root.currentView === modelData.id
                            }
                            MouseArea {
                                id: btnMA; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                onClicked: { root.currentView = modelData.id; root.refreshView() }
                            }
                        }
                    }
                    Text {
                        text: "• " + appModel.count + " apps | Total uso PC: " + root.formatTime(root.totalTime)
                        font.family: root.fontFamily; font.pixelSize: 11
                        color: Qt.rgba(root.cSub.r, root.cSub.g, root.cSub.b, 0.6)
                    }
                }
            }
            Item { Layout.fillWidth: true }
        }

        // Column headers
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 12; Layout.rightMargin: 12
            Text { text: "APLICACIÓN";   font.family: root.fontFamily; font.pixelSize: 11; color: root.cSub; Layout.fillWidth: true }
            Text { text: "APERTURAS";    font.family: root.fontFamily; font.pixelSize: 11; color: root.cSub; Layout.preferredWidth: 90 }
            Text { text: "TIEMPO";       font.family: root.fontFamily; font.pixelSize: 11; color: root.cSub; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.07) }

        // Lista con scroll
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Empty state (solo cuando no hay datos)
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12
                visible: appModel.count === 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "󰔛"
                    font.family: root.fontFamily; font.pixelSize: 48; color: root.cSub
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Sin datos de uso aún"
                    font.family: root.fontFamily; font.pixelSize: 14; color: root.cSub
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Los datos se acumulan mientras usas el sistema"
                    font.family: root.fontFamily; font.pixelSize: 11
                    color: Qt.rgba(root.cSub.r, root.cSub.g, root.cSub.b, 0.6)
                }
            }

            // Lista scrolleable
            ListView {
                id: appList
                anchors.fill: parent
                anchors.rightMargin: 10
                model: appModel
                clip: true
                spacing: 6
                visible: appModel.count > 0
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 1500

                ScrollBar.vertical: ScrollBar {
                    id: vScrollBar
                    policy: ScrollBar.AlwaysOn
                    minimumSize: 0.05
                    contentItem: Rectangle {
                        implicitWidth: 5
                        radius: 3
                        color: vScrollBar.pressed
                            ? root.cAccent
                            : Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.5)
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    background: Rectangle {
                        implicitWidth: 5
                        radius: 3
                        color: Qt.rgba(1, 1, 1, 0.05)
                    }
                }

                delegate: Rectangle {
                    width: appList.width
                    height: 58
                    radius: 12
                    color: root.cSurface

                    // Barra lateral de posición
                    Rectangle {
                        width: 3; height: parent.height * 0.6
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        radius: 2
                        color: {
                            if (index === 0) return root.cAccent
                            if (index === 1) return root.cBlue
                            return root.cGreen
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        anchors.leftMargin: 16
                        spacing: 12

                        // Icono con fallback a letra
                        Item {
                            width: 34; height: 34

                            Rectangle {
                                anchors.fill: parent; radius: 9
                                color: {
                                    if (index === 0) return Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.18)
                                    if (index === 1) return Qt.rgba(root.cBlue.r,   root.cBlue.g,   root.cBlue.b,   0.18)
                                    return Qt.rgba(root.cGreen.r, root.cGreen.g, root.cGreen.b, 0.18)
                                }
                            }

                            Image {
                                id: appIcon
                                anchors.fill: parent; anchors.margins: 4
                                source: "image://icon/" + model.name
                                fillMode: Image.PreserveAspectFit
                                smooth: true; mipmap: true
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                text: model.name.charAt(0).toUpperCase()
                                font.family: root.fontFamily; font.pixelSize: 16; font.bold: true
                                color: index === 0 ? root.cAccent : (index === 1 ? root.cBlue : root.cGreen)
                                visible: appIcon.status !== Image.Ready
                            }
                        }

                        // Nombre
                        Text {
                            Layout.fillWidth: true
                            text: model.name
                            color: root.cText; font.family: root.fontFamily
                            font.pixelSize: 14; font.bold: true
                            elide: Text.ElideRight
                        }

                        // Aperturas
                        Row {
                            Layout.preferredWidth: 90
                            spacing: 5
                            Text { text: "󰏌"; font.family: root.fontFamily; font.pixelSize: 13; color: root.cSub }
                            Text {
                                text: model.opens + "x"
                                color: root.cSub; font.family: root.fontFamily; font.pixelSize: 13
                            }
                        }

                        // Tiempo
                        Text {
                            Layout.preferredWidth: 80
                            text: root.formatTime(model.time)
                            color: root.cText; font.family: root.fontFamily
                            font.pixelSize: 14; font.bold: true
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }
        }
    }
}
