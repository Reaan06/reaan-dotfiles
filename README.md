# 󰖬 Dotfiles de Rean - Modern Wayland Setup

<div align="center">

![Hyprland](https://img.shields.io/badge/Hyprland-Dynamic-89b4fa?style=for-the-badge&logo=wayland&logoColor=white)
![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)
![Catppuccin](https://img.shields.io/badge/Catppuccin-Mocha-cba6f7?style=for-the-badge)

Una configuración completa, moderna y orientada a resultados para Arch Linux + Hyprland. Estética limpia, transiciones fluidas y lista para programar.

</div>

## ✨ Características Principales

- **🎨 Tema Catppuccin Mocha:** Paleta de colores consistente en todas las aplicaciones.
- **🚀 Animaciones Fluidas:** Curvas bezier personalizadas para transiciones premium.
- **📊 Barra de Estado Moderna:** Waybar con diseño *glassmorphism* y módulos dinámicos.
- **🔔 Centro de Notificaciones:** SwayNC con controles multimedia y acciones rápidas.
- **🖼️ Wallpapers Dinámicos:** Generación automática de colores basada en el fondo (Matugen/Pywal).
- **📝 Entorno de Desarrollo:** Atajos preconfigurados para iniciar tu entorno (Trae, Docker, Terminal) al instante.

## 🖼️ Capturas de Pantalla

> [!NOTE]  
> *Añade tus capturas de pantalla aquí después de la instalación.*

## 📦 Stack Tecnológico

| Componente | Herramienta | Descripción |
| :--- | :--- | :--- |
| **Window Manager** | Hyprland | Compositor Wayland dinámico |
| **Terminal** | Kitty | Emulador acelerado por GPU |
| **Lanzador** | Rofi (Wayland) | Menú de aplicaciones estilizado |
| **Notificaciones** | SwayNC | Centro de notificaciones y widgets |
| **Barra de Estado** | Waybar | Panel superior altamente personalizable |
| **Gestión de Sesión** | Hyprlock / Hypridle | Bloqueo de pantalla y gestión de energía |
| **Dotfiles Manager** | Chezmoi | (Opcional) Gestión robusta de configuraciones |

## 🚀 Instalación

### Requisitos Previos
- Arch Linux o EndeavourOS recién instalado.
- Conexión a internet.
- Git instalado (`sudo pacman -S git`).

### Instalación Rápida (Recomendada)

El script interactivo hará un backup de tu configuración actual, instalará paquetes AUR y aplicará los dotfiles.

```bash
# 1. Clonar el repositorio
git clone [https://github.com/tu-usuario/reaan-dotfiles.git](https://github.com/tu-usuario/reaan-dotfiles.git)
cd reaan-dotfiles

# 2. Dar permisos y ejecutar
chmod +x scripts/install.sh
./scripts/install.sh
