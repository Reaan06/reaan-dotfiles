import os
import json
import glob

"""
app_launcher_data.py — Genera lista de apps instaladas para el lanzador Aura.
"""

SOBER_ICON = "/var/lib/flatpak/appstream/flathub/x86_64/fe3c325c6b3b62554b14d1bc4e86ed91546c79a3795939ba8267336264a50a3a/icons/128x128/org.vinegarhq.Sober.png"

# Mapeos: WMClass -> nombre_icono_correcto
ICON_OVERRIDES = {
    "brave-browser": "brave",
    "google-chrome": "google-chrome",
    "Spotify": "spotify",
    "spotify": "spotify",
    "discord": "discord",
    "Code": "vscode",
    "code-oss": "vscode",
    "sober": SOBER_ICON,
    "Sober": SOBER_ICON,
    "org.vinegarhq.Sober": SOBER_ICON,
    "org.vinegarhq.sober": SOBER_ICON,
    "Roblox": SOBER_ICON,
    "llauncher": "legacy-launcher",
}

# Apps extra que no tienen .desktop pero queremos incluir
EXTRA_APPS = [
    {
        "name": "Sober",
        "exec": "flatpak run org.vinegarhq.Sober",
        "icon": SOBER_ICON,
        "class": "sober"
    }
]

def strip(value):
    return value.strip() if value else ""

def get_apps():
    apps = []
    paths = [
        "/usr/share/applications/*.desktop",
        "/usr/local/share/applications/*.desktop",
        "/var/lib/flatpak/exports/share/applications/*.desktop",
        "/var/lib/flatpak/app/*/*/export/share/applications/*.desktop",
        os.path.expanduser("~/.local/share/applications/*.desktop"),
        os.path.expanduser("~/.local/share/flatpak/exports/share/applications/*.desktop")
    ]

    seen_names = set()

    for path_glob in paths:
        for path in glob.glob(path_glob):
            try:
                with open(path, 'r', errors='ignore') as f:
                    content = f.read()

                entry = {}
                in_desktop_entry = False
                for line in content.split('\n'):
                    line = line.strip()
                    if line == '[Desktop Entry]':
                        in_desktop_entry = True
                        continue
                    if line.startswith('[') and line != '[Desktop Entry]':
                        in_desktop_entry = False
                    if not in_desktop_entry:
                        continue
                    if line.startswith('Name=') and 'name' not in entry:
                        entry['name'] = strip(line[5:])
                    elif line.startswith('Icon='):
                        entry['icon'] = strip(line[5:])
                    elif line.startswith('Exec=') and 'exec' not in entry:
                        # Limpiar exec: quitar flags de %u, %f, etc y comillas
                        raw = strip(line[5:])
                        for flag in ['%u','%U','%f','%F','%i','%c','%k']:
                            raw = raw.replace(flag, '')
                        entry['exec'] = raw.strip().strip('"')
                    elif line.startswith('StartupWMClass='):
                        entry['class'] = strip(line[15:])
                    elif line.startswith('NoDisplay=') and line[10:].strip().lower() == 'true':
                        entry['nodisplay'] = True
                    elif line.startswith('Type=') and strip(line[5:]) != 'Application':
                        entry['not_app'] = True

                # Filtrar entradas inválidas
                if entry.get('not_app'):
                    continue
                if 'name' not in entry or 'exec' not in entry:
                    continue
                if entry['name'] in seen_names:
                    continue

                # Asignar clase si no hay
                if 'class' not in entry:
                    entry['class'] = entry['name']

                # Aplicar override de icono
                icon_override = ICON_OVERRIDES.get(entry.get('icon','')) or ICON_OVERRIDES.get(entry.get('class',''))
                if icon_override:
                    entry['icon'] = icon_override

                seen_names.add(entry['name'])
                apps.append(entry)

            except Exception:
                continue

    # Agregar apps extra (como Sober si no se encontró su .desktop)
    for extra in EXTRA_APPS:
        if extra['name'] not in seen_names:
            apps.append(extra)
            seen_names.add(extra['name'])

    return sorted(apps, key=lambda x: x['name'].lower())

if __name__ == "__main__":
    print(json.dumps(get_apps()))
