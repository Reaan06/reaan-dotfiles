import sys
import os
import json

HIDE_FILE = os.path.expanduser("~/.config/scripts/hidden_apps.json")

def main():
    if len(sys.argv) < 2:
        return

    app_class = sys.argv[1]
    hidden = []
    
    if os.path.exists(HIDE_FILE):
        try:
            with open(HIDE_FILE, 'r') as f:
                hidden = json.load(f)
        except:
            hidden = []

    if app_class in hidden:
        hidden.remove(app_class)
    else:
        hidden.append(app_class)

    with open(HIDE_FILE, 'w') as f:
        json.dump(hidden, f)

if __name__ == "__main__":
    main()
