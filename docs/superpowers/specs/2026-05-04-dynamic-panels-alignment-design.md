# Design Spec: Dynamic Panel Alignment and Joining

**Date:** 2026-05-04
**Status:** Draft
**Author:** Gemini CLI (Senior Dotfiles Developer)

## 1. Goal

Achieve perfect visual and logical integration between the Status Bar modules and the Super+F1 (Audio) and Super+F2 (Dashboard) panels. The panels must appear to "grow" from their respective modules, maintaining alignment even when modules move due to dynamic content.

## 2. Architecture: Global Coordinate Mapping

To eliminate fragile "magic numbers," we will use dynamic coordinate resolution.

### 2.1. Anchor Exporting (StatusBar.qml)

- **Concept:** The `StatusBar` will identify its modules as "Anchors."
- **Implementation:**
  - Assign `id: mprisAnchor` to the MPRIS module and `id: clockAnchor` to the Clock module.
  - Expose `readonly property real mprisCenterWorldX` and `readonly property real clockCenterWorldX`.
  - Use `mapToItem(null, width / 2, height / 2).x` to get the global horizontal center of each module.

### 2.2. Dynamic Window Positioning (shell.qml)

- **Concept:** `PanelWindow` margins will react to the anchors' global coordinates.
- **Formula for Super+F1:** `leftMargin = statusBar.mprisCenterWorldX - (audioManagerWin.width / 2)`.
- **Formula for Super+F2:**
  - The window stays centered: `leftMargin = (screen.width - 1200) / 2`.
  - The `PanelConnector` offset is calculated: `offset = clockAnchorX - screenCenter`.

## 3. Component Details

### 3.1. Flexible PanelConnector.qml

Refactor the `Canvas` logic to support an asymmetrical "neck":

- **Properties:**
  - `neckOffset`: Horizontal shift of the top part relative to the base center.
  - `barWidth`: Width of the anchor module in the bar.
- **Visual logic:** The top curve will be centered at `neckOffset`, while the bottom edge remains fixed to the panel's width.

### 3.2. Smooth Transitions

- Use `Behavior on x` and `Behavior on neckOffset` with `Easing.OutCubic` to ensure that if a module moves (e.g., when a song title changes length), the panel or connector follows it smoothly.

## 4. Implementation Plan Summary

1.  Modify `StatusBar.qml` to expose global anchor centers.
2.  Update `PanelConnector.qml` to handle horizontal offsets via Bézier curves.
3.  Modify `shell.qml` to bind window margins and connector properties to the exported anchors.
4.  Verify alignment across different screen states (MPRIS active/inactive, Clock shifting).

## 5. Success Criteria

- Super+F1 panel is perfectly centered under the MPRIS module.
- Super+F2 panel remains centered on screen, but its visual neck aligns exactly with the Clock module.
- No visual "gaps" between the bar and the panel during animations.
