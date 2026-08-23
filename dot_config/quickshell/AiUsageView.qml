import QtQuick
import QtQuick.Layouts
import "components"

Item {
    id: root
    property real scale: (parent && parent.scale) ? parent.scale : 1.0
    property color cSurface: Qt.rgba(0.07, 0.07, 0.10, 0.96)
    property color cCard: Qt.rgba(1, 1, 1, 0.05)
    property color cText: shellRoot.cText
    property color cSub: shellRoot.cSub
    property color cAccent: shellRoot.cTeal
    property color cGood: shellRoot.cGreen
    property color cWarning: shellRoot.cYellow
    property color cError: shellRoot.cRed
    property string fontFamily: "JetBrains Mono Nerd Font"
    property string period: "day"
    property string status: "missing"
    property string errorCode: "source-missing"
    property bool loading: false
    property int sourceAgeSeconds: -1
    property var snapshot: null
    property real anchorWidth: 120
    property real neckOffset: 0
    signal refreshRequested()
    signal periodSelected(string selectedPeriod)
    readonly property bool hasSnapshot: !!(root.snapshot && root.snapshot.totals)
    readonly property var totals: root.hasSnapshot ? root.snapshot.totals : null
    readonly property var groups: root.hasSnapshot && root.snapshot.breakdown ? root.snapshot.breakdown : []

    function periodLabel(value) { return value === "week" ? "WEEK" : value === "month" ? "MONTH" : "DAY" }
    function formatNumber(value) {
        var number = Number(value)
        return number % 1 === 0 ? number.toString() : number.toFixed(2)
    }
    function formatAge(seconds) {
        if (seconds < 60) return Math.max(0, seconds) + "s"
        if (seconds < 3600) return Math.floor(seconds / 60) + "m"
        return Math.floor(seconds / 3600) + "h"
    }
    function statusColor() {
        return root.status === "ok" ? root.cGood : root.status === "stale" ? root.cWarning : root.cError
    }
    function freshnessText() {
        if (root.hasSnapshot && root.snapshot.generated_at) return "Last good: " + root.snapshot.generated_at
        if (root.sourceAgeSeconds >= 0) return "Source age: " + root.formatAge(root.sourceAgeSeconds)
        return "No successful snapshot"
    }

    Rectangle { anchors.fill: parent; radius: 18; color: root.cSurface }
    PanelConnector {
        anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(1, root.anchorWidth + 32); height: 20
        barWidth: root.anchorWidth; neckOffset: root.neckOffset; color: root.cSurface
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 22 * root.scale; anchors.topMargin: 30 * root.scale
        spacing: 14 * root.scale

        RowLayout {
            Layout.fillWidth: true; spacing: 12 * root.scale
            Rectangle {
                width: 42 * root.scale; height: 42 * root.scale; radius: 12 * root.scale
                color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.16)
                Text {
                    anchors.centerIn: parent; text: "󰚩"; font.family: root.fontFamily
                    font.pixelSize: 22 * root.scale; color: root.cAccent
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 2 * root.scale
                Text { text: "AI Usage"; font.family: root.fontFamily; font.pixelSize: 17 * root.scale; font.bold: true; color: root.cText }
                Text { text: "Local OpenCode token and cost analytics"; font.family: root.fontFamily; font.pixelSize: 10 * root.scale; color: root.cSub; elide: Text.ElideRight }
            }
            Rectangle {
                implicitWidth: statusText.implicitWidth + 16 * root.scale; height: 24 * root.scale; radius: 12 * root.scale
                color: Qt.rgba(root.statusColor().r, root.statusColor().g, root.statusColor().b, 0.16)
                Text {
                    id: statusText; anchors.centerIn: parent; text: root.loading ? "loading" : root.status
                    font.family: root.fontFamily; font.pixelSize: 10 * root.scale; font.bold: true; color: root.statusColor()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 8 * root.scale
            Repeater {
                model: ["day", "week", "month"]
                Rectangle {
                    required property string modelData
                    Layout.fillWidth: true; height: 28 * root.scale; radius: 9 * root.scale
                    color: root.period === modelData ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.18) : root.cCard
                    border.width: root.period === modelData ? 1 : 0; border.color: root.cAccent
                    Text {
                        anchors.centerIn: parent; text: root.periodLabel(parent.modelData)
                        font.family: root.fontFamily; font.pixelSize: 10 * root.scale
                        font.bold: root.period === parent.modelData; color: root.period === parent.modelData ? root.cAccent : root.cSub
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.periodSelected(parent.modelData) }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 8 * root.scale
            Repeater {
                model: [
                    { label: "COST", key: "cost", prefix: "$" }, { label: "INPUT", key: "input_tokens", prefix: "" },
                    { label: "OUTPUT", key: "output_tokens", prefix: "" }, { label: "REASONING", key: "reasoning_tokens", prefix: "" },
                    { label: "CACHE", key: "cache_tokens", prefix: "" }
                ]
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredWidth: 1; height: 70 * root.scale; radius: 12 * root.scale
                    color: root.cCard; visible: root.hasSnapshot
                    Column {
                        anchors.centerIn: parent; spacing: 4 * root.scale
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.modelData.label; font.family: root.fontFamily; font.pixelSize: 9 * root.scale; color: root.cSub }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.totals ? parent.parent.modelData.prefix + root.formatNumber(root.totals[parent.parent.modelData.key]) : "—"; font.family: root.fontFamily; font.pixelSize: 14 * root.scale; font.bold: true; color: root.cText }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true; spacing: 5 * root.scale; visible: root.status !== "ok"
            Text { text: root.status + (root.errorCode ? " · " + root.errorCode : ""); font.family: root.fontFamily; font.pixelSize: 11 * root.scale; font.bold: true; color: root.statusColor() }
            Text { text: root.hasSnapshot ? "Last-known-good totals retained" : "No usage totals available"; font.family: root.fontFamily; font.pixelSize: 10 * root.scale; color: root.cSub }
        }

        ColumnLayout {
            Layout.fillWidth: true; spacing: 6 * root.scale; visible: root.groups.length > 0
            Text { text: "DETAIL"; font.family: root.fontFamily; font.pixelSize: 10 * root.scale; font.bold: true; color: root.cSub }
            Repeater {
                model: root.groups
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Text { text: parent.modelData.provider + "/" + parent.modelData.model; font.family: root.fontFamily; font.pixelSize: 10 * root.scale; color: root.cText; Layout.fillWidth: true }
                    Text { text: "$" + root.formatNumber(parent.modelData.cost); font.family: root.fontFamily; font.pixelSize: 10 * root.scale; color: root.cSub }
                }
            }
        }

        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: root.freshnessText(); font.family: root.fontFamily; font.pixelSize: 10 * root.scale; color: root.cSub; elide: Text.ElideRight }
            Rectangle {
                implicitWidth: refreshText.implicitWidth + 22 * root.scale; height: 30 * root.scale; radius: 10 * root.scale; color: root.cCard
                Text { id: refreshText; anchors.centerIn: parent; text: root.loading ? "Refreshing…" : "Refresh"; font.family: root.fontFamily; font.pixelSize: 10 * root.scale; color: root.cAccent }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.refreshRequested() }
            }
        }
    }
}
