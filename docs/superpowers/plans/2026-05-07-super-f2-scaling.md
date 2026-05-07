# Super + F2 Panel Scaling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix proportionality of the Super + F2 dashboard on small screens by implementing systematic scaling and flexible layouts.

**Architecture:** We will propagate a `scale` property from `shell.qml` down to all sub-components. Components will use this scale for font sizes, margins, and fixed-size elements, while using QML Layouts to fill available space.

**Tech Stack:** QML (Qt 6 / Quickshell)

---

### Task 1: Adaptive Scaling in shell.qml

**Files:**
- Modify: `dot_config/quickshell/shell.qml`

- [ ] **Step 1: Update scaling logic and window sizing**
Update `superF2Win` to have more adaptive dimensions and a better scale calculation.

```qml
// In dot_config/quickshell/shell.qml

// ... inside superF2Win PanelWindow ...
            implicitWidth: Math.min(1200, screen.width * 0.9)
            implicitHeight: Math.min(800, screen.height * 0.85)
// ...
            SuperF2Panel {
                // ...
                scale: Math.max(0.65, Math.min(parent.width / 1200, parent.height / 800))
            }
```

- [ ] **Step 2: Commit changes**
```bash
git add dot_config/quickshell/shell.qml
git commit -m "style: make SuperF2Panel window sizing and scaling more adaptive"
```

### Task 2: Scaling in Weather Components (Part 1: Calendar & Details)

**Files:**
- Modify: `dot_config/quickshell/WeatherCalendar.qml`
- Modify: `dot_config/quickshell/WeatherDetails.qml`

- [ ] **Step 1: Implement scaling in WeatherCalendar.qml**
Add `property real scale: 1.0` and apply it to all dimensions.

```qml
// In dot_config/quickshell/WeatherCalendar.qml
Rectangle {
    id: root
    // ...
    property real scale: 1.0
    radius: 30 * scale
    // ...
    ColumnLayout {
        anchors.margins: 20 * root.scale
        spacing: 15 * root.scale
        // ... apply scale to font.pixelSize, width, height, radius ...
    }
}
```

- [ ] **Step 2: Implement scaling in WeatherDetails.qml**
Add `property real scale: 1.0` and apply it to all dimensions.

```qml
// In dot_config/quickshell/WeatherDetails.qml
Rectangle {
    id: root
    property real scale: 1.0
    radius: 20 * scale
    // ...
    ColumnLayout {
        anchors.margins: 20 * root.scale
        spacing: 20 * root.scale
        // ... apply scale to font.pixelSize, width, height, radius ...
    }
}
```

- [ ] **Step 3: Commit changes**
```bash
git add dot_config/quickshell/WeatherCalendar.qml dot_config/quickshell/WeatherDetails.qml
git commit -m "style: implement scaling in WeatherCalendar and WeatherDetails"
```

### Task 3: Scaling in Weather Components (Part 2: Timeline & View)

**Files:**
- Modify: `dot_config/quickshell/WeatherTimeline.qml`
- Modify: `dot_config/quickshell/WeatherCalendarView.qml`

- [ ] **Step 1: Implement scaling in WeatherTimeline.qml**
Add `property real scale: 1.0` and apply it to all dimensions.

```qml
// In dot_config/quickshell/WeatherTimeline.qml
Item {
    id: root
    property real scale: 1.0
    // ... apply scale to font.pixelSize, spacing, width, height, radius ...
}
```

- [ ] **Step 2: Update WeatherCalendarView.qml to propagate scale correctly**
Ensure children receive the scale.

```qml
// In dot_config/quickshell/WeatherCalendarView.qml
WeatherCalendar {
    // ...
    scale: root.scale
}
// ... repeat for WeatherTimeline and WeatherDetails
```

- [ ] **Step 3: Commit changes**
```bash
git add dot_config/quickshell/WeatherTimeline.qml dot_config/quickshell/WeatherCalendarView.qml
git commit -m "style: implement scaling in WeatherTimeline and propagate in WeatherCalendarView"
```

### Task 4: Scaling in System Monitor & App Usage

**Files:**
- Modify: `dot_config/quickshell/SystemMonitor.qml`
- Modify: `dot_config/quickshell/AppUsageView.qml`

- [ ] **Step 1: Ensure full scaling in SystemMonitor.qml**
Audit and fix any missing scale multiplications.

- [ ] **Step 2: Implement scaling in AppUsageView.qml**
Add `property real scale: 1.0` and apply it to all dimensions.

- [ ] **Step 3: Commit changes**
```bash
git add dot_config/quickshell/SystemMonitor.qml dot_config/quickshell/AppUsageView.qml
git commit -m "style: finalize scaling in SystemMonitor and AppUsageView"
```
