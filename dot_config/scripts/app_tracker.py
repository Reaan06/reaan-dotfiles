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
            return data
    except:
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

def get_audio_apps():
    # Mapeo de nombres de reproductores a clases de ventana conocidas
    mapping = {
        "chromium": "google-chrome",
        "brave": "brave-browser",
        "firefox": "firefox",
        "spotify": "spotify",
    }
    try:
        output = subprocess.check_output(
            ["playerctl", "metadata", "--format", "{{playerName}}:{{status}}", "-a"],
            stderr=subprocess.DEVNULL
        ).decode('utf-8')
        apps = []
        for line in output.strip().split('\n'):
            if ":Playing" in line:
                raw_name = line.split(':')[0].lower().split('.')[0]
                # Usar mapeo o el nombre raw
                name = mapping.get(raw_name, raw_name)
                if name: apps.append(name)
        return apps
    except: return []

def update_time():
    global last_time, current_app
    now = time.time()
    delta = now - last_time
    
    if delta > 14400: delta = 0
    
    if delta > 0:
        active_apps = set()
        # Normalizar a minúsculas para evitar duplicados (Spotify vs spotify)
        if current_app: active_apps.add(current_app.lower())
        
        audio_apps = get_audio_apps()
        for app in audio_apps: active_apps.add(app.lower())

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
                        for p in ["daily", "weekly", "monthly"]:
                            if app_class not in store[p]: store[p][app_class] = {"time": 0, "opens": 0}
                            store[p][app_class]["opens"] += 1
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
