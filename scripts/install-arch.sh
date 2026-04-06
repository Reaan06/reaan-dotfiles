#!/bin/bash

# ═══════════════════════════════════════════════════════════════
#  Hyprland + Quickshell — Dotfiles Installer (Arch Linux)
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

# ── Colores ──
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Rutas ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

# ── Helpers ──
header()  { echo -e "\n${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n  ${CYAN}$1${NC}\n${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }
ok()      { echo -e "  ${GREEN}✓${NC} $1"; }
info()    { echo -e "  ${BLUE}ℹ${NC} $1"; }
warn()    { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail()    { echo -e "  ${RED}✗${NC} $1"; }
die()     { fail "$1"; exit 1; }

# ═══════════════════════════════════════════════════════════════
#  Validaciones
# ═══════════════════════════════════════════════════════════════

[ -f /etc/arch-release ] || die "Este script es exclusivo para Arch Linux."

if ! command -v yay &>/dev/null; then
    warn "yay no encontrado. Instalando..."
    sudo pacman -S --needed --noconfirm git base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay-install
    (cd /tmp/yay-install && makepkg -si --noconfirm)
    rm -rf /tmp/yay-install
    ok "yay instalado"
fi

# ═══════════════════════════════════════════════════════════════
#  Selección interactiva de software opcional
# ═══════════════════════════════════════════════════════════════

clear
header "Hyprland + Quickshell — Instalador de Dotfiles"
header "Software Opcional"

echo -e "${CYAN}Navegador:${NC}"
echo "  1) Firefox   2) Brave   3) Chrome   4) Ninguno"
read -rp "  Opción (1-4): " _b
case $_b in
    1) BROWSER="firefox" ;;
    2) BROWSER="brave-bin" ;;
    3) BROWSER="google-chrome" ;;
    *) BROWSER="" ;;
esac

echo -e "\n${CYAN}Editor de código:${NC}"
echo "  1) VSCode   2) Neovim   3) VSCodium   4) Ninguno"
read -rp "  Opción (1-4): " _e
case $_e in
    1) EDITOR_PKG="visual-studio-code-bin" ;;
    2) EDITOR_PKG="neovim" ;;
    3) EDITOR_PKG="vscodium-bin" ;;
    *) EDITOR_PKG="" ;;
esac

echo ""
read -rp "  ¿Instalar Docker? (s/n): " _docker
read -rp "  ¿Instalar Steam?  (s/n): " _steam

# ═══════════════════════════════════════════════════════════════
#  Paquetes
# ═══════════════════════════════════════════════════════════════

header "Instalando Paquetes"

CORE=(
    # Hyprland
    hyprland hyprlock hypridle hyprpaper
    xdg-desktop-portal-hyprland

    # Shell (Quickshell reemplaza Waybar)
    quickshell-git

    # Notificaciones
    swaync

    # Terminal + Zsh
    kitty zsh zsh-autosuggestions zsh-syntax-highlighting

    # Launcher
    rofi-wayland

    # Wallpaper + Screenshots
    swaybg grim slurp swappy

    # Audio / Brillo
    pavucontrol playerctl brightnessctl pamixer light

    # Gestor de pantallas + Imagemagick (colores dinámicos)
    nwg-displays imagemagick jq

    # Wallpaper picker GUI (GTK4 + Libadwaita)
    python-gobject gtk4 libadwaita

    # Bluetooth
    bluez bluez-utils blueman

    # Red
    network-manager-applet

    # Clipboard
    wl-clipboard cliphist

    # Fuentes
    ttf-jetbrains-mono-nerd ttf-font-awesome
    noto-fonts noto-fonts-emoji

    # Theming
    qt5ct qt6ct kvantum papirus-icon-theme

    # Sistema
    polkit-kde-agent

    # Archivos
    dolphin file-roller unzip unrar p7zip
)

CLI_TOOLS=(
    eza bat ripgrep fd dust duf btop procs fzf
)

info "Paquetes core + Quickshell..."
yay -S --needed --noconfirm "${CORE[@]}"

info "Herramientas CLI modernas..."
yay -S --needed --noconfirm "${CLI_TOOLS[@]}"

[[ -n "$BROWSER" ]]    && { info "Instalando $BROWSER...";    yay -S --needed --noconfirm "$BROWSER"; }
[[ -n "$EDITOR_PKG" ]] && { info "Instalando $EDITOR_PKG..."; yay -S --needed --noconfirm "$EDITOR_PKG"; }
[[ "$_docker" == "s" ]] && { info "Instalando Docker..."; yay -S --needed --noconfirm docker docker-compose; sudo systemctl enable docker; sudo usermod -aG docker "$USER"; }
[[ "$_steam" == "s" ]]  && { info "Instalando Steam...";  yay -S --needed --noconfirm steam; }

ok "Todos los paquetes instalados"

# ═══════════════════════════════════════════════════════════════
#  Despliegue de Dotfiles
# ═══════════════════════════════════════════════════════════════

header "Desplegando Dotfiles"

# Directorios destino
mkdir -p ~/.config/{hypr,quickshell/components,kitty,rofi,swaync,nvim,cava,scripts,qt6ct}
mkdir -p ~/.local/bin ~/Pictures/{Screenshots,wallpapers}
mkdir -p ~/.cache

# Mapa de configs: origen (relativo a DOTFILES_DIR) → destino
deploy() {
    local src="$DOTFILES_DIR/$1"
    local dst="$2"
    if [ -d "$src" ]; then
        info "Desplegando $1..."
        mkdir -p "$dst"
        cp -rf "$src"/. "$dst"/
    elif [ -f "$src" ]; then
        info "Desplegando $1..."
        cp -f "$src" "$dst"
    else
        warn "No encontrado: $1 (saltando)"
    fi
}

deploy "dot_config/hypr"        "$HOME/.config/hypr"
deploy "dot_config/quickshell"  "$HOME/.config/quickshell"
deploy "dot_config/kitty"       "$HOME/.config/kitty"
deploy "dot_config/rofi"        "$HOME/.config/rofi"
deploy "dot_config/swaync"      "$HOME/.config/swaync"
deploy "dot_config/nvim"        "$HOME/.config/nvim"
deploy "dot_config/cava"        "$HOME/.config/cava"
deploy "dot_config/scripts"     "$HOME/.config/scripts"
deploy "dot_config/qt6ct"       "$HOME/.config/qt6ct"
deploy "dot_zshrc"              "$HOME/.zshrc"

# Power menu script
if [ -f "$DOTFILES_DIR/dot_config/hypr/scripts/screenshot.sh" ]; then
    cp "$DOTFILES_DIR/dot_config/hypr/scripts/screenshot.sh" "$HOME/.config/hypr/scripts/"
fi

# Sudoers para toggle de cámara (F8)
info "Configurando sudoers para cámara..."
echo '%wheel ALL=(ALL) NOPASSWD: /usr/bin/modprobe -r uvcvideo, /usr/bin/modprobe uvcvideo' | sudo tee /etc/sudoers.d/camera >/dev/null
sudo chmod 440 /etc/sudoers.d/camera
ok "Sudoers para cámara configurado"

# Crear power menu si no existe
if [ ! -f "$HOME/.config/scripts/powermenu.sh" ]; then
    info "Creando power menu..."
    cat > "$HOME/.config/scripts/powermenu.sh" << 'PMEOF'
#!/bin/bash
options="  Apagar\n  Reiniciar\n  Suspender\n  Bloquear\n  Hibernar"
chosen=$(echo -e "$options" | rofi -dmenu -p "Power Menu" -theme-str 'window {width: 250px;} listview {lines: 5;}')
case "$chosen" in
    *Apagar)     systemctl poweroff ;;
    *Reiniciar)  systemctl reboot ;;
    *Suspender)  systemctl suspend ;;
    *Bloquear)   hyprlock || swaylock ;;
    *Hibernar)   systemctl hibernate ;;
esac
PMEOF
fi

# Permisos de ejecución
chmod +x "$HOME/.config/scripts/"*.sh 2>/dev/null || true
chmod +x "$HOME/.config/scripts/"*.py 2>/dev/null || true
chmod +x "$HOME/.config/hypr/scripts/"*.sh 2>/dev/null || true

# Wallpapers
if [ -d "$DOTFILES_DIR/wallps" ]; then
    info "Copiando wallpapers..."
    cp -r "$DOTFILES_DIR/wallps"/. ~/Pictures/wallpapers/
fi

# Monitor config por defecto
[ -f ~/.config/hypr/monitors.conf ] || echo "monitor=,preferred,auto,1" > ~/.config/hypr/monitors.conf

# Generar paleta inicial desde wallpaper por defecto
if [ -f "$HOME/.config/scripts/extract-colors.py" ] && command -v magick &>/dev/null; then
    info "Generando paleta de colores inicial..."
    DEFAULT_WP=$(ls ~/Pictures/wallpapers/*.{jpg,jpeg,png,webp} 2>/dev/null | head -1)
    if [ -n "$DEFAULT_WP" ]; then
        RAW=/tmp/qs-colors-raw
        magick "$DEFAULT_WP" -resize 200x200! -colors 8 -unique-colors -depth 8 txt:- 2>/dev/null \
            | tail -n +2 | grep -oE '#[0-9A-Fa-f]{6}' | head -8 > "$RAW"
        python3 "$HOME/.config/scripts/extract-colors.py" "$RAW" "$HOME/.cache/qs-palette" 2>/dev/null
        rm -f "$RAW"
        MONITOR=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].name' 2>/dev/null || echo 'eDP-1')
        cat > "$HOME/.config/hypr/hyprpaper.conf" <<WPEOF
wallpaper {
    monitor = $MONITOR
    path = $DEFAULT_WP
}
WPEOF
        ok "Paleta y wallpaper configurados"
    else
        warn "No hay wallpapers en ~/Pictures/wallpapers/ — paleta por defecto"
    fi
fi

ok "Dotfiles desplegados"

# ═══════════════════════════════════════════════════════════════
#  Configuración de Zsh
# ═══════════════════════════════════════════════════════════════

header "Configurando Shell"

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    info "Instalando Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    ok "Oh My Zsh instalado"
fi

if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
    info "Instalando Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
    ok "Powerlevel10k instalado"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    info "Instalando zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    info "Instalando zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

if [ "$SHELL" != "$(which zsh)" ]; then
    info "Cambiando shell por defecto a zsh..."
    sudo chsh -s "$(which zsh)" "$USER"
    ok "Shell cambiada a zsh"
fi

# ═══════════════════════════════════════════════════════════════
#  Servicios del sistema
# ═══════════════════════════════════════════════════════════════

header "Habilitando Servicios"

sudo systemctl enable --now NetworkManager 2>/dev/null || true
sudo systemctl enable --now bluetooth 2>/dev/null || true

ok "Servicios habilitados"

# ═══════════════════════════════════════════════════════════════
#  Validación
# ═══════════════════════════════════════════════════════════════

header "Validación"

REQUIRED=(hyprland quickshell kitty rofi swaync)
all_ok=true

for app in "${REQUIRED[@]}"; do
    if command -v "$app" &>/dev/null; then
        ok "$app instalado"
    else
        fail "$app NO encontrado"
        all_ok=false
    fi
done

# Verificar que los archivos de configuración existen
for cfg in ~/.config/quickshell/shell.qml ~/.config/hypr/hyprland.conf ~/.zshrc; do
    if [ -f "$cfg" ]; then
        ok "$(basename "$cfg") desplegado"
    else
        fail "$(basename "$cfg") NO encontrado"
        all_ok=false
    fi
done

# ═══════════════════════════════════════════════════════════════
#  Resumen
# ═══════════════════════════════════════════════════════════════

header "Instalación Completa"

if [ "$all_ok" = true ]; then
    echo -e "  ${GREEN}✓ Todo instalado correctamente${NC}\n"
    echo -e "  ${CYAN}Próximos pasos:${NC}"
    echo -e "    1. ${YELLOW}Cerrar sesión${NC}"
    echo -e "    2. Seleccionar ${YELLOW}Hyprland${NC} en el display manager"
    echo -e "    3. Iniciar sesión\n"
    echo -e "  ${CYAN}Atajos principales:${NC}"
    echo -e "    ${YELLOW}Super + Return${NC}    Terminal"
    echo -e "    ${YELLOW}Super${NC}             Launcher"
    echo -e "    ${YELLOW}Super + Q${NC}         Cerrar ventana"
    echo -e "    ${YELLOW}Super + W${NC}         Wallpaper picker"
    echo -e "    ${YELLOW}Super + Shift+S${NC}   Captura de pantalla"
    echo -e "  ${CYAN}Teclas de función:${NC}"
    echo -e "    ${YELLOW}F1${NC} Mute  ${YELLOW}F2${NC} Vol-  ${YELLOW}F3${NC} Vol+  ${YELLOW}F4${NC} Mic"
    echo -e "    ${YELLOW}F6${NC} Touchpad  ${YELLOW}F8${NC} Cámara  ${YELLOW}F9${NC} Lock"
    echo -e "    ${YELLOW}F10${NC} Pantallas  ${YELLOW}F11${NC} Brillo-  ${YELLOW}F12${NC} Brillo+\n"
    echo -e "  ${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}  Hyprland + Quickshell listo 󰖬 ${NC}"
    echo -e "  ${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
else
    fail "Algunos componentes fallaron. Revisa los errores arriba."
    exit 1
fi
