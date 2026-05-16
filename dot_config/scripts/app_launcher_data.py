import os
import json
import glob

"""
app_launcher_data.py — Genera lista de apps instaladas para el lanzador Aura.
"""

def get_apps():
    apps = []
    paths = [
        "/usr/share/applications/*.desktop",
        os.path.expanduser("~/.local/share/applications/*.desktop")
    ]
    
    seen_execs = set()
    
    for path_glob in paths:
        for path in glob.glob(path_glob):
            try:
                with open(path, 'r', errors='ignore') as f:
                    content = f.read()
                    
                entry = {}
                for line in content.split('\n'):
                    if line.startswith('Name='): entry['name'] = line.split('=')[1]
                    if line.startswith('Icon='): entry['icon'] = line.split('=')[1]
                    if line.startswith('Exec='): entry['exec'] = line.split('=')[1].split(' %')[0]
                    if line.startswith('Class='): entry['class'] = line.split('=')[1]
                    if line.startswith('StartupWMClass='): entry['class'] = line.split('=')[1]
                
                if 'name' in entry and 'exec' in entry:
                    # Evitar duplicados por ejecutable
                    if entry['exec'] not in seen_execs:
                        apps.append(entry)
                        seen_execs.add(entry['exec'])
            except: continue
            
    return sorted(apps, key=lambda x: x['name'].lower())

if __name__ == "__main__":
    print(json.dumps(get_apps()))
