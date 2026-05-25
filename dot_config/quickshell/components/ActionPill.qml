import QtQuick

// ActionPill: botón pill reutilizable (BT/WiFi panels).
Rectangle {
    id: pill

    required property string label
    required property string iconGlyph
    property real uiScale: 1.0
    property string uiFont: "JetBrains Mono Nerd Font"
    property color accentColor: "#cba6f7"
    property color onAccentFg: "#11111b"
    property color fgColor: "#cdd6f4"
    property color dangerColor: Qt.rgba(0.95, 0.55, 0.66, 1)
    property bool primary: false
    property bool danger: false
    property bool busy: false

    implicitWidth: pillRow.implicitWidth + 28 * uiScale
    implicitHeight: 36 * uiScale
    radius: implicitHeight / 2
    opacity: busy ? 0.55 : 1
    color: {
        if (!pillMa.enabled) return Qt.rgba(1, 1, 1, 0.04)
        if (danger && pillMa.containsMouse) return Qt.rgba(dangerColor.r, dangerColor.g, dangerColor.b, 0.28)
        if (danger) return Qt.rgba(dangerColor.r, dangerColor.g, dangerColor.b, 0.14)
        if (primary) return accentColor
        if (pillMa.containsMouse) return Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.22)
        return Qt.rgba(1, 1, 1, 0.08)
    }
    border.color: primary ? "transparent" : Qt.rgba(1, 1, 1, 0.1)
    border.width: primary ? 0 : 1

    Behavior on color { ColorAnimation { duration: 150 } }

    Row {
        id: pillRow
        anchors.centerIn: parent
        spacing: 8 * uiScale
        Text {
            text: pill.iconGlyph
            font.family: uiFont
            font.pixelSize: 14 * uiScale
            color: pill.primary ? onAccentFg : (pill.danger ? dangerColor : fgColor)
        }
        Text {
            text: pill.label
            font.family: uiFont
            font.pixelSize: 12 * uiScale
            font.bold: true
            color: pill.primary ? onAccentFg : (pill.danger ? dangerColor : fgColor)
        }
    }

    MouseArea {
        id: pillMa
        anchors.fill: parent
        hoverEnabled: true
        enabled: !pill.busy
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: pill.clicked()
    }

    signal clicked()
}
