import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "components"

Item {
    id: root

    property real scale: (parent && parent.scale) ? parent.scale : 1.0
    property color cSurface: Qt.rgba(0.07, 0.07, 0.10, 0.90)
    property color cCard: Qt.rgba(0.12, 0.12, 0.15, 0.12)
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
    property bool refreshQueued: false
    property var providers: []
    property var lastKnownGoodProviders: ({})
    property string lastGoodPeriod: ""
    property string lastCompletedAt: ""
    property string lastCompletedPeriod: ""
    property string lastCompletedStatus: "never"
    property bool authBusy: false
    property string authProvider: ""
    property string authAction: ""
    property string authStatus: ""
    property real anchorWidth: 120
    property real neckOffset: 0
    property real unfoldProgress: 1
    signal refreshRequested()
    signal periodSelected(string selectedPeriod)
    signal providerAuthRequested(string providerId, string action)

    function parsePalette(raw) {
        if (!raw || raw.length === 0) return
        var parts = raw.split(" ")
        if (parts.length < 8) return
        try {
            var pc = parts[0]
            if (pc && pc.startsWith("#") && pc.length >= 7) {
                var r = parseInt(pc.substr(1, 2), 16) / 255
                var g = parseInt(pc.substr(3, 2), 16) / 255
                var b = parseInt(pc.substr(5, 2), 16) / 255
                cSurface = Qt.rgba(r, g, b, 0.90)
                cCard = Qt.rgba(r + 0.05, g + 0.05, b + 0.05, 0.12)
            }
            cAccent = parts[1] || cAccent
            cGood = parts[2] || cGood
            cWarning = parts[4] || cWarning
            cError = parts[5] || cError
            cText = parts[6] || cText
            cSub = parts[7] || cSub
        } catch (e) {
            console.log("Error parsing palette in AiUsageView: " + e)
        }
    }

    Process {
        id: paletteProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/.palette 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.parsePalette(text.trim()) }
    }
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: paletteProc.running = true }

    opacity: root.unfoldProgress
    clip: true
    transform: Scale {
        origin.x: root.width / 2
        origin.y: 0
        xScale: 1
        yScale: root.unfoldProgress
    }

    function providerModel() {
        if (root.providers && root.providers.length > 0) return root.providers
        return [
            { id: "chatgpt", label: "ChatGPT / OpenAI", status: "missing", error: "credentials-missing", windows: [] },
            { id: "claude", label: "Claude", status: "missing", error: "credentials-missing", windows: [] },
            { id: "opencode", label: "OpenCode", status: "missing", error: "source-missing", windows: [] }
        ]
    }

    function displayCard(card) {
        if (card && card.status === "ok") return card
        if (card && card.id && root.lastGoodPeriod === root.period
                && root.lastKnownGoodProviders[card.id]) return root.lastKnownGoodProviders[card.id]
        return null
    }

    function statusColor(card, shown) {
        if (shown) return root.cWarning
        var value = card ? card.status : "missing"
        if (value === "ok") return root.cGood
        if (value === "offline" || value === "rate-limited" || value === "locked") return root.cWarning
        return root.cError
    }

    function statusLabel(card, shown) {
        if (!card) return "no data"
        if (shown) return "cached · " + root.lastGoodPeriod
        if (card.status === "ok") return "fresh"
        if (card.id === "claude" && card.status === "missing" && card.cli_status === "unavailable") return "cli unavailable"
        return shown ? "last good · " + card.status : card.status
    }

    function providerAuthAction(card) {
        if (!card || card.id === "opencode") return ""
        if (card.id === "claude") {
            if (card.status === "ok") return "logout"
            if (card.status === "missing" || card.status === "auth" || card.status === "expired") return "login"
        }
        if (card.id === "chatgpt" && card.status === "ok") return "logout"
        return ""
    }

    function formatNumber(value) {
        var number = Number(value)
        if (!isFinite(number)) return "—"
        return number % 1 === 0 ? number.toString() : number.toFixed(2)
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

    function freshness(card, shown) {
        if (!card) return "No successful snapshot"
        var stamp = card.generated_at || ""
        var prefix = shown ? "Last good (" + root.lastGoodPeriod + ")" : "Updated (" + root.period + ")"
        if (stamp) return prefix + ": " + stamp
        if (card.source_age_seconds !== undefined && card.source_age_seconds !== null) return prefix + ": " + card.source_age_seconds + "s ago"
        return prefix
    }

    function refreshStateText() {
        if (root.loading) return root.refreshQueued ? "refresh queued" : "refreshing"
        if (root.lastCompletedStatus === "never") return "not refreshed yet"
        return "last completed " + root.lastCompletedPeriod + " · " + root.lastCompletedStatus
    }

    function refreshMetaText() {
        if (!root.lastCompletedAt) return "No completed refresh in this session"
        return "Completed: " + root.lastCompletedAt + " · request period: " + root.lastCompletedPeriod
    }

    Rectangle { anchors.fill: parent; radius: 18; color: root.cSurface; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.10) }
    PanelConnector {
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 20; barWidth: root.anchorWidth; neckOffset: root.neckOffset; color: root.cSurface
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 18 * root.scale; anchors.topMargin: 28 * root.scale; spacing: 9 * root.scale

        RowLayout {
            Layout.fillWidth: true; spacing: 10 * root.scale
            Rectangle {
                width: 42 * root.scale; height: 42 * root.scale; radius: 13 * root.scale
                color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.16)
                border.width: 1 * root.scale
                border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.30)
                Text { anchors.centerIn: parent; text: "AI"; font.family: root.fontFamily; font.pixelSize: 13 * root.scale; font.bold: true; color: root.cAccent }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1 * root.scale
                Text { text: "AI Usage"; font.family: root.fontFamily; font.pixelSize: 16 * root.scale; font.bold: true; color: root.cText }
                Text { text: "ChatGPT / OpenAI · Claude · OpenCode"; font.family: root.fontFamily; font.pixelSize: 9 * root.scale; color: root.cSub; elide: Text.ElideRight }
            }
            Rectangle {
                implicitWidth: headerStatus.implicitWidth + 16 * root.scale
                height: 24 * root.scale
                radius: height / 2
                color: root.loading
                    ? Qt.rgba(root.cWarning.r, root.cWarning.g, root.cWarning.b, 0.14)
                    : Qt.rgba(root.cGood.r, root.cGood.g, root.cGood.b, 0.12)
                Row {
                    anchors.centerIn: parent; spacing: 5 * root.scale
                    Rectangle {
                        width: 6 * root.scale; height: width; radius: width / 2
                        color: root.loading ? root.cWarning : root.cGood
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        id: headerStatus
                        text: root.loading ? (root.refreshQueued ? "queued" : "refreshing") : "ready"
                        font.family: root.fontFamily; font.pixelSize: 8 * root.scale; font.bold: true
                        color: root.loading ? root.cWarning : root.cGood
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 6 * root.scale
            Repeater {
                model: ["day", "week", "month"]
                Rectangle {
                    required property string modelData
                    property bool selected: root.period === modelData
                    Layout.fillWidth: true; height: 25 * root.scale; radius: 8 * root.scale
                    color: selected
                        ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.18)
                        : (periodMouse.containsMouse ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.10) : root.cCard)
                    border.width: selected || periodMouse.containsMouse ? 1 : 0
                    border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, selected ? 0.80 : 0.35)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text { anchors.centerIn: parent; text: parent.modelData.toUpperCase(); font.family: root.fontFamily; font.pixelSize: 9 * root.scale; font.bold: parent.selected; color: parent.selected ? root.cAccent : root.cSub }
                    MouseArea { id: periodMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.periodSelected(parent.modelData) }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 9 * root.scale
            Repeater {
                model: root.providerModel()
                Rectangle {
                    id: providerCard
                    required property var modelData
                    property var card: modelData
                    property var shown: root.displayCard(card)
                    property bool showingCached: card && card.status !== "ok" && !!shown
                    property string availableAuthAction: root.providerAuthAction(card)
                    property bool authPending: root.authBusy
                        && root.authProvider === card.id
                        && root.authAction === availableAuthAction
                    Layout.fillWidth: true
                    Layout.preferredHeight: card.id === "opencode" ? 76 * root.scale : 112 * root.scale
                    radius: 14 * root.scale; color: root.cCard; border.width: 1
                    border.color: Qt.rgba(root.statusColor(card, showingCached).r, root.statusColor(card, showingCached).g, root.statusColor(card, showingCached).b, showingCached ? 0.34 : 0.22)
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 11 * root.scale; spacing: 4 * root.scale
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6 * root.scale
                            Rectangle {
                                width: 7 * root.scale; height: width; radius: width / 2
                                color: root.statusColor(providerCard.card, providerCard.showingCached)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text { text: providerCard.card.label || providerCard.card.id; font.family: root.fontFamily; font.pixelSize: 11 * root.scale; font.bold: true; color: root.cText; Layout.fillWidth: true }
                            Text { text: root.statusLabel(providerCard.card, providerCard.showingCached); font.family: root.fontFamily; font.pixelSize: 8 * root.scale; color: root.statusColor(providerCard.card, providerCard.showingCached) }
                            Rectangle {
                                visible: providerCard.availableAuthAction !== ""
                                implicitWidth: authButtonText.implicitWidth + 16 * root.scale
                                height: 22 * root.scale
                                radius: height / 2
                                color: authMouse.containsMouse
                                    ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.26)
                                    : Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.14)
                                border.width: 1
                                border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.28)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text {
                                    id: authButtonText
                                    anchors.centerIn: parent
                                    text: providerCard.authPending
                                        ? (root.authAction === "login" ? "Opening..." : "Logging out...")
                                        : (providerCard.availableAuthAction === "login" ? "Login" : "Logout")
                                    font.family: root.fontFamily; font.pixelSize: 8 * root.scale; color: root.cAccent
                                }
                                MouseArea {
                                    id: authMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !root.authBusy
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: root.providerAuthRequested(providerCard.card.id, providerCard.availableAuthAction)
                                }
                            }
                        }
                        Text { visible: providerCard.card.id === "opencode"; text: root.usageText(providerCard.shown); font.family: root.fontFamily; font.pixelSize: 10 * root.scale; color: root.cText }
                        Repeater {
                            model: providerCard.shown && providerCard.shown.windows ? providerCard.shown.windows : []
                            RowLayout {
                                required property var modelData
                                Layout.fillWidth: true; spacing: 5 * root.scale
                                Text { text: modelData.label || "window"; font.family: root.fontFamily; font.pixelSize: 9 * root.scale; color: root.cSub; Layout.preferredWidth: 58 * root.scale }
                                Rectangle { Layout.fillWidth: true; height: 6 * root.scale; radius: 3 * root.scale; color: Qt.rgba(1, 1, 1, 0.08); Rectangle { width: Math.max(0, Math.min(1, Number(modelData.utilization || 0) / 100)) * parent.width; height: parent.height; radius: parent.radius; color: root.statusColor(providerCard.card, providerCard.showingCached) } }
                                Text { text: root.formatNumber(modelData.utilization) + "% · " + root.resetText(modelData); font.family: root.fontFamily; font.pixelSize: 8 * root.scale; color: root.cSub; Layout.preferredWidth: 106 * root.scale }
                            }
                        }
                        Text { visible: !providerCard.shown; text: providerCard.card.error || "No data available"; font.family: root.fontFamily; font.pixelSize: 9 * root.scale; color: root.cSub; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: root.freshness(providerCard.shown, !!providerCard.shown); font.family: root.fontFamily; font.pixelSize: 8 * root.scale; color: root.cSub; elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 32 * root.scale
            radius: 10 * root.scale
            color: Qt.rgba(1, 1, 1, 0.035)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.07)
            ColumnLayout {
                anchors.fill: parent; anchors.leftMargin: 10 * root.scale; anchors.rightMargin: 10 * root.scale
                spacing: 0
                Text { text: root.refreshStateText(); font.family: root.fontFamily; font.pixelSize: 8 * root.scale; font.bold: true; color: root.loading ? root.cWarning : root.cText; Layout.fillWidth: true; elide: Text.ElideRight }
                Text { text: root.refreshMetaText(); font.family: root.fontFamily; font.pixelSize: 7 * root.scale; color: root.cSub; Layout.fillWidth: true; elide: Text.ElideRight }
            }
        }

        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: root.authStatus || (root.errorCode && root.status !== "ok" ? root.status + " · " + root.errorCode : "Per-provider status is shown above"); font.family: root.fontFamily; font.pixelSize: 8 * root.scale; color: root.cSub; elide: Text.ElideRight }
            Rectangle {
                implicitWidth: refreshText.implicitWidth + 24 * root.scale; height: 30 * root.scale; radius: height / 2
                color: refreshMouse.containsMouse && refreshMouse.enabled
                    ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.24)
                    : Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.13)
                border.width: 1; border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.30)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text { id: refreshText; anchors.centerIn: parent; text: root.loading ? (root.refreshQueued ? "Queued" : "Refreshing") : "Refresh"; font.family: root.fontFamily; font.pixelSize: 9 * root.scale; font.bold: true; color: root.cAccent }
                MouseArea { id: refreshMouse; anchors.fill: parent; enabled: !root.loading; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.refreshRequested() }
            }
        }
    }
}
