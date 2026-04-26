#!/usr/bin/env python3
import os
import json
import socket
import time
import glob
import sys
from datetime import datetime

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

def load_data():
    if not os.path.exists(CACHE_FILE):
        return {"daily": {}, "weekly": {}, "monthly": {}, "_day": "", "_week": "", "_month": ""}
    try:
        with open(CACHE_FILE, 'r') as f:
            data = json.load(f)
            if "daily" not in data: # Migración forzada
                return {"daily": {}, "weekly": {}, "monthly": {}, "_day": "", "_week": "", "_month": ""}
            
            # Limpieza y normalización de datos existentes
            modified = False
            for period in ["daily", "weekly", "monthly"]:
                new_period_data = {}
                for app_name, stats in data[period].items():
                    if app_name.startswith("_"):
                        new_period_data[app_name] = stats
                        continue
                    
                    norm_name = normalize_name(app_name)
                    if norm_name not in new_period_data:
                        new_period_data[norm_name] = stats
                    else:
                        # Fusionar estadísticas
                        new_period_data[norm_name]["time"] += stats.get("time", 0)
                        new_period_data[norm_name]["opens"] += stats.get("opens", 0)
                    
                    if norm_name != app_name:
                        modified = True
                data[period] = new_period_data
            
            if modified:
                save_data(data)
                
            return data
    except Exception as e:
        print(f"Error loading data: {e}", file=sys.stderr)
        return {"daily": {}, "weekly": {}, "monthly": {}, "_day": "", "_week": "", "_month": ""}

def save_data(data):
    try:
        os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
        with open(CACHE_FILE, 'w') as f:
            json.dump(data, f)
    except Exception as e:
        print(f"Error saving data: {e}", file=sys.stderr)

def check_resets(store, current_app_name):
    keys = get_keys()
    changed = False
    
    if store.get("_day") != keys["day"]:
        store["daily"] = {}
        store["_day"] = keys["day"]
        changed = True
        
    if store.get("_week") != keys["week"]:
        store["weekly"] = {}
        store["_week"] = keys["week"]
        changed = True
        
    if store.get("_month") != keys["month"]:
        store["monthly"] = {}
        store["_month"] = keys["month"]
        changed = True
    
    if changed and current_app_name:
        for p in ["daily", "weekly", "monthly"]:
            if current_app_name not in store[p]:
                store[p][current_app_name] = {"time": 0, "opens": 0}
        
    return store, changed

# --- Main ---
sock_path = find_hyprland_socket()
if not sock_path:
    print("Hyprland socket not found", file=sys.stderr)
    sys.exit(1)

store = load_data()
current_app = None
store, _ = check_resets(store, current_app)
save_data(store)

last_time = time.time()
last_save = time.time()

import subprocess

def normalize_name(name):
    if not name: return ""
    
    # Mapeos específicos de clase/nombre a icono
    mapping = {
        "google-chrome": "google-chrome",
        "chrome": "google-chrome",
        "brave-browser": "brave-browser",
        "firefox": "firefox",
        "spotify": "spotify",
        "obsidian": "obsidian",
        "code-oss": "vscodium",
        "vscodium": "vscodium",
        "code": "visual-studio-code",
        "thunar": "thunar",
        "dolphin": "dolphin",
        "kitty": "kitty",
        "foot": "foot",
        "alacritty": "alacritty",
        "discord": "discord",
        "vesktop": "vesktop",
        "steam": "steam",
        "pavucontrol": "multimedia-volume-control",
        "blueman-manager": "blueman",
        "org.freecad.freecad": "freecad",
        "org.openscad.openscad": "openscad",
        "com.reaan.wallpicker": "wallpaper",
        "windsurf": "windsurf",
        "cursor-url-handler": "cursor",
        "sober": "sober",
    }
    
    # 1. Lowercase
    name = name.lower()
    
    # 2. Quitar extensiones comunes
    if name.endswith(".exe"): name = name[:-4]
    
    # 3. Quitar prefijos reverse-dns (org.kde.dolphin -> dolphin)
    prefixes = ["org.kde.", "org.gnome.", "com.", "io.", "net.", "org.freecad.", "org.openscad.", "org.vinegarhq."]
    for pref in prefixes:
        if name.startswith(pref):
            name = name[len(pref):]
            break
            
    # 4. Limpieza de caracteres raros (ej: war thunder (vulkan -> war thunder)
    if "(" in name: name = name.split("(")[0].strip()
    
    # 5. Espacios a guiones (mejor para iconos de sistema)
    name = name.replace(" ", "-")
    
    # 6. Aplicar mapeo
    return mapping.get(name, name)

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
        return apps
    except: return []

def get_package_counts():
    try:
        # Pacman (native)
        pacman_out = subprocess.check_output(["pacman", "-Qn"], stderr=subprocess.DEVNULL).decode("utf-8")
        pacman_count = len(pacman_out.strip().split("\n")) if pacman_out.strip() else 0
        
        # Yay/AUR (foreign)
        yay_out = subprocess.check_output(["pacman", "-Qm"], stderr=subprocess.DEVNULL).decode("utf-8")
        yay_count = len(yay_out.strip().split("\n")) if yay_out.strip() else 0
        
        return pacman_count, yay_count
    except Exception as e:
        print(f"Error getting package counts: {e}", file=sys.stderr)
        return 0, 0

last_pkg_check = 0

def update_time():
    global last_time, current_app, last_pkg_check
    now = time.time()
    delta = now - last_time
    
    if delta > 14400: delta = 0
    
    # Actualizar conteo de paquetes cada 5 minutos
    if now - last_pkg_check > 300:
        p_count, y_count = get_package_counts()
        store["_pacman_count"] = p_count
        store["_yay_count"] = y_count
        last_pkg_check = now
    
    if delta > 0:
        active_apps = set()
        if current_app: 
            norm_app = normalize_name(current_app)
            if norm_app: active_apps.add(norm_app)
        
        audio_apps = get_audio_apps()
        for app in audio_apps: active_apps.add(app)
        
        # Guardar lista de apps activas para la UI
        store["_active"] = list(active_apps)

        for p in ["daily", "weekly", "monthly"]:
            if "_total_" not in store[p]: store[p]["_total_"] = {"time": 0, "opens": 0}
            store[p]["_total_"]["time"] += delta
            
            for app in active_apps:
                if app not in store[p]: store[p][app] = {"time": 0, "opens": 0}
                store[p][app]["time"] += delta
                
    last_time = now

try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(sock_path)
except Exception as e:
    print(f"Failed to connect to socket: {e}", file=sys.stderr)
    sys.exit(1)

print("Connected to Hyprland socket")

while True:
    try:
        raw = s.recv(4096).decode('utf-8', errors='ignore')
        if not raw: break

        for line in raw.strip().split('\n'):
            line = line.strip()
            if not line: continue

            store, changed = check_resets(store, current_app)
            
            if line.startswith('activewindow>>'):
                update_time()
                payload = line.split('>>', 1)[1]
                parts = payload.split(',', 1)
                current_app = parts[0].strip() if parts else ""
                if (time.time() - last_save) >= 2.0 or changed:
                    save_data(store)
                    last_save = time.time()

            elif line.startswith('openwindow>>'):
                payload = line.split('>>', 1)[1]
                parts = payload.split(',')
                if len(parts) >= 3:
                    app_class = parts[2].strip()
                    if app_class:
                        app_name = normalize_name(app_class)
                        for p in ["daily", "weekly", "monthly"]:
                            if app_name not in store[p]: store[p][app_name] = {"time": 0, "opens": 0}
                            store[p][app_name]["opens"] += 1
                save_data(store)
                last_save = time.time()

            elif line.startswith('closewindow>>'):
                update_time()
                if (time.time() - last_save) >= 2.0 or changed:
                    save_data(store)
                    last_save = time.time()

        if time.time() - last_save >= 10.0:
            update_time()
            save_data(store)
            last_save = time.time()

    except Exception as e:
        print(f"Error in loop: {e}", file=sys.stderr)
        break

update_time()
save_data(store)
