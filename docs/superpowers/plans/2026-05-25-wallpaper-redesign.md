# Wallpaper Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Redesign the wallpaper picker into a Quickshell component with file upload capability to dotfiles.

**Architecture:** Quickshell (QML) for UI, Python bridge for file operations, Shell scripts for system integration.

**Tech Stack:** QML, Python 3, Bash, Quickshell, Hyprland.

---

### Task 1: Bridge & Backend (Agent: architect)
**Files:**
- Create: `dot_config/scripts/wallpaper_bridge.py`
- Modify: `dot_config/scripts/apply-wallpaper.sh`

- [ ] **Step 1: Create the Python Bridge**
Create a script that lists images in `~/reaan-dotfiles/wallps/` as JSON and provides a command to copy a file from a given path to that folder.
- [ ] **Step 2: Update Apply Script**
Ensure `apply-wallpaper.sh` handles paths correctly and triggers color extraction.

### Task 2: UI Design (Agent: ux_designer)
**Files:**
- Create: `dot_config/quickshell/WallpaperPicker.qml`
- Create: `dot_config/quickshell/components/WallpaperCard.qml`

- [ ] **Step 1: Create WallpaperCard component**
A styled card with thumbnail and hover effects.
- [ ] **Step 2: Create Main WallpaperPicker UI**
Grid layout, transparent background, blur, and "Upload" button.

### Task 3: Quickshell Integration (Agent: coder)
**Files:**
- Modify: `dot_config/quickshell/shell.qml`

- [ ] **Step 1: Register Wallpaper Visibility State**
Add logic to monitor `/tmp/qs-wallpaper-picker`.
- [ ] **Step 2: Add WallpaperPicker Window**
Instantiate the `WallpaperPicker` component as a `PanelWindow`.

### Task 4: System Integration & Keybinds (Agent: devops_engineer)
**Files:**
- Create: `dot_config/scripts/wallpaper-toggle.sh`
- Modify: `dot_config/hypr/keybinds.conf`

- [ ] **Step 1: Create Toggle Script**
A bash script to toggle the "visible/hidden" state in `/tmp/qs-wallpaper-picker`.
- [ ] **Step 2: Update Hyprland Keybind**
Point `Super + W` to the new toggle script.

### Task 5: Testing & Validation (Agent: tester)
**Files:**
- Create: `tests/test_wallpaper_flow.sh`

- [ ] **Step 1: Verify Listing & Upload**
Ensure the bridge returns correct JSON and copies files.
- [ ] **Step 2: Verify UI & Application**
Ensure `Super + W` opens the panel and selecting a wallpaper applies it correctly.

---
**Plan saved. Ready to dispatch subagents.**
