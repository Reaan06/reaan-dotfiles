import os
import json
import socket
import threading
import sys
import subprocess
import glob

"""
dock_bridge.py — Puente de datos para el Dock Antigravity.
Rastrea ventanas abiertas y gestiona apps fijadas.
"""

PINNED_FILE = os.path.expanduser('~/.config/quickshell/pinned_apps.json')
USAGE_FILE = os.path.expanduser('~/.cache/app_usage.json')
STATE_FILE = os.path.expanduser('/tmp/qs-dock-state.json')

def load_pinned():
    if os.path.exists(PINNED_FILE):
        try:
            with open(PINNED_FILE, 'r') as f: return json.load(f)
        except: return []
    return []

def get_top_apps(limit=7):
    if not os.path.exists(USAGE_FILE): return []
    try:
        with open(USAGE_FILE, 'r') as f:
            data = json.load(f)
            daily = data.get("daily", {})
            
            # Filtros para evitar aplicaciones del sistema o basura
            blacklist = ["_total_", "gcr-prompter", "swappy", "polkit", "xdg", "antigravity", "quickshell"]
            
            apps = []
            for k, v in daily.items():
                if k.startswith("_"): continue
                if any(b in k.lower() for b in blacklist): continue
                if len(k) < 3: continue # Evitar nombres demasiado cortos
                apps.append((k, v.get("time", 0)))
                
            sorted_apps = sorted(apps, key=lambda x: x[1], reverse=True)
            return [app[0] for app in sorted_apps[:limit]]
    except Exception as e:
        print(f"Error getting top apps: {e}", file=sys.stderr)
        return []

def save_pinned(apps):
    with open(PINNED_FILE, 'w') as f: json.dump(apps, f)

def find_hyprland_socket():
    sig = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE')
    xdg = os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')
    if sig:
        path = f"{xdg}/hypr/{sig}/.socket2.sock"
        if os.path.exists(path): return path
    return None

def get_clients():
    try:
        out = subprocess.check_output(["hyprctl", "clients", "-j"]).decode('utf-8')
        clients = json.loads(out)
        active_classes = {}
        for c in clients:
            cls = c.get("class", "")
            if cls:
                active_classes[cls] = active_classes.get(cls, 0) + 1
        return active_classes
    except: return {}

class DockBridge:
    def __init__(self):
        self.pinned = load_pinned()
        self.top_apps = get_top_apps()
        self.active_windows = get_clients()
        self.lock = threading.Lock()
        self.running = True
        self.last_pinned_mtime = self.get_mtime(PINNED_FILE)

    def get_mtime(self, path):
        try: return os.path.getmtime(path)
        except: return 0

    def check_pinned_change(self):
        mtime = self.get_mtime(PINNED_FILE)
        if mtime != self.last_pinned_mtime:
            self.last_pinned_mtime = mtime
            self.pinned = load_pinned()
            self.update_state()
            return True
        return False

    def update_state(self):
        with self.lock:
            state = {
                "pinned": self.pinned,
                "top": self.top_apps,
                "active": self.active_windows
            }
            with open(STATE_FILE, 'w') as f:
                json.dump(state, f)
            print(json.dumps(state))
            sys.stdout.flush()

    def handle_event(self, line):
        # Eventos que cambian el estado de las ventanas
        events = ['openwindow>>', 'closewindow>>', 'activewindow>>']
        if any(line.startswith(e) for e in events):
            self.active_windows = get_clients()
            self.top_apps = get_top_apps()
            self.check_pinned_change()
            self.update_state()

def main():
    bridge = DockBridge()
    bridge.update_state()
    
    sock_path = find_hyprland_socket()
    if not sock_path:
        # Fallback si no hay socket: solo actualizar estado periódicamente
        while True:
            bridge.active_windows = get_clients()
            bridge.check_pinned_change()
            bridge.update_state()
            import time
            time.sleep(2)

    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(sock_path)
        while True:
            # Check for pinned file changes periodically even when waiting for events
            bridge.check_pinned_change()
            
            # Non-blocking check for socket data would be better, but for now 
            # we just depend on events or the fallback loop below
            s.settimeout(2.0)
            try:
                raw = s.recv(4096).decode('utf-8', errors='ignore')
                if not raw: break
                for line in raw.strip().split('\n'):
                    bridge.handle_event(line.strip())
            except socket.timeout:
                continue
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)

if __name__ == "__main__":
    main()
