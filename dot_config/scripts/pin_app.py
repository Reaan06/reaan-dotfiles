import sys
import json
import os

PINNED_FILE = os.path.expanduser('~/.config/scripts/pinned_apps.json')

def toggle_pin(app_class):
    if not os.path.exists(PINNED_FILE):
        pinned = []
    else:
        try:
            with open(PINNED_FILE, 'r') as f:
                pinned = json.load(f)
        except:
            pinned = []
            
    if app_class in pinned:
        pinned.remove(app_class)
        action = "unpinned"
    else:
        pinned.append(app_class)
        action = "pinned"
        
    os.makedirs(os.path.dirname(PINNED_FILE), exist_ok=True)
    with open(PINNED_FILE, 'w') as f:
        json.dump(pinned, f)
        
    print(f"App {app_class} {action}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        toggle_pin(sys.argv[1])
    else:
        print("Usage: python3 pin_app.py <AppClass>")
