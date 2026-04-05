<<<<<<< HEAD
# reaan-dotfiles
DotFiles Para Arch Linux
=======
# 󰖬 Hyprland Dotfiles - Modern Wayland Setup

<div align="center">

![Hyprland](https://img.shields.io/badge/Hyprland-Dynamic-89b4fa?style=for-the-badge&logo=wayland&logoColor=white)
![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)
![Catppuccin](https://img.shields.io/badge/Catppuccin-Mocha-cba6f7?style=for-the-badge)

A complete, modern Hyprland configuration for Arch Linux with beautiful aesthetics and smooth animations.

</div>

## ✨ Features

- **🎨 Catppuccin Mocha Theme** - Beautiful, consistent theming across all applications
- **🚀 Smooth Animations** - Custom bezier curves for premium window transitions
- **📊 Modern Status Bar** - Waybar with glassmorphism design and dynamic modules
- **🔔 Notification Center** - SwayNC with media controls and quick actions
- **🖼️ Dynamic Wallpapers** - Automatic color scheme generation with Matugen
- **⌨️ Optimized Keybindings** - Intuitive shortcuts for maximum productivity
- **🔒 Lock Screen** - Hyprlock with beautiful blur effects
- **💤 Idle Management** - Hypridle for automatic screen dimming and locking
- **📝 Neovim Setup** - Complete IDE configuration with LSP and plugins
- **🐚 Zsh + Powerlevel10k** - Modern shell with autosuggestions and syntax highlighting

## 🖼️ Screenshots

> Add your screenshots here after installation

## 📦 What's Included

### Core Components
- **Hyprland** - Dynamic tiling Wayland compositor
- **Waybar** - Highly customizable status bar
- **Kitty** - GPU-accelerated terminal emulator
- **Rofi** - Application launcher and window switcher
- **Swaync** - Notification daemon and control center
- **Hyprlock** - Screen locker with blur effects
- **Hypridle** - Idle management daemon

### Applications
- **Neovim** - Modern text editor with LSP support
- **Zsh** - Powerful shell with Oh My Zsh
- **Cava** - Audio visualizer
- **Dolphin** - File manager

### Utilities
- Modern CLI tools: `eza`, `bat`, `ripgrep`, `fd`, `btop`, `dust`, `duf`
- Screenshot tools: `grim`, `slurp`, `swappy`
- Clipboard manager: `cliphist`
- Wallpaper daemon: `swww`

## 🚀 Installation

### Prerequisites
- Arch Linux (or Arch-based distribution)
- Internet connection
- Git installed

### Quick Install

```bash
# Clone the repository
git clone https://github.com/yourusername/reaan-dotfiles.git
cd reaan-dotfiles

# Run the installation script
chmod +x scripts/install-arch.sh
./scripts/install-arch.sh
```

The installer will:
1. ✅ Install all required packages (including AUR packages via yay)
2. ✅ Deploy all configuration files
3. ✅ Set up Zsh with Oh My Zsh and Powerlevel10k
4. ✅ Configure system services
5. ✅ Validate the installation

### Manual Installation

If you prefer manual installation:

```bash
# Install yay (AUR helper)
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay.git
cd yay && makepkg -si

# Install core packages
yay -S hyprland hyprlock hypridle waybar kitty rofi-wayland swaync \
       swww grim slurp swappy brightnessctl pavucontrol playerctl \
       ttf-jetbrains-mono-nerd zsh neovim

# Deploy dotfiles
cp -r dot_config/* ~/.config/
cp dot_zshrc ~/.zshrc

# Install Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Change default shell
chsh -s $(which zsh)
```

## ⌨️ Keybindings

### General
| Keybind | Action |
|---------|--------|
| `SUPER + Q` | Close active window |
| `SUPER + Return` | Open terminal (Kitty) |
| `SUPER + D` | Application launcher (Rofi) |
| `SUPER + E` | File manager (Dolphin) |
| `SUPER + L` | Lock screen |
| `SUPER + M` | Exit Hyprland |

### Window Management
| Keybind | Action |
|---------|--------|
| `SUPER + Arrow Keys` | Move focus |
| `SUPER + Shift + Arrow Keys` | Move window |
| `SUPER + F` | Toggle fullscreen |
| `SUPER + V` | Toggle floating |
| `SUPER + P` | Toggle pseudo-tiling |

### Workspaces
| Keybind | Action |
|---------|--------|
| `SUPER + 1-9` | Switch to workspace 1-9 |
| `SUPER + Shift + 1-9` | Move window to workspace 1-9 |
| `SUPER + Mouse Scroll` | Cycle workspaces |

### Screenshots
| Keybind | Action |
|---------|--------|
| `SUPER + Shift + S` | Screenshot area (with editor) |
| `Print` | Screenshot full screen |

### Media
| Keybind | Action |
|---------|--------|
| `XF86AudioPlay` | Play/Pause |
| `XF86AudioNext` | Next track |
| `XF86AudioPrev` | Previous track |
| `XF86AudioRaiseVolume` | Volume up |
| `XF86AudioLowerVolume` | Volume down |

## 🎨 Customization

### Changing Wallpaper

```bash
# Set a specific wallpaper
~/.config/hypr/scripts/wallpaper.sh /path/to/wallpaper.jpg

# Set random wallpaper from ~/wallps
~/.config/hypr/scripts/wallpaper.sh
```

### Monitor Configuration

Edit `~/.config/hypr/monitors.conf`:

```conf
# Example for single 1080p monitor
monitor=,1920x1080@60,0x0,1

# Example for dual monitors
monitor=DP-1,1920x1080@144,0x0,1
monitor=HDMI-A-1,1920x1080@60,1920x0,1
```

### Theme Colors

The configuration uses Catppuccin Mocha palette. To customize colors, edit:
- Waybar: `~/.config/waybar/style.css`
- Kitty: `~/.config/kitty/kitty.conf`
- Rofi: `~/.config/rofi/theme.rasi`
- Hyprland: `~/.config/hypr/hyprland.conf`

## 📁 File Structure

```
reaan-dotfiles/
├── dot_config/
│   ├── hypr/              # Hyprland configuration
│   │   ├── hyprland.conf  # Main config
│   │   ├── hyprlock.conf  # Lock screen
│   │   ├── hypridle.conf  # Idle management
│   │   ├── keybinds.conf  # Keybindings
│   │   ├── monitors.conf  # Monitor setup
│   │   ├── windowrules.conf # Window rules
│   │   └── scripts/       # Utility scripts
│   ├── waybar/            # Status bar
│   ├── kitty/             # Terminal
│   ├── rofi/              # Launcher
│   ├── swaync/            # Notifications
│   ├── nvim/              # Neovim
│   └── cava/              # Audio visualizer
├── scripts/
│   └── install-arch.sh    # Installation script
├── wallps/                # Wallpapers
└── README.md
```

## 🔧 Troubleshooting

### Waybar not showing
```bash
killall waybar && waybar &
```

### Screen tearing
Add to `~/.config/hypr/hyprland.conf`:
```conf
env = WLR_DRM_NO_ATOMIC,1
```

### NVIDIA GPU issues
```conf
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = WLR_NO_HARDWARE_CURSORS,1
```

## 🤝 Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest new features
- Submit pull requests
- Share your screenshots

## 📝 Credits

### Inspiration
- **ilyamiro.dev** - Design inspiration and aesthetic reference

### Projects Used
- [Hyprland](https://hyprland.org/) - Dynamic tiling Wayland compositor
- [Catppuccin](https://github.com/catppuccin/catppuccin) - Soothing pastel theme
- [Waybar](https://github.com/Alexays/Waybar) - Highly customizable status bar
- [SwayNC](https://github.com/ErikReider/SwayNotificationCenter) - Notification daemon

## 📄 License

MIT License - Feel free to use and modify!

---

<div align="center">

**Made with ❤️ for the Hyprland community**

⭐ Star this repo if you find it useful!

</div>

## 1. Stack Tecnológico Recomendado
- **Frontend**: **Hyprland** (Compositor de Wayland) - Ofrece una experiencia de usuario moderna, fluida y altamente personalizable mediante scripts.
- **Notificaciones**: **SwayNC** (Sway Notification Center) - Centro de notificaciones moderno con soporte para widgets y control de medios.
- **Lanzador**: **Rofi (Wayland fork)** o **Wofi** - Para un menú de aplicaciones estilizado y búsqueda rápida.
- **Dynamic Theming**: **Matugen** o **Pywal** - Genera paletas de colores dinámicas a partir del wallpaper para todos los componentes (Kitty, Waybar, etc.).
- **Gestión de Configuración**: **Chezmoi** - Herramienta robusta para gestionar dotfiles de forma segura y portable.
- **Base de Datos/Estado**: **Git** - Control de versiones para sincronización y reversión de cambios.
- **Infraestructura**: **Arch Linux** - Distribución base para asegurar las últimas versiones de los paquetes de Wayland.

## 2. Estructura de Carpetas del Proyecto
```text
/home/reaan/reaan-dotfiles/
├── .chezmoi.toml           # Configuración del gestor de dotfiles
├── dot_config/             # Archivos que irán a ~/.config/
│   ├── hypr/
│   │   ├── hyprland.conf   # Configuración principal y animaciones
│   │   ├── keybinds.conf   # Atajos de teclado
│   │   └── monitors.conf   # Configuración de pantallas
│   ├── waybar/
│   │   ├── config          # Estructura modular de la barra
│   │   └── style.css       # Estilos (CSS) con variables de Matugen
│   ├── swaync/             # Centro de notificaciones
│   │   └── config.json
│   ├── kitty/              # Terminal
│   │   └── kitty.conf
│   └── rofi/               # Lanzador de apps
│       └── theme.rasi
├── scripts/                # Lógica de automatización
│   ├── install.sh          # Script de instalación "one-click"
│   ├── set-wallpaper.sh    # Cambia wallpaper y regenera colores
│   └── themes/             # Generadores de temas (Matugen)
├── wallps/                 # Galería de fondos de pantalla curada
└── README.md               # Documentación y guía de uso
```

## 3. Modelo de Datos
- **Entidad: `Configuración` (File-based)**
    - `nombre`: Nombre del archivo (ej. `hyprland.conf`).
    - `ruta_destino`: Ubicación en el sistema de archivos (ej. `~/.config/hypr/`).
    - `contenido`: Directivas de configuración específicas del componente.
    - `estado`: `Vinculado` | `Modificado` | `Pendiente`.
- **Entidad: `Dependencia` (Package-based)**
    - `paquete`: Nombre del paquete en el gestor (ej. `hyprland-git`).
    - `tipo`: `Core` | `Estético` | `Utilidad`.
    - `estado_instalacion`: `Instalado` | `No Instalado`.
- **Relaciones**: Cada `Configuración` tiene una relación de dependencia con uno o más `Paquetes` del sistema.

## Guía de Atajos de Teclado (Keybinds)

### **Obligatorios (Preinstalados)**
- `Super + Return`: Abrir Terminal **Kitty**.
- `Super + D`: Abrir **Discord**.
- `Super + S`: Abrir **Spotify**.

### **Opcionales (Configurables en Instalación)**
- `Super + B`: Abrir **Navegador Web** (seleccionado).
- `Super + I`: Abrir **Editor de Código** (seleccionado).
- `Super + G`: Abrir **Docker Desktop**.
- `Super + J`: Abrir **Steam**.

### **Funcionalidades Especiales**
- `Super` (sola): Abrir el **Launcher** de aplicaciones (Rofi).
- `Super + W`: Abrir el **Selector de Wallpapers** personalizado.
- `Super + N`: Mostrar el **Centro de Notificaciones** (SwayNC).
- `PrintScreen`: Realizar captura de pantalla interactiva.

### **Navegación de Escritorios**
- `Super + Flechas`: Navegar entre escritorios virtuales.
- `Super + Shift + Flechas`: Mover ventana al escritorio siguiente/anterior.
- `Control + Flechas`: Mover ventana a un escritorio específico.

## Instalación Interactiva
El script `scripts/install.sh` permite:
1. Realizar un backup automático de tu configuración actual.
2. Elegir tu Navegador y Editor preferido.
3. Instalar dependencias opcionales (Docker, Steam).
4. Validar que todas las aplicaciones se instalen correctamente.
5. Configurar automáticamente los atajos de teclado basados en tus elecciones.

## 5. Decisiones de Diseño
- **Experiencia de Usuario (UX) Primero**: Priorizar animaciones y transiciones suaves (estilo ilyamiro) para reducir la carga cognitiva y mejorar la estética del entorno.
- **Abstracción de Colores**: Uso de variables de entorno y archivos CSS generados dinámicamente para asegurar que todo el sistema cambie de color coherentemente con el wallpaper.
- **Modularidad de Configuración**: Dividir la configuración de Hyprland en archivos específicos (monitores, animaciones, atajos) para facilitar la personalización sin romper el sistema.
- **Gestión Declarativa de Paquetes**: Mantener una lista explícita de dependencias para asegurar la reproducibilidad total en nuevas instalaciones.

## 6. Riesgos Técnicos y Mitigación
- **Riesgo 1: Incompatibilidad de Hardware (GPU/Monitores)**
    - *Mitigación*: Implementar detección automática en los scripts de inicio para asignar configuraciones específicas según el vendor de la GPU (Nvidia vs AMD).
- **Riesgo 2: Ruptura por actualizaciones (Rolling Release)**
    - *Mitigación*: Uso de subgrupos de configuración "estables" y scripts de respaldo automáticos antes de aplicar actualizaciones críticas del sistema.
>>>>>>> 0785b1f (Se agrega el proyecto)
