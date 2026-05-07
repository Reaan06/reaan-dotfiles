import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    objectName: "SystemMonitor.qml"
    color: "transparent"

    property real scale: (parent && parent.scale) ? parent.scale : 1.0
    readonly property string font: "JetBrains Mono Nerd Font"
    
    // ═══════════════════════════════════════════════
    // THEME — Dinámico
    // ═══════════════════════════════════════════════
    property color cMauve: "#cba6f7"
    property color cBlue: "#89b4fa"
    property color cTeal: "#94e2d5"
    property color cPeach: "#fab387"
    property color cText: "#cdd6f4"
    property color cSub: "#6c7086"
    property color cBg: Qt.rgba(0.1, 0.1, 0.15, 0.3)

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
            cTeal  = parts[2] || cTeal
            cMauve = parts[3] || cMauve
            cPeach = parts[4] || cPeach
            cText  = parts[6] || cText
            cSub   = parts[7] || cSub
        } catch (e) {
            console.log("Error parsing palette in SystemMonitor: " + e)
        }
    }

    Process {
        id: paletteProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/.palette 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { root.parsePalette(text.trim()) } }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: paletteProc.running = true }

    property var stats: ({
        cpu: {name: "CPU", usage: 0, temp: 0},
        gpu: {name: "GPU", usage: 0, temp: 0},
        mem: {used: 0, total: 0, perc: 0},
        storage: {used: 0, total: 0, perc: 0},
        net: {down: 0, up: 0, t_down: 0, t_up: 0, history: [0,0,0,0,0,0,0,0,0,0]}
    })

    property real sCpu: 0; Behavior on sCpu { NumberAnimation { duration: 1000; easing.type: Easing.OutCubic } }
    property real sGpu: 0; Behavior on sGpu { NumberAnimation { duration: 1000; easing.type: Easing.OutCubic } }
    property real sMem: 0; Behavior on sMem { NumberAnimation { duration: 1000; easing.type: Easing.OutCubic } }
    property real sSt: 0;  Behavior on sSt { NumberAnimation { duration: 1000; easing.type: Easing.OutCubic } }

    Process {
        id: statsProc; command: ["sh", "-c", "python3 ~/.config/scripts/get_system_stats.py"]
        stdout: StdioCollector { 
            onStreamFinished: { 
                try { 
                    let raw = text.trim();
                    let jsonStart = raw.indexOf('{');
                    if (jsonStart !== -1) {
                        let s = JSON.parse(raw.substring(jsonStart)); 
                        root.stats = s; 
                        root.sCpu = s.cpu.usage || 0; 
                        root.sGpu = s.gpu.usage || 0; 
                        root.sMem = s.mem.perc || 0; 
                        root.sSt = s.storage.perc || 0; 
                        netCanvas.requestPaint();
                        root.checkTemps(s.cpu.temp || 0, s.gpu.temp || 0);
                    }
                } catch(e) { console.log("Error parsing system stats: " + e); } 
            } 
        }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { statsProc.running = false; statsProc.running = true } }

    property bool tempWarningSent: false
    property bool tempCriticalSent: false

    Process {
        id: notifyProc
        property string msg: ""
        property string icon: ""
        property string urgency: "normal"
        command: ["sh", "-c", "notify-send -u " + urgency + " -i " + icon + " 'Alerta de Temperatura' '" + msg + "'"]
    }

    function checkTemps(cpuTemp, gpuTemp) {
        var maxTemp = Math.max(cpuTemp, gpuTemp);
        if (maxTemp >= 90) {
            if (!tempCriticalSent) {
                notifyProc.msg = "Temperatura CRÍTICA (" + maxTemp + "°C). El sistema se está sobrecalentando severamente.";
                notifyProc.icon = "dialog-error";
                notifyProc.urgency = "critical";
                notifyProc.running = false;
                notifyProc.running = true;
                tempCriticalSent = true;
                tempWarningSent = true;
            }
        } else if (maxTemp >= 80) {
            if (!tempWarningSent) {
                notifyProc.msg = "Temperatura alta (" + maxTemp + "°C). El sistema se está calentando.";
                notifyProc.icon = "dialog-warning";
                notifyProc.urgency = "normal";
                notifyProc.running = false;
                notifyProc.running = true;
                tempWarningSent = true;
            }
            tempCriticalSent = false;
        } else {
            tempWarningSent = false;
            tempCriticalSent = false;
        }
    }

    function getTempColor(temp, defaultColor) {
        if (temp >= 90) return "#f38ba8"; // Rojo crítico
        if (temp >= 80) return "#fab387"; // Naranja advertencia
        return defaultColor;
    }

    component CircularGauge: Item {
        property real fillVal: 0
        property color fillCol: "white"
        width: 130 * root.scale; height: 130 * root.scale
        Shape {
            anchors.fill: parent; layer.enabled: true; layer.samples: 4
            ShapePath { strokeColor: Qt.rgba(1,1,1,0.05); strokeWidth: 12 * root.scale; fillColor: "transparent"; capStyle: ShapePath.RoundCap; PathAngleArc { centerX: 65 * root.scale; centerY: 65 * root.scale; radiusX: 55 * root.scale; radiusY: 55 * root.scale; startAngle: -90; sweepAngle: 360 } }
            ShapePath { strokeColor: fillCol; strokeWidth: 12 * root.scale; fillColor: "transparent"; capStyle: ShapePath.RoundCap; PathAngleArc { centerX: 65 * root.scale; centerY: 65 * root.scale; radiusX: 55 * root.scale; radiusY: 55 * root.scale; startAngle: -90; sweepAngle: Math.max(0.1, (fillVal / 100) * 360) } }
        }
        Text { anchors.centerIn: parent; text: Math.round(fillVal) + "%"; color: root.cText; font.pixelSize: 20 * root.scale; font.bold: true; font.family: root.font }
    }

    ColumnLayout {
        anchors.fill: parent; spacing: 25 * root.scale
        RowLayout {
            Layout.fillWidth: true; spacing: 25 * root.scale
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 180 * root.scale; radius: 24 * root.scale; color: root.cBg; border.color: Qt.rgba(1,1,1,0.05); border.width: 1 * root.scale
                ColumnLayout { anchors.fill: parent; anchors.margins: 25 * root.scale; spacing: 12 * root.scale
                    RowLayout { 
                        spacing: 8 * root.scale
                        Text { text: "󰍛"; font.pixelSize: 22 * root.scale; color: root.cBlue }
                        Text { text: "CPU - " + root.stats.cpu.name; font.family: root.font; font.pixelSize: 14 * root.scale; font.bold: true; color: root.cText; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: Math.round(root.sCpu) + "%"; font.family: root.font; font.pixelSize: 24 * root.scale; font.bold: true; color: root.cBlue } 
                    }
                    Text { text: (root.stats.cpu.temp || 0).toFixed(0) + "°C Temp"; font.family: root.font; font.pixelSize: 16 * root.scale; font.bold: (root.stats.cpu.temp >= 80); color: root.getTempColor(root.stats.cpu.temp || 0, root.cSub) }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 6 * root.scale; radius: 3 * root.scale; color: Qt.rgba(1, 1, 1, 0.05)
                        Rectangle { width: Math.max(4 * root.scale, parent.width * (root.sCpu / 100)); height: parent.height; radius: 3 * root.scale; color: root.getTempColor(root.stats.cpu.temp || 0, root.cBlue) } 
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 180 * root.scale; radius: 24 * root.scale; color: root.cBg; border.color: Qt.rgba(1,1,1,0.05); border.width: 1 * root.scale
                ColumnLayout { anchors.fill: parent; anchors.margins: 25 * root.scale; spacing: 12 * root.scale
                    RowLayout { 
                        spacing: 8 * root.scale
                        Text { text: "󰢮"; font.pixelSize: 22 * root.scale; color: root.cTeal }
                        Text { text: "GPU - " + root.stats.gpu.name; font.family: root.font; font.pixelSize: 14 * root.scale; font.bold: true; color: root.cText; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: Math.round(root.sGpu) + "%"; font.family: root.font; font.pixelSize: 24 * root.scale; font.bold: true; color: root.cTeal } 
                    }
                    Text { text: (root.stats.gpu.temp || 0).toFixed(0) + "°C Temp"; font.family: root.font; font.pixelSize: 16 * root.scale; font.bold: (root.stats.gpu.temp >= 80); color: root.getTempColor(root.stats.gpu.temp || 0, root.cSub) }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 6 * root.scale; radius: 3 * root.scale; color: Qt.rgba(1, 1, 1, 0.05)
                        Rectangle { width: Math.max(4 * root.scale, parent.width * (root.sGpu / 100)); height: parent.height; radius: 3 * root.scale; color: root.getTempColor(root.stats.gpu.temp || 0, root.cTeal) } 
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 25 * root.scale
            Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; radius: 24 * root.scale; color: root.cBg; border.color: Qt.rgba(1,1,1,0.05); border.width: 1 * root.scale
                ColumnLayout { anchors.fill: parent; anchors.margins: 20 * root.scale
                    Text { text: "Memory"; font.family: root.font; font.pixelSize: 14 * root.scale; font.bold: true; color: root.cText; Layout.alignment: Qt.AlignHCenter }
                    CircularGauge { fillVal: root.sMem; fillCol: root.cMauve; Layout.alignment: Qt.AlignHCenter }
                    Text { text: root.stats.mem.used + " / " + root.stats.mem.total + " GiB"; font.family: root.font; font.pixelSize: 12 * root.scale; color: root.cSub; Layout.alignment: Qt.AlignHCenter } 
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; radius: 24 * root.scale; color: root.cBg; border.color: Qt.rgba(1,1,1,0.05); border.width: 1 * root.scale
                ColumnLayout { anchors.fill: parent; anchors.margins: 20 * root.scale
                    Text { text: "Storage"; font.family: root.font; font.pixelSize: 14 * root.scale; font.bold: true; color: root.cText; Layout.alignment: Qt.AlignHCenter }
                    CircularGauge { fillVal: root.sSt; fillCol: root.cBlue; Layout.alignment: Qt.AlignHCenter }
                    Text { text: root.stats.storage.used + " / " + root.stats.storage.total + " GiB"; font.family: root.font; font.pixelSize: 12 * root.scale; color: root.cSub; Layout.alignment: Qt.AlignHCenter } 
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; radius: 24 * root.scale; color: root.cBg; border.color: Qt.rgba(1,1,1,0.05); border.width: 1 * root.scale
                ColumnLayout { anchors.fill: parent; anchors.margins: 25 * root.scale; spacing: 10 * root.scale
                    RowLayout { 
                        spacing: 8 * root.scale
                        Text { text: "󰓅 Network"; font.family: root.font; font.pixelSize: 14 * root.scale; font.bold: true; color: root.cText }
                        Item { Layout.fillWidth: true }
                        Text { text: "Total: " + ((root.stats.net.t_down || 0) + (root.stats.net.t_up || 0)).toFixed(2) + " GB"; font.family: root.font; font.pixelSize: 12 * root.scale; color: root.cPeach; font.bold: true } 
                    }
                    Canvas { id: netCanvas; Layout.fillWidth: true; Layout.preferredHeight: 80 * root.scale
                        onPaint: { var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height); let h = root.stats.net.history || []; if (h.length < 2) return; let maxV = Math.max(...h, 50); let step = width / (h.length - 1); var grad = ctx.createLinearGradient(0, 0, 0, height); grad.addColorStop(0, Qt.rgba(root.cPeach.r, root.cPeach.g, root.cPeach.b, 0.2)); grad.addColorStop(1, "transparent"); ctx.beginPath(); ctx.moveTo(0, height); for (let i = 0; i < h.length; i++) ctx.lineTo(i * step, height - (h[i] / maxV) * height); ctx.lineTo(width, height); ctx.fillStyle = grad; ctx.fill(); ctx.beginPath(); ctx.moveTo(0, height - (h[0] / maxV) * height); for (let i = 1; i < h.length; i++) ctx.lineTo(i * step, height - (h[i] / maxV) * height); ctx.strokeStyle = root.cPeach; ctx.lineWidth = 2 * root.scale; ctx.stroke(); }
                    }
                    RowLayout { spacing: 20 * root.scale
                        ColumnLayout { 
                            Text { text: "DOWN"; font.family: root.font; font.pixelSize: 10 * root.scale; color: root.cSub }
                            Text { text: (root.stats.net.t_down || 0).toFixed(2) + " GB"; font.family: root.font; font.pixelSize: 14 * root.scale; font.bold: true; color: root.cText } 
                        }
                        ColumnLayout { 
                            Text { text: "UP"; font.family: root.font; font.pixelSize: 10 * root.scale; color: root.cSub }
                            Text { text: (root.stats.net.t_up || 0).toFixed(2) + " GB"; font.family: root.font; font.pixelSize: 14 * root.scale; font.bold: true; color: root.cText } 
                        } 
                    }
                }
            }
        }
    }
}
