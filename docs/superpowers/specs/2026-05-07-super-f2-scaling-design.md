# Design Spec: Super + F2 Panel Proportional Scaling

## Problem Statement
The Super + F2 dashboard panel does not scale correctly on small screens. Many sub-components use fixed pixel values and do not implement the scaling property passed from the parent. This results in overlapping elements, cut-off content, and poor readability on lower resolutions.

## Proposed Solution
Implement a systematic but flexible scaling mechanism across the entire dashboard. We will transition from hardcoded sizes to a combination of QML `Layout` management (filling space) and proportional scaling for non-layout elements (fonts, icons, fixed-radius borders).

## Architecture Changes

### 1. Adaptive Window Scaling (`shell.qml`)
- Adjust the `superF2Win` `implicitWidth` and `implicitHeight` to be more adaptive.
- Refine the `scale` calculation to use a more appropriate reference resolution for small screens.
- Ensure the minimum scale is sufficient for usability.

### 2. Systematic Scaling Propagation
- Ensure all view components (`SystemMonitor.qml`, `WeatherCalendarView.qml`, `GitHubDashboardView.qml`, `AppUsageView.qml`) define and correctly utilize a `scale` property.
- Propagate this scale to all child components (`WeatherCalendar`, `WeatherTimeline`, `WeatherDetails`, etc.).

### 3. Flexible Layout Refactoring
- Replace fixed `width` and `height` with `Layout.fillWidth`, `Layout.fillHeight`, `Layout.preferredWidth`, and `Layout.preferredHeight` where appropriate.
- Use the `scale` property for:
    - `font.pixelSize`
    - `radius`
    - `spacing` and `margins`
    - Fixed-size icons and decorative elements.

## Impacted Files
- `dot_config/quickshell/shell.qml`
- `dot_config/quickshell/SuperF2Panel.qml`
- `dot_config/quickshell/WeatherCalendarView.qml`
- `dot_config/quickshell/WeatherCalendar.qml`
- `dot_config/quickshell/WeatherTimeline.qml`
- `dot_config/quickshell/WeatherDetails.qml`
- `dot_config/quickshell/SystemMonitor.qml`
- `dot_config/quickshell/AppUsageView.qml`
- `dot_config/quickshell/GitHubDashboardView.qml`

## Success Criteria
- The panel opens without overlapping elements on screens as small as 1366x768.
- Text and icons remain readable and proportional.
- Layout adapts to different aspect ratios without content overflow.
