#!/usr/bin/env python3
import os
import json
import socket
import time
import glob
import sys
import subprocess
import threading
from datetime import datetime

"""
app_tracker.py — Rastreador mejorado de uso de aplicaciones via Hyprland IPC.
Soporta detección por clase y título, normalización recursiva y heartbeat constante.
"""

CACHE_FILE = os.path.expanduser('~/.cache/app_usage.json')

def get_keys():
    now = datetime.now()
    return {
        "day": now.strftime("%Y-%m-%d"),
        "week": now.strftime("%Y-%U"), 
        "month": now.strftime("%Y-%m")
    }

def find_hyprland_socket():
    sig = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE')
    xdg = os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')
    if sig:
        path = f"{xdg}/hypr/{sig}/.socket2.sock"
        if os.path.exists(path): return path
    
    sockets = glob.glob(f"{xdg}/hypr/*/.socket2.sock")
    if sockets: return sockets[0]
    return None

def normalize_name(cls_name, title=""):
    # Priorizar clase, si no hay, usar título
    raw_name = cls_name if cls_name else title
    if not raw_name: return ""
    
    name = raw_name.lower().strip()
    
    # --- 1. Palabras clave de alta prioridad (Fuzzy matching) ---
    if any(x in name for x in ["sober", "roblox", "vinegar"]):
        return "sober"
    
    if "chrome" in name or "chromium" in name: return "google-chrome"
    if "brave" in name: return "brave-browser"
    if "firefox" in name: return "firefox"
    if "vscodium" in name or "code-oss" in name: return "vscodium"
    if "visual studio code" in name or "vscode" in name: return "visual-studio-code"
    if "cursor" in name: return "cursor"
    if "windsurf" in name: return "windsurf"
    if "discord" in name or "vesktop" in name: return "discord"
    if "spotify" in name: return "spotify"
    if "steam" in name: return "steam"

    # --- 2. Limpieza recursiva de prefijos DNS ---
    while True:
        found_prefix = False
        for pref in ["org.", "com.", "io.", "net.", "gov.", "edu.", "ai."]:
            if name.startswith(pref):
                parts = name.split(".")
                if len(parts) > 1:
                    name = ".".join(parts[1:])
                    found_prefix = True
                    break
        if not found_prefix: break

    # --- 3. Limpieza de extensiones y sufijos ---
    if name.endswith(".exe"): name = name[:-4]
    if "(" in name: name = name.split("(")[0].strip()
    name = name.replace(" ", "-").replace("_", "-")
    
    # Mapeos de iconos específicos
    icon_mapping = {
        "pavucontrol": "multimedia-volume-control",
        "blueman-manager": "blueman",
        "freecad": "freecad",
        "openscad": "openscad",
        "wallpicker": "wallpaper",
        "kitty": "kitty",
        "foot": "foot",
        "alacritty": "alacritty",
    }
    
    return icon_mapping.get(name, name)

def load_data():
    if not os.path.exists(CACHE_FILE):
        return {"daily": {}, "weekly": {}, "monthly": {}, "_day": "", "_week": "", "_month": ""}
    try:
        with open(CACHE_FILE, 'r') as f:
            data = json.load(f)
            if "daily" not in data:
                return {"daily": {}, "weekly": {}, "monthly": {}, "_day": "", "_week": "", "_month": ""}
            return data
    except:
        return {"daily": {}, "weekly": {}, "monthly": {}, "_day": "", "_week": "", "_month": ""}

def save_data(data):
    try:
        os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
        temp_file = CACHE_FILE + ".tmp"
        with open(temp_file, 'w') as f:
            json.dump(data, f)
        os.rename(temp_file, CACHE_FILE)
    except Exception as e:
        print(f"Error saving data: {e}", file=sys.stderr)

def get_active_window_info():
    try:
        out = subprocess.check_output(["hyprctl", "activewindow", "-j"], stderr=subprocess.DEVNULL).decode('utf-8')
        data = json.loads(out)
        return data.get("class", ""), data.get("title", "")
    except:
        return "", ""

def get_audio_apps():
    try:
        output = subprocess.check_output(
            ["playerctl", "metadata", "--format", "{{playerName}}:{{status}}", "-a"],
            stderr=subprocess.DEVNULL
        ).decode('utf-8')
        apps = []
        for line in output.strip().split('\n'):
            if ":Playing" in line:
                raw_name = line.split(':')[0].lower().split('.')[0]
                name = normalize_name(raw_name)
                if name: apps.append(name)
        return list(set(apps))
    except: return []

def get_package_counts():
    try:
        pacman_out = subprocess.check_output(["pacman", "-Qn"], stderr=subprocess.DEVNULL).decode("utf-8")
        pacman_count = len(pacman_out.strip().split("\n")) if pacman_out.strip() else 0
        yay_out = subprocess.check_output(["pacman", "-Qm"], stderr=subprocess.DEVNULL).decode("utf-8")
        yay_count = len(yay_out.strip().split("\n")) if yay_out.strip() else 0
        return pacman_count, yay_count
    except:
        return 0, 0

class AppTracker:
    def __init__(self):
        self.store = load_data()
        cls, title = get_active_window_info()
        self.current_app = normalize_name(cls, title)
        self.lock = threading.Lock()
        self.last_tick = time.time()
        self.last_pkg_check = 0
        self.running = True
        
        keys = get_keys()
        for k in ["_day", "_week", "_month"]:
            if k not in self.store: self.store[k] = keys[k[1:]]

    def check_resets(self):
        keys = get_keys()
        changed = False
        with self.lock:
            if self.store.get("_day") != keys["day"]:
                self.store["daily"] = {}
                self.store["_day"] = keys["day"]
                changed = True
            if self.store.get("_week") != keys["week"]:
                self.store["weekly"] = {}
                self.store["_week"] = keys["week"]
                changed = True
            if self.store.get("_month") != keys["month"]:
                self.store["monthly"] = {}
                self.store["_month"] = keys["month"]
                changed = True
        return changed

    def update_stats(self):
        now = time.time()
        delta = now - self.last_tick
        self.last_tick = now
        
        if delta > 60 or delta < 0: return

        active_apps = set()
        if self.current_app: active_apps.add(self.current_app)
        for app in get_audio_apps(): active_apps.add(app)
            
        with self.lock:
            self.store["_active"] = list(active_apps)
            if now - self.last_pkg_check > 600:
                p, y = get_package_counts()
                self.store["_pacman_count"] = p
                self.store["_yay_count"] = y
                self.last_pkg_check = now

            for p in ["daily", "weekly", "monthly"]:
                if "_total_" not in self.store[p]: self.store[p]["_total_"] = {"time": 0, "opens": 0}
                self.store[p]["_total_"]["time"] += delta
                for app in active_apps:
                    if app not in self.store[p]: self.store[p][app] = {"time": 0, "opens": 0}
                    self.store[p][app]["time"] += delta

    def heartbeat_loop(self):
        last_save = time.time()
        while self.running:
            self.check_resets()
            self.update_stats()
            if time.time() - last_save > 5:
                with self.lock: save_data(self.store)
                last_save = time.time()
            time.sleep(1)

    def handle_event(self, line):
        if line.startswith('activewindow>>'):
            payload = line.split('>>', 1)[1]
            parts = payload.split(',', 1)
            cls = parts[0].strip() if len(parts) > 0 else ""
            title = parts[1].strip() if len(parts) > 1 else ""
            new_app = normalize_name(cls, title)
            with self.lock: self.current_app = new_app

        elif line.startswith('openwindow>>'):
            payload = line.split('>>', 1)[1]
            parts = payload.split(',')
            if len(parts) >= 3:
                app_class = parts[2].strip()
                app_name = normalize_name(app_class)
                if app_name:
                    with self.lock:
                        for p in ["daily", "weekly", "monthly"]:
                            if app_name not in self.store[p]: self.store[p][app_name] = {"time": 0, "opens": 0}
                            self.store[p][app_name]["opens"] += 1

def main():
    sock_path = find_hyprland_socket()
    if not sock_path:
        print("Hyprland socket not found", file=sys.stderr)
        sys.exit(1)

    tracker = AppTracker()
    threading.Thread(target=tracker.heartbeat_loop, daemon=True).start()

    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(sock_path)
        while True:
            raw = s.recv(4096).decode('utf-8', errors='ignore')
            if not raw: break
            for line in raw.strip().split('\n'):
                tracker.handle_event(line.strip())
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
    finally:
        tracker.running = False
        save_data(tracker.store)

if __name__ == "__main__":
    main()
