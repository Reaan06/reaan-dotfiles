import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    objectName: "GitHubDashboardView.qml"
    color: "transparent"

    required property var ghManager
    property real scale: (parent && parent.scale) ? parent.scale : 1.0

    readonly property string font: "JetBrains Mono Nerd Font"
    readonly property string textFont: "Inter, Noto Sans, Ubuntu, sans-serif"
    property color cMauve:   "#cba6f7"
    property color cBlue:    "#89b4fa"
    property color cGreen:   "#a6e3a1"
    property color cTeal:    "#94e2d5"
    property color cPeach:   "#fab387"
    property color cRed:     "#f38ba8"
    property color cYellow:  "#f9e2af"
    property color cFlamingo:"#f2cdcd"
    property color cText:    "#cdd6f4"
    property color cSub:     "#6c7086"
    property color cOverlay: "#45475a"
    property color cBg:      Qt.rgba(0.1, 0.1, 0.15, 0.3)

    function parsePalette(raw) {
        if (!raw || raw.length === 0) return
        var parts = raw.split(" ")
        if (parts.length < 8) return
        try {
            var pc = parts[0]
            if (pc && pc.startsWith("#") && pc.length >= 7) {
                cBg    = Qt.rgba(parseInt(pc.substr(1,2),16)/255, parseInt(pc.substr(3,2),16)/255, parseInt(pc.substr(5,2),16)/255, 0.4)
            }
            cBlue  = parts[1] || cBlue
            cTeal  = parts[2] || cTeal
            cMauve = parts[3] || cMauve
            cPeach = parts[4] || cPeach
            cText  = parts[6] || cText
            cSub   = parts[7] || cSub
        } catch (e) {
            console.log("Error parsing palette in GitHubDashboardView: " + e)
        }
    }

    Process {
        id: paletteProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/.palette 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { root.parsePalette(text.trim()) } }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: paletteProc.running = true }

    property bool isHoveringList: false
    property bool showNotifications: false

    function eventIcon(type) {
        var map = {
            "PushEvent":        { icon: "󰊢", color: cGreen  },
            "PullRequestEvent": { icon: "󰓊", color: cBlue   },
            "IssuesEvent":      { icon: "󰌷", color: cPeach  },
            "CreateEvent":      { icon: "󰐕", color: cMauve  },
            "WatchEvent":       { icon: "󰓎", color: cYellow },
            "ForkEvent":        { icon: "󰘬", color: cTeal   },
            "ReleaseEvent":     { icon: "󰏗", color: cFlamingo },
            "DeleteEvent":      { icon: "󰆴", color: cRed    },
        }
        return map[type] || { icon: "󰊤", color: cSub }
    }

    function timeAgo(isoDate) {
        if (!isoDate) return ""
        var diff = Math.floor((new Date() - new Date(isoDate)) / 1000)
        if (diff < 60)    return diff + "s"
        if (diff < 3600)  return Math.floor(diff / 60) + "m"
        if (diff < 86400) return Math.floor(diff / 3600) + "h"
        if (diff < 604800) return Math.floor(diff / 86400) + "d"
        return Math.floor(diff / 604800) + "w"
    }

    function langColor(lang) {
        var map = {
            "JavaScript": "#f1e05a", "TypeScript": "#3178c6", "Python": "#3572A5",
            "Rust": "#dea584", "Go": "#00ADD8", "C++": "#f34b7d", "C": "#555555",
            "C#": "#178600", "Java": "#b07219", "Lua": "#000080", "Shell": "#89e051",
            "HTML": "#e34c26", "CSS": "#563d7c", "QML": "#44a51c", "Dart": "#00B4AB",
            "Ruby": "#701516", "PHP": "#4F5D95", "Swift": "#F05138", "Kotlin": "#A97BFF",
        }
        return map[lang] || cSub
    }

    Flickable {
        anchors.fill: parent
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: !root.isHoveringList

        ColumnLayout {
            id: mainColumn
            width: parent.width
            spacing: 16 * root.scale

            // ── Profile Header (Top) ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 72 * root.scale
                radius: 20 * root.scale
                color: root.cBg

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16 * root.scale
                    anchors.rightMargin: 16 * root.scale
                    spacing: 14 * root.scale

                    Rectangle {
                        width: 44 * root.scale
                        height: 44 * root.scale
                        radius: 14 * root.scale
                        color: root.cMauve
                        clip: true
                        Text {
                            anchors.centerIn: parent
                            text: "󰊤"
                            font.pixelSize: 22 * root.scale
                            color: "#11111b"
                            visible: avatarImg.status !== Image.Ready
                        }
                        Image {
                            id: avatarImg
                            anchors.fill: parent
                            source: root.ghManager.profile.avatar_url || ""
                            fillMode: Image.PreserveAspectCrop
                            mipmap: true
                            visible: status === Image.Ready
                        }
                    }

                    ColumnLayout {
                        spacing: 1 * root.scale
                        Layout.fillWidth: true
                        Text {
                            text: root.ghManager.profile.name || root.ghManager.profile.login
                            font.family: root.textFont
                            font.pixelSize: 16 * root.scale
                            font.bold: true
                            color: root.cText
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "@" + root.ghManager.profile.login
                            font.family: root.textFont
                            font.pixelSize: 11 * root.scale
                            color: root.cSub
                        }
                    }

                    Repeater {
                        model: [
                            { icon: "󰳐", value: root.ghManager.profile.public_repos, col: root.cBlue },
                            { icon: "󰌾", value: root.ghManager.profile.private_repos || 0, col: root.cPeach },
                            { icon: "󰋻", value: root.ghManager.profile.followers, col: root.cGreen },
                        ]
                        Rectangle {
                            width: badgeRow.implicitWidth + 18 * root.scale
                            height: 30 * root.scale
                            radius: 9 * root.scale
                            color: Qt.rgba(1,1,1,0.04)
                            visible: modelData.value > 0 || index < 2
                            Row {
                                id: badgeRow
                                anchors.centerIn: parent
                                spacing: 5 * root.scale
                                Text {
                                    text: modelData.icon
                                    font.pixelSize: 13 * root.scale
                                    color: modelData.col
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.value
                                    font.family: root.textFont
                                    font.pixelSize: 12 * root.scale
                                    font.bold: true
                                    color: root.cText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 34 * root.scale
                        height: 34 * root.scale
                        radius: 10 * root.scale
                        color: Qt.rgba(1,1,1,0.04)
                        Text {
                            anchors.centerIn: parent
                            text: "󰑓"
                            font.pixelSize: 15 * root.scale
                            color: root.cSub
                            RotationAnimation on rotation {
                                running: root.ghManager.loading
                                from: 0
                                to: 360
                                duration: 800
                                loops: Animation.Infinite
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.ghManager.refresh()
                        }
                    }

                    Rectangle {
                        width: 34 * root.scale
                        height: 34 * root.scale
                        radius: 10 * root.scale
                        color: Qt.rgba(1,0.3,0.3,0.08)
                        Text {
                            anchors.centerIn: parent
                            text: "󰗼"
                            font.pixelSize: 15 * root.scale
                            color: root.cRed
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.ghManager.disconnect()
                        }
                    }
                }
            }

            // ── Heatmap + Sidebar (Improved Box) ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 12 * root.scale

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 185 * root.scale
                    Layout.minimumWidth: 320 * root.scale
                    radius: 20 * root.scale
                    color: root.cBg
                    border.color: Qt.rgba(1, 1, 1, 0.03)
                    border.width: 1 * root.scale

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16 * root.scale
                        spacing: 12 * root.scale

                        RowLayout {
                            spacing: 8 * root.scale
                            Text {
                                text: "󰔶"
                                font.pixelSize: 16 * root.scale
                                color: root.cGreen
                            }
                            Text {
                                text: "CONTRIBUTIONS"
                                font.family: root.textFont
                                font.pixelSize: 12 * root.scale
                                font.bold: true
                                color: root.cText
                                font.letterSpacing: 1.2 * root.scale
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root.ghManager.contributions ? (root.ghManager.contributions.total + " this year") : "Token required"
                                font.family: root.textFont
                                font.pixelSize: 11 * root.scale
                                color: root.cSub
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            Canvas {
                                id: heatmapCanvas
                                anchors.fill: parent
                                property var weeksData: root.ghManager.contributions ? root.ghManager.contributions.weeks : []
                                onWeeksDataChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    var weeks = weeksData
                                    if (!weeks || weeks.length === 0) {
                                        ctx.fillStyle = root.cSub.toString()
                                        ctx.font = (12 * root.scale) + "px " + root.textFont
                                        ctx.textAlign = "center"
                                        ctx.fillText("Connect with a PAT to see your heatmap", width / 2, height / 2)
                                        return
                                    }

                                    var cellSize = Math.min(Math.floor((height - 6 * root.scale) / 7), 13 * root.scale)
                                    var gap = 2.5 * root.scale
                                    var step = cellSize + gap
                                    var maxWeeks = Math.floor((width - 4 * root.scale) / step)
                                    var startWeek = Math.max(0, weeks.length - maxWeeks)

                                    for (var w = startWeek; w < weeks.length; w++) {
                                        var days = weeks[w].contributionDays
                                        var col = w - startWeek
                                        for (var d = 0; d < days.length; d++) {
                                            var day = days[d]
                                            var x = col * step + 2 * root.scale
                                            var y = d * step + 2 * root.scale

                                            if (day.color && day.contributionCount > 0) {
                                                ctx.fillStyle = day.color
                                            } else if (day.contributionCount === 0) {
                                                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.05).toString()
                                            } else {
                                                var t = Math.min(day.contributionCount / 12, 1)
                                                ctx.fillStyle = Qt.rgba(0.65 * t, 0.89 * t + 0.08, 0.63 * t, 0.25 + 0.75 * t).toString()
                                            }
                                            ctx.beginPath()
                                            ctx.roundedRect(x, y, cellSize, cellSize, 3.5 * root.scale, 3.5 * root.scale)
                                            ctx.fill()
                                        }
                                    }
                                }

                                MouseArea {
                                    id: heatmapMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onPositionChanged: (mouse) => {
                                        var weeks = heatmapCanvas.weeksData
                                        if (!weeks || weeks.length === 0) {
                                            heatmapTooltip.visible = false
                                            return
                                        }
                                        var cellSize = Math.min(Math.floor((heatmapCanvas.height - 6 * root.scale) / 7), 13 * root.scale)
                                        var step = cellSize + 2.5 * root.scale
                                        var maxWeeks = Math.floor((heatmapCanvas.width - 4 * root.scale) / step)
                                        var startWeek = Math.max(0, weeks.length - maxWeeks)
                                        var col = Math.floor((mouse.x - 2 * root.scale) / step)
                                        var row = Math.floor((mouse.y - 2 * root.scale) / step)
                                        var isInsideCell = (mouse.x - 2 * root.scale - col * step) <= cellSize && (mouse.y - 2 * root.scale - row * step) <= cellSize
                                        if (col >= 0 && col < weeks.length - startWeek && row >= 0 && row < 7 && isInsideCell) {
                                            var w = startWeek + col
                                            if (weeks[w] && weeks[w].contributionDays[row]) {
                                                var day = weeks[w].contributionDays[row]
                                                var count = day.contributionCount
                                                tooltipText.text = (count === 0 ? "No" : count) + " contribution" + (count === 1 ? "" : "s") + " on " + day.date
                                                var tx = mouse.x + 10
                                                if (tx + heatmapTooltip.width > heatmapCanvas.width) tx = mouse.x - heatmapTooltip.width - 10
                                                heatmapTooltip.x = tx
                                                var ty = mouse.y + 15
                                                if (ty + heatmapTooltip.height > heatmapCanvas.height) ty = mouse.y - heatmapTooltip.height - 10
                                                heatmapTooltip.y = ty
                                                heatmapTooltip.visible = true
                                                return
                                            }
                                        }
                                        heatmapTooltip.visible = false
                                    }
                                    onExited: heatmapTooltip.visible = false
                                }

                                Rectangle {
                                    id: heatmapTooltip
                                    visible: false
                                    color: Qt.rgba(0.08, 0.08, 0.12, 0.95)
                                    border.color: Qt.rgba(1, 1, 1, 0.1)
                                    border.width: 1 * root.scale
                                    radius: 8 * root.scale
                                    width: tooltipText.implicitWidth + 20 * root.scale
                                    height: tooltipText.implicitHeight + 12 * root.scale
                                    z: 100
                                    Text {
                                        id: tooltipText
                                        anchors.centerIn: parent
                                        color: root.cText
                                        font.family: root.textFont
                                        font.pixelSize: 11 * root.scale
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 160 * root.scale
                    spacing: 8 * root.scale
                    Repeater {
                        model: {
                            var c = root.ghManager.contributions
                            return [
                                { label: "STREAK",  value: c ? c.current_streak + "d" : "—", icon: "󰈸", col: root.cPeach },
                                { label: "BEST",    value: c ? c.longest_streak + "d"  : "—", icon: "󰆣", col: root.cYellow },
                                { label: "COMMITS", value: c ? c.commits.toString()     : "—", icon: "󰊢", col: root.cGreen },
                                { label: "PRS",     value: c ? c.prs.toString()          : "—", icon: "󰓊", col: root.cBlue }
                            ]
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40 * root.scale
                            radius: 12 * root.scale
                            color: root.cBg
                            border.color: Qt.rgba(1, 1, 1, 0.02)
                            border.width: 1 * root.scale
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12 * root.scale
                                anchors.rightMargin: 12 * root.scale
                                spacing: 8 * root.scale
                                Text {
                                    text: modelData.icon
                                    font.pixelSize: 14 * root.scale
                                    color: modelData.col
                                }
                                Text {
                                    text: modelData.value
                                    font.family: root.textFont
                                    font.pixelSize: 15 * root.scale
                                    font.bold: true
                                    color: root.cText
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: modelData.label
                                    font.family: root.textFont
                                    font.pixelSize: 9 * root.scale
                                    color: root.cSub
                                    font.letterSpacing: 0.5 * root.scale
                                }
                            }
                        }
                    }
                }
            }

            // ── Activity Feed + Top Repos ──
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12 * root.scale

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 250 * root.scale
                    radius: 20 * root.scale
                    color: root.cBg
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14 * root.scale
                        spacing: 6 * root.scale
                        RowLayout {
                            Text {
                                text: root.showNotifications ? "󰂚" : "󱅫"
                                font.pixelSize: 16 * root.scale
                                color: root.showNotifications ? root.cYellow : root.cMauve
                            }
                            Row {
                                spacing: 10 * root.scale
                                Text {
                                    text: "ACTIVITY"
                                    font.family: root.textFont
                                    font.pixelSize: 12 * root.scale
                                    font.bold: !root.showNotifications
                                    color: !root.showNotifications ? root.cText : root.cSub
                                    font.letterSpacing: 1 * root.scale
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        anchors.margins: -5
                                        onClicked: root.showNotifications = false
                                    }
                                }
                                Text {
                                    text: "/"
                                    font.family: root.textFont
                                    font.pixelSize: 12 * root.scale
                                    color: root.cSub
                                }
                                Text {
                                    text: "NOTIFICATIONS"
                                    font.family: root.textFont
                                    font.pixelSize: 12 * root.scale
                                    font.bold: root.showNotifications
                                    color: root.showNotifications ? root.cText : root.cSub
                                    font.letterSpacing: 1 * root.scale
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        anchors.margins: -5
                                        onClicked: root.showNotifications = true
                                    }
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: (root.showNotifications ? root.ghManager.notifications.length : root.ghManager.events.length) + (root.showNotifications ? " unread" : " events")
                                font.family: root.textFont
                                font.pixelSize: 10 * root.scale
                                color: root.cSub
                            }
                        }
                        ListView {
                            HoverHandler { onHoveredChanged: root.isHoveringList = hovered }
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 3 * root.scale
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.showNotifications ? root.ghManager.notifications : root.ghManager.events
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: ListView.view ? ListView.view.width : 0
                                height: 38 * root.scale
                                radius: 10 * root.scale
                                color: evMA.containsMouse ? Qt.rgba(1,1,1,0.04) : (index % 2 === 0 ? Qt.rgba(1,1,1,0.015) : "transparent")
                                Behavior on color { ColorAnimation { duration: 120 } }
                                MouseArea {
                                    id: evMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (modelData.url) Qt.openUrlExternally(modelData.url) }
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8 * root.scale
                                    anchors.rightMargin: 8 * root.scale
                                    spacing: 8 * root.scale
                                    Rectangle {
                                        width: 26 * root.scale
                                        height: 26 * root.scale
                                        radius: 7 * root.scale
                                        color: root.showNotifications ? Qt.rgba(root.cYellow.r, root.cYellow.g, root.cYellow.b, 0.12) : Qt.rgba(root.eventIcon(modelData.type).color.r, root.eventIcon(modelData.type).color.g, root.eventIcon(modelData.type).color.b, 0.12)
                                        Text {
                                            anchors.centerIn: parent
                                            text: root.showNotifications ? "󰂚" : root.eventIcon(modelData.type).icon
                                            font.pixelSize: 12 * root.scale
                                            color: root.showNotifications ? root.cYellow : root.eventIcon(modelData.type).color
                                        }
                                    }
                                    ColumnLayout {
                                        spacing: 0
                                        Layout.fillWidth: true
                                        Text {
                                            text: modelData.repo ? modelData.repo.split("/").pop() : ""
                                            font.family: root.textFont
                                            font.pixelSize: 11 * root.scale
                                            font.bold: true
                                            color: root.cText
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: root.showNotifications ? (modelData.title || "") : (modelData.detail || "")
                                            font.family: root.textFont
                                            font.pixelSize: 9 * root.scale
                                            color: root.cSub
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                    Rectangle {
                                        width: timeLbl.implicitWidth + 10 * root.scale
                                        height: 18 * root.scale
                                        radius: 5 * root.scale
                                        color: Qt.rgba(1,1,1,0.04)
                                        Text {
                                            id: timeLbl
                                            anchors.centerIn: parent
                                            text: root.showNotifications ? root.timeAgo(modelData.updated_at) : root.timeAgo(modelData.created_at)
                                            font.family: root.textFont
                                            font.pixelSize: 9 * root.scale
                                            color: root.cSub
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 320 * root.scale
                    Layout.fillHeight: true
                    Layout.minimumHeight: 250 * root.scale
                    radius: 20 * root.scale
                    color: root.cBg
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14 * root.scale
                        spacing: 6 * root.scale
                        RowLayout {
                            Text {
                                text: "󰳐"
                                font.pixelSize: 16 * root.scale
                                color: root.cBlue
                            }
                            Text {
                                text: "REPOSITORIES"
                                font.family: root.textFont
                                font.pixelSize: 12 * root.scale
                                font.bold: true
                                color: root.cText
                                font.letterSpacing: 1 * root.scale
                            }
                        }
                        ListView {
                            HoverHandler { onHoveredChanged: root.isHoveringList = hovered }
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 3 * root.scale
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.ghManager.repos
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: ListView.view ? ListView.view.width : 0
                                height: 38 * root.scale
                                radius: 10 * root.scale
                                color: rpMA.containsMouse ? Qt.rgba(1,1,1,0.04) : (index % 2 === 0 ? Qt.rgba(1,1,1,0.015) : "transparent")
                                Behavior on color { ColorAnimation { duration: 120 } }
                                MouseArea {
                                    id: rpMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (modelData.url) Qt.openUrlExternally(modelData.url) }
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8 * root.scale
                                    anchors.rightMargin: 8 * root.scale
                                    spacing: 8 * root.scale
                                    Rectangle {
                                        width: 26 * root.scale
                                        height: 26 * root.scale
                                        radius: 7 * root.scale
                                        color: Qt.rgba(root.cBlue.r, root.cBlue.g, root.cBlue.b, 0.12)
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.private ? "󰌾" : "󰳐"
                                            font.pixelSize: 11 * root.scale
                                            color: root.cBlue
                                        }
                                    }
                                    ColumnLayout {
                                        spacing: 0
                                        Layout.fillWidth: true
                                        Text {
                                            text: modelData.name || ""
                                            font.family: root.textFont
                                            font.pixelSize: 11 * root.scale
                                            font.bold: true
                                            color: root.cText
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Row {
                                            spacing: 6 * root.scale
                                            Rectangle {
                                                width: 7 * root.scale
                                                height: 7 * root.scale
                                                radius: width / 2
                                                color: modelData.language ? root.langColor(modelData.language) : root.cSub
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: !!modelData.language
                                            }
                                            Text {
                                                text: modelData.language || "—"
                                                font.family: root.textFont
                                                font.pixelSize: 9 * root.scale
                                                color: root.cSub
                                            }
                                            Text {
                                                text: modelData.last_commit_msg ? (" · " + modelData.last_commit_msg) : ""
                                                font.family: root.textFont
                                                font.pixelSize: 9 * root.scale
                                                color: Qt.rgba(root.cSub.r, root.cSub.g, root.cSub.b, 0.6)
                                                elide: Text.ElideRight
                                                visible: !!modelData.last_commit_msg
                                                Layout.maximumWidth: 120 * root.scale
                                            }
                                        }
                                    }
                                    ColumnLayout {
                                        spacing: 0
                                        Row {
                                            spacing: 3 * root.scale
                                            Layout.alignment: Qt.AlignRight
                                            Text {
                                                text: "󰓎"
                                                font.pixelSize: 10 * root.scale
                                                color: root.cYellow
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Text {
                                                text: (modelData.stars || 0).toString()
                                                font.family: root.textFont
                                                font.pixelSize: 10 * root.scale
                                                color: root.cSub
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                        Text {
                                            text: root.timeAgo(modelData.updated_at)
                                            font.family: root.textFont
                                            font.pixelSize: 8 * root.scale
                                            color: Qt.rgba(root.cSub.r, root.cSub.g, root.cSub.b, 0.5)
                                            Layout.alignment: Qt.AlignRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Item { Layout.preferredHeight: 2 * root.scale }
        }
    }
}
