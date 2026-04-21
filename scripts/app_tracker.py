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

def current_month_key():
    return datetime.now().strftime("%Y-%m")

def find_hyprland_socket():
    """Encuentra el socket IPC de Hyprland automáticamente."""
    sig = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE')
    xdg = os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')
    if sig:
        path = f"{xdg}/hypr/{sig}/.socket2.sock"
        if os.path.exists(path):
            return path
    # Fallback: buscar cualquier socket activo
    pattern = f"{xdg}/hypr/*/.socket2.sock"
    sockets = glob.glob(pattern)
    if sockets:
        return sockets[0]
    return None

def load_data():
    if not os.path.exists(CACHE_FILE):
        return {}
    try:
        with open(CACHE_FILE, 'r') as f:
            return json.load(f)
    except:
        return {}

def save_data(data):
    try:
        os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
        with open(CACHE_FILE, 'w') as f:
            json.dump(data, f)
    except Exception as e:
        print(f"[tracker] Error guardando: {e}")

def check_and_reset(store):
    month = current_month_key()
    if store.get("_month") != month:
        print(f"[tracker] Nuevo mes detectado ({month}), reiniciando datos.")
        store.clear()
        store["_month"] = month
    return store

# ─── Main ───────────────────────────────────────────────────────────────────

sock_path = find_hyprland_socket()
if not sock_path:
    print("[tracker] ERROR: No se encontró el socket de Hyprland. ¿Está corriendo Hyprland?")
    exit(1)

print(f"[tracker] Conectando a: {sock_path}")

store = load_data()
store = check_and_reset(store)
save_data(store)

current_app = None
last_time = time.time()
last_save = time.time()

def update_time():
    global last_time
    now = time.time()
    if current_app and current_app != "":
        if current_app not in store:
            store[current_app] = {"time": 0, "opens": 0}
        store[current_app]["time"] += (now - last_time)
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

            store = check_and_reset(store)

            if line.startswith('activewindow>>'):
                update_time()
                payload = line.split('>>', 1)[1]
                parts = payload.split(',', 1)
                current_app = parts[0].strip() if parts else ""
                if current_app:
                    print(f"[tracker] Foco: {current_app}")

            elif line.startswith('openwindow>>'):
                payload = line.split('>>', 1)[1]
                parts = payload.split(',')
                if len(parts) >= 3:
                    app_class = parts[2].strip()
                    if app_class and app_class != "":
                        if app_class not in store:
                            store[app_class] = {"time": 0, "opens": 0}
                        store[app_class]["opens"] += 1
                        print(f"[tracker] Apertura: {app_class} ({store[app_class]['opens']}x)")

            elif line.startswith('closewindow>>'):
                update_time()

        # Guardar cada 5 segundos
        now = time.time()
        if now - last_save >= 5:
            save_data(store)
            last_save = now

    except KeyboardInterrupt:
        print("[tracker] Detenido por el usuario.")
        break
    except Exception as e:
        print(f"[tracker] Error: {e}")
        break

update_time()
save_data(store)
print("[tracker] Guardado final. Saliendo.")
