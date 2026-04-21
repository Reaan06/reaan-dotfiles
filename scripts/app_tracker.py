#!/usr/bin/env python3
"""
app_tracker.py — Rastreador mensual de uso de aplicaciones via Hyprland IPC.
Ejecutar como: python ~/.config/scripts/app_tracker.py
"""
import os
import json
import socket
import time
import glob
from datetime import datetime

CACHE_FILE = os.path.expanduser('~/.cache/app_usage.json')

def current_day_key(): return datetime.now().strftime("%Y-%m-%d")
def current_week_key(): return datetime.now().strftime("%Y-%W")
def current_month_key(): return datetime.now().strftime("%Y-%m")

def load_data():
    if not os.path.exists(CACHE_FILE):
        return {"daily": {}, "weekly": {}, "monthly": {}}
    try:
        with open(CACHE_FILE, 'r') as f:
            data = json.load(f)
            # Migrar formato antiguo a nuevo si es necesario
            if "daily" not in data:
                old_apps = {k: v for k, v in data.items() if not k.startswith("_")}
                return {
                    "_day": current_day_key(), "_week": current_week_key(), "_month": current_month_key(),
                    "daily": {}, "weekly": {}, "monthly": old_apps
                }
            return data
    except:
        return {"daily": {}, "weekly": {}, "monthly": {}}

def save_data(data):
    try:
        os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
        with open(CACHE_FILE, 'w') as f:
            json.dump(data, f)
    except Exception as e:
        print(f"[tracker] Error guardando: {e}")

def check_and_reset(store):
    day = current_day_key()
    week = current_week_key()
    month = current_month_key()
    
    changed = False
    if store.get("_day") != day:
        store["daily"] = {}
        store["_day"] = day
        changed = True
    if store.get("_week") != week:
        store["weekly"] = {}
        store["_week"] = week
        changed = True
    if store.get("_month") != month:
        store["monthly"] = {}
        store["_month"] = month
        changed = True
        
    return store, changed

# ─── Main ───────────────────────────────────────────────────────────────────

sock_path = find_hyprland_socket()
if not sock_path:
    print("[tracker] ERROR: No se encontró el socket de Hyprland. ¿Está corriendo Hyprland?")
    exit(1)

print(f"[tracker] Conectando a: {sock_path}")

store = load_data()
store, _ = check_and_reset(store)
save_data(store)

current_app = None
last_time = time.time()
last_save = time.time()

def update_time():
    global last_time
    now = time.time()
    delta = now - last_time
    
    # Prevenir saltos gigantes (ej. suspensión del PC > 4 horas)
    if delta > 14400:
        delta = 0

    for period in ["daily", "weekly", "monthly"]:
        if "_total_" not in store[period]:
            store[period]["_total_"] = {"time": 0, "opens": 0}
        store[period]["_total_"]["time"] += delta

    if current_app and current_app != "":
        for period in ["daily", "weekly", "monthly"]:
            if current_app not in store[period]:
                store[period][current_app] = {"time": 0, "opens": 0}
            store[period][current_app]["time"] += delta
    last_time = now

try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(sock_path)
    print("[tracker] Conectado. Escuchando eventos...")
except Exception as e:
    print(f"[tracker] ERROR conectando al socket: {e}")
    exit(1)

while True:
    try:
        raw = s.recv(4096).decode('utf-8', errors='ignore')
        if not raw:
            break

        for line in raw.strip().split('\n'):
            line = line.strip()
            if not line:
                continue

            store, changed = check_and_reset(store)
            now = time.time()

            if line.startswith('activewindow>>'):
                update_time()
                payload = line.split('>>', 1)[1]
                parts = payload.split(',', 1)
                current_app = parts[0].strip() if parts else ""
                if current_app:
                    print(f"[tracker] Foco: {current_app}")
                if now - last_save >= 1.0 or changed:
                    save_data(store)
                    last_save = now

            elif line.startswith('openwindow>>'):
                payload = line.split('>>', 1)[1]
                parts = payload.split(',')
                if len(parts) >= 3:
                    app_class = parts[2].strip()
                    if app_class and app_class != "":
                        for period in ["daily", "weekly", "monthly"]:
                            if app_class not in store[period]:
                                store[period][app_class] = {"time": 0, "opens": 0}
                            store[period][app_class]["opens"] += 1
                        print(f"[tracker] Apertura: {app_class}")
                save_data(store)
                last_save = now

            elif line.startswith('closewindow>>'):
                update_time()
                if now - last_save >= 1.0 or changed:
                    save_data(store)
                    last_save = now

        if time.time() - last_save >= 3.0:
            save_data(store)
            last_save = time.time()

    except KeyboardInterrupt:
        print("[tracker] Detenido por el usuario.")
        break
    except Exception as e:
        print(f"[tracker] Error: {e}")
        break

update_time()
save_data(store)
print("[tracker] Guardado final. Saliendo.")
