# Plan: Dynamic Panels Alignment & Proportional Sizing

Implement functionality to open Super+F1 (Audio Manager) and Super+F2 (Dashboard) panels only on the monitor with the mouse cursor, and make their sizes proportional to the screen dimensions.

## Objective
- Ensure panels open only on the active monitor (where the mouse is).
- Scale panel dimensions relative to the monitor's resolution.

## Key Files & Context
- `dot_config/scripts/audio-manager.sh`: Toggles Audio Manager state.
- `dot_config/scripts/super-f2-toggle.sh`: Toggles Super F2 Dashboard state.
- `dot_config/quickshell/shell.qml`: Manages panel windows and visibility.

## Implementation Steps

### 1. Update Scripts to Capture Active Monitor
Modify the toggle scripts to detect the focused monitor (which typically follows the mouse in Hyprland) and include its name in the state file.

- **File**: `dot_config/scripts/audio-manager.sh`
  - Update `toggle`, `show` cases to include monitor name using `hyprctl monitors -j`.
- **File**: `dot_config/scripts/super-f2-toggle.sh`
  - Update `toggle`, `show` cases to include monitor name using `hyprctl monitors -j`.

### 2. Update Quickshell Shell for Per-Monitor Visibility
Modify `shell.qml` to parse the monitor name from state files and apply conditional visibility and proportional sizing.

- **File**: `dot_config/quickshell/shell.qml`
  - Add `audioManagerMonitor` and `superF2Monitor` properties.
  - Update `amStateProc` to split the state file content (e.g., "visible eDP-1") into state and monitor.
  - Update `audioManagerWin`:
    - Set `visible` to `(audioManagerVisible || amAnimating) && screen.name === audioManagerMonitor`.
    - Change `implicitWidth` to `Math.max(400, Math.min(600, screen.width * 0.3))`.
    - Change `implicitHeight` to `Math.max(600, Math.min(800, screen.height * 0.65))`.
  - Update `superF2Win`:
    - Set `visible` to `(superF2Visible || f2Animating) && screen.name === superF2Monitor`.
    - Change `implicitWidth` to `screen.width * 0.8`.
    - Change `implicitHeight` to `screen.height * 0.75`.
    - Update `margins.left` to `(screen.width - width) / 2` to maintain centering.

## Verification & Testing
- Press Super+F1 and Super+F2 on different monitors.
- Verify panels only appear on the monitor where the cursor was located at the time of pressing.
- Verify panels resize correctly on different monitor resolutions (if available).
- Ensure animations still work correctly.
