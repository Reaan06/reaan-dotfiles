# Dynamic Panel Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement dynamic horizontal alignment for Super+F1 and Super+F2 panels using global coordinate mapping and a flexible connector component.

**Architecture:** 
1. `StatusBar.qml` exposes global X coordinates of MPRIS and Clock modules.
2. `PanelConnector.qml` is refactored to allow a horizontal offset for its top "neck" while keeping its base aligned with the panel.
3. `shell.qml` binds panel window margins to these dynamic coordinates.

**Tech Stack:** Quickshell (QtQuick/QML)

---

### Task 1: Expose Global Anchors in StatusBar.qml

**Files:**
- Modify: `dot_config/quickshell/StatusBar.qml`

- [ ] **Step 1: Add IDs to anchor modules**
Locate the MPRIS `Pill` and the Clock/Weather `Pill`. Add `id: mprisAnchor` and `id: clockAnchor` respectively.

- [ ] **Step 2: Add coordinate helper functions and properties**
Add the following to the root `Item` in `StatusBar.qml`:
```qml
readonly property real mprisCenterWorldX: getCenterWorldX(mprisAnchor)
readonly property real clockCenterWorldX: getCenterWorldX(clockAnchor)

function getCenterWorldX(item) {
    if (!item) return 0
    // Map center of the item to global window coordinates
    var p = item.mapToItem(null, item.width / 2, 0)
    return p.x
}
```

- [ ] **Step 3: Commit**
```bash
git add dot_config/quickshell/StatusBar.qml
git commit -m "feat(statusbar): expose global center coordinates for mpris and clock"
```

### Task 2: Refactor PanelConnector.qml for Flexibility

**Files:**
- Modify: `dot_config/quickshell/components/PanelConnector.qml`

- [ ] **Step 1: Add neckOffset property**
Add `property real neckOffset: 0` to the root `Canvas`.

- [ ] **Step 2: Update Canvas drawing logic**
Update the `onPaint` handler to draw an asymmetrical connector:
```javascript
onPaint: {
    var ctx = getContext("2d");
    ctx.reset();
    ctx.fillStyle = root.color;
    
    var centerX = width / 2;
    var topCenter = centerX + neckOffset;
    var halfBar = barWidth / 2;
    
    ctx.beginPath();
    // Top line (at the bar)
    ctx.moveTo(topCenter - halfBar, -1);
    ctx.lineTo(topCenter + halfBar, -1);
    
    // Right curve
    ctx.bezierCurveTo(
        topCenter + halfBar, connectorHeight * 0.4,
        centerX + (width/2 - cornerRadius), connectorHeight * 0.6,
        width + 1, connectorHeight + 1
    );
    
    // Bottom line (at the panel)
    ctx.lineTo(-1, connectorHeight + 1);
    
    // Left curve
    ctx.bezierCurveTo(
        centerX - (width/2 - cornerRadius), connectorHeight * 0.6,
        topCenter - halfBar, connectorHeight * 0.4,
        topCenter - halfBar, -1
    );
    
    ctx.closePath();
    ctx.fill();
}
```

- [ ] **Step 3: Commit**
```bash
git add dot_config/quickshell/components/PanelConnector.qml
git commit -m "refactor(components): make PanelConnector asymmetrical with neckOffset"
```

### Task 3: Update Panels to use the new Connector Logic

**Files:**
- Modify: `dot_config/quickshell/AudioManager.qml`
- Modify: `dot_config/quickshell/SuperF2Panel.qml`

- [ ] **Step 1: Update AudioManager.qml**
Expose `neckOffset` and pass it to the `PanelConnector`.
```qml
// In AudioManager.qml root
property real neckOffset: 0

// In PanelConnector usage
PanelConnector {
    neckOffset: root.neckOffset
    // ... other props
}
```

- [ ] **Step 2: Update SuperF2Panel.qml**
Expose `neckOffset` and pass it to the `PanelConnector`.
```qml
// In SuperF2Panel.qml root
property real neckOffset: 0

// In PanelConnector usage
PanelConnector {
    neckOffset: root.neckOffset
    // ... other props
}
```

- [ ] **Step 3: Commit**
```bash
git add dot_config/quickshell/AudioManager.qml dot_config/quickshell/SuperF2Panel.qml
git commit -m "feat(panels): support neckOffset in AudioManager and SuperF2Panel"
```

### Task 4: Integrate everything in shell.qml

**Files:**
- Modify: `dot_config/quickshell/shell.qml`

- [ ] **Step 1: Get reference to StatusBar**
Add an ID to the `StatusBar` in the `Variants` block:
```qml
StatusBar {
    id: statusBar
    anchors.fill: parent
}
```

- [ ] **Step 2: Bind Audio Manager Window position**
Update `audioManagerWin` margins:
```qml
margins {
    top: 48 
    left: statusBar.mprisCenterWorldX - (audioManagerWin.width / 2)
}
// Add Behavior for smooth movement
Behavior on margins.left { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
```

- [ ] **Step 3: Bind Super F2 Window position and calculate neckOffset**
Update `superF2Win` and pass `neckOffset` to the panel:
```qml
PanelWindow {
    id: superF2Win
    // ...
    margins {
        top: 48
        left: (screen.width - 1200) / 2
    }
    
    SuperF2Panel {
        anchors.fill: parent
        active: superF2Visible
        neckOffset: statusBar.clockCenterWorldX - (superF2Win.x + superF2Win.width / 2)
    }
}
```

- [ ] **Step 4: Verify and Commit**
Check for visual gaps and smoothness.
```bash
git add dot_config/quickshell/shell.qml
git commit -m "feat(shell): implement dynamic alignment logic for all panels"
```
