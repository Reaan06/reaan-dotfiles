# Weather Panel Redesign - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Implement a new interactive weather/calendar dashboard in `WeatherCalendarView.qml` mirroring the provided design.

**Architecture:**
- **Layout:** Use a `RowLayout` to separate the View into three distinct zones: Left (Calendar), Center (Curva Horaria/Reloj), Right (Stats/Indicators).
- **Interactivity:** State-driven components for day/hour selection.
- **Visuals:** Polar coordinate math for the hourly curve; modular components for stats.

---

### Task 1: Refactor Base Layout
- [ ] Modify `WeatherCalendarView.qml` to enforce the 3-column layout defined in the design model.
- [ ] Ensure placeholders for Calendar, Curve, and Stats are rendered.

### Task 2: Implement Calendar Grid
- [ ] Update `GridView` to support clicking/selecting days.
- [ ] Add visual state feedback for selected day.

### Task 3: Implement Hourly Curve and Central Clock
- [ ] Implement the dynamic curved layout (using polar coordinates).
- [ ] Position hour nodes along the path.
- [ ] Add central clock/date display.

### Task 4: Implement Right Stats Panel
- [ ] Create stats components (Wind, Humidity, Rain, Feels).
- [ ] Style them as circular gauges or pill components.

### Task 5: Integration and Final Polish
- [ ] Verify interactivity between zones (e.g., clicking calendar updates hourly curve).
- [ ] Final visual alignment (padding, fonts, colors).
