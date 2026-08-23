import QtQuick
import QtQuick.Layouts
import "components"

Item {
    id: root

    property real scale: (parent && parent.scale) ? parent.scale : 1.0
    property color cSurface: Qt.rgba(0.07, 0.07, 0.10, 0.97)
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
    property var providers: []
    property var lastKnownGoodProviders: ({})
    property real anchorWidth: 120
    property real neckOffset: 0
    signal refreshRequested()
    signal periodSelected(string selectedPeriod)

    function providerModel() {
        if (root.providers && root.providers.length > 0) return root.providers
        return [
            { id: "chatgpt", label: "ChatGPT/Codex", status: "missing", error: "not signed in", windows: [] },
            { id: "claude", label: "Claude", status: "missing", error: "not signed in", windows: [] },
            { id: "opencode", label: "OpenCode", status: "missing", error: "source-missing", windows: [] }
        ]
    }

    function displayCard(card) {
        if (card && card.status === "ok") return card
        if (card && card.id && root.lastKnownGoodProviders[card.id]) return root.lastKnownGoodProviders[card.id]
        return null
    }

    function statusColor(card) {
        var value = card ? card.status : "missing"
        if (value === "ok") return root.cGood
        if (value === "offline" || value === "rate-limited" || value === "stale" || value === "locked") return root.cWarning
        return root.cError
    }

    function statusLabel(card, shown) {
        if (!card) return "no data"
        if (card.status === "ok") return "fresh"
        if (card.status === "missing" && card.cli_status === "unavailable") return "cli unavailable"
        return shown ? "last good · " + card.status : card.status
    }

    function formatNumber(value) {
        var number = Number(value)
        if (!isFinite(number)) return "—"
        return number % 1 === 0 ? number.toString() : number.toFixed(2)
    }

    function formatAge(seconds) {
        if (seconds === null || seconds === undefined || Number(seconds) < 0) return ""
        var value = Number(seconds)
        if (value < 60) return Math.max(0, Math.floor(value)) + "s"
        if (value < 3600) return Math.floor(value / 60) + "m"
        return Math.floor(value / 3600) + "h"
    }

    function freshness(card, shown) {
        if (!card) return "No successful snapshot"
        var stamp = card.generated_at || ""
        var age = card.source_age_seconds
        var prefix = shown ? "Last good" : "Updated"
        if (stamp) return prefix + ": " + stamp
        if (age !== undefined && age !== null) return prefix + ": " + formatAge(age) + " ago"
        return prefix
    }

    function resetText(window) {
        if (window && typeof window.reset_in_seconds === "number") {
            var seconds = Math.max(0, Math.floor(window.reset_in_seconds))
            if (seconds < 60) return "reset " + seconds + "s"
            if (seconds < 3600) return "reset " + Math.floor(seconds / 60) + "m"
            if (seconds < 86400) return "reset " + Math.floor(seconds / 3600) + "h"
            return "reset " + Math.floor(seconds / 86400) + "d"
        }
        return "reset unknown"
    }

    function usageText(card) {
        var usage = card && card.usage
        if (!usage) return "No local totals"
        var tokens = Number(usage.input_tokens || 0) + Number(usage.output_tokens || 0)
            + Number(usage.reasoning_tokens || 0) + Number(usage.cache_tokens || 0)
        return "$" + formatNumber(usage.cost) + " · " + formatNumber(tokens) + " tokens"
    }

    Rectangle { anchors.fill: parent; radius: 18; color: root.cSurface }
    PanelConnector {
        anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(1, root.anchorWidth + 32); height: 20
        barWidth: root.anchorWidth; neckOffset: root.neckOffset; color: root.cSurface
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18 * root.scale
        anchors.topMargin: 28 * root.scale
        spacing: 9 * root.scale

        RowLayout {
            Layout.fillWidth: true
            spacing: 10 * root.scale
            Rectangle {
                width: 38 * root.scale; height: 38 * root.scale; radius: 11 * root.scale
                color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.16)
                Text {
                    anchors.centerIn: parent; text: "󰚩"; font.family: root.fontFamily
                    font.pixelSize: 20 * root.scale; color: root.cAccent
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1 * root.scale
                Text { text: "AI Usage"; font.family: root.fontFamily; font.pixelSize: 16 * root.scale; font.bold: true; color: root.cText }
                Text { text: "ChatGPT/Codex · Claude · OpenCode"; font.family: root.fontFamily; font.pixelSize: 9 * root.scale; color: root.cSub; elide: Text.ElideRight }
            }
            Text { text: root.loading ? "loading" : "ready"; font.family: root.fontFamily; font.pixelSize: 9 * root.scale; color: root.loading ? root.cWarning : root.cSub }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 6 * root.scale
            Repeater {
                model: ["day", "week", "month"]
                Rectangle {
                    required property string modelData
                    Layout.fillWidth: true; height: 25 * root.scale; radius: 8 * root.scale
                    color: root.period === modelData ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.18) : root.cCard
                    border.width: root.period === modelData ? 1 : 0; border.color: root.cAccent
                    Text {
                        anchors.centerIn: parent; text: parent.modelData.toUpperCase()
                        font.family: root.fontFamily; font.pixelSize: 9 * root.scale
                        font.bold: root.period === parent.modelData; color: root.period === parent.modelData ? root.cAccent : root.cSub
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.periodSelected(parent.modelData) }
                }
            }
        }

        Repeater {
            model: root.providerModel()
            Rectangle {
                id: providerCard
                required property var modelData
                property var card: modelData
                property var shown: root.displayCard(card)
                Layout.fillWidth: true
                Layout.preferredHeight: card.id === "opencode" ? 84 * root.scale : 100 * root.scale
                radius: 12 * root.scale
                color: root.cCard
                border.width: 1
                border.color: Qt.rgba(root.statusColor(card).r, root.statusColor(card).g, root.statusColor(card).b, 0.22)

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 10 * root.scale; spacing: 4 * root.scale
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6 * root.scale
                        Text { text: providerCard.card.label || providerCard.card.id; font.family: root.fontFamily; font.pixelSize: 11 * root.scale; font.bold: true; color: root.cText; Layout.fillWidth: true }
                        Text {
                            text: root.statusLabel(providerCard.card, !!providerCard.shown)
                            font.family: root.fontFamily; font.pixelSize: 8 * root.scale; color: root.statusColor(providerCard.card)
                        }
                    }
                    Text {
                        visible: providerCard.card.id === "opencode"
                        text: root.usageText(providerCard.shown)
                        font.family: root.fontFamily; font.pixelSize: 10 * root.scale; color: root.cText
                    }
                    Repeater {
                        model: providerCard.shown && providerCard.shown.windows ? providerCard.shown.windows : []
                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true; spacing: 5 * root.scale
                            Text { text: modelData.label || "window"; font.family: root.fontFamily; font.pixelSize: 9 * root.scale; color: root.cSub; Layout.preferredWidth: 58 * root.scale }
                            Rectangle {
                                Layout.fillWidth: true; height: 6 * root.scale; radius: 3 * root.scale; color: Qt.rgba(1, 1, 1, 0.08)
                                Rectangle { width: Math.max(0, Math.min(1, Number(modelData.utilization || 0) / 100)) * parent.width; height: parent.height; radius: parent.radius; color: root.statusColor(providerCard.card) }
                            }
                            Text { text: root.formatNumber(modelData.utilization) + "% · " + root.resetText(modelData); font.family: root.fontFamily; font.pixelSize: 8 * root.scale; color: root.cSub; Layout.preferredWidth: 106 * root.scale }
                        }
                    }
                    Text {
                        visible: !providerCard.shown
                        text: providerCard.card.error || "No data available"
                        font.family: root.fontFamily; font.pixelSize: 9 * root.scale; color: root.cSub
                    }
                    Text {
                        text: root.freshness(providerCard.shown, !!providerCard.shown)
                        font.family: root.fontFamily; font.pixelSize: 8 * root.scale; color: root.cSub; elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: root.errorCode && root.status !== "ok" ? root.status + " · " + root.errorCode : "Per-provider status is shown above"; font.family: root.fontFamily; font.pixelSize: 8 * root.scale; color: root.cSub; elide: Text.ElideRight }
            Rectangle {
                implicitWidth: refreshText.implicitWidth + 20 * root.scale; height: 28 * root.scale; radius: 9 * root.scale; color: root.cCard
                Text { id: refreshText; anchors.centerIn: parent; text: root.loading ? "Refreshing" : "Refresh"; font.family: root.fontFamily; font.pixelSize: 9 * root.scale; color: root.cAccent }
                MouseArea { anchors.fill: parent; onClicked: root.refreshRequested() }
            }
        }
    }
}
