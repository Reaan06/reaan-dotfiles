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
DOTFILES_DIR="$SCRIPT_DIR"

# ── Helpers ──
header()  { echo -e "\n${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n  ${CYAN}$1${NC}\n${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }
ok()      { echo -e "  ${GREEN}✓${NC} $1"; }
info()    { echo -e "  ${BLUE}ℹ${NC} $1"; }
warn()    { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail()    { echo -e "  ${RED}✗${NC} $1"; }
die()     { fail "$1"; exit 1; }

terminal_config_root() {
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

terminal_state_dir() {
    printf '%s/reaan\n' "$(terminal_config_root)"
}

terminal_state_file() {
    printf '%s/terminal-dots.conf\n' "$(terminal_state_dir)"
}

terminal_herdr_config_file() {
    printf '%s/herdr/config.toml\n' "$(terminal_config_root)"
}

gentleman_installer_url() {
    case "$(uname -m)" in
        x86_64) printf '%s\n' 'https://github.com/Gentleman-Programming/Gentleman.Dots/releases/latest/download/gentleman-installer-linux-amd64' ;;
        aarch64) printf '%s\n' 'https://github.com/Gentleman-Programming/Gentleman.Dots/releases/latest/download/gentleman-installer-linux-arm64' ;;
        *) fail "Unsupported architecture: $(uname -m). Gentleman.Dots supports Linux x86_64 and aarch64."; return 1 ;;
    esac
}

write_terminal_state() {
    local value="$1"
    local directory="$(terminal_state_dir)"
    local file="$(terminal_state_file)"
    local temporary old_umask

    case "$value" in
        none|herdr|tmux|zellij) ;;
        *) fail "Invalid terminal state: $value"; return 1 ;;
    esac

    mkdir -p "$directory" || return 1
    chmod 700 "$directory" || return 1
    old_umask="$(umask)"
    umask 077
    if ! temporary="$(mktemp "$directory/.terminal-dots.conf.XXXXXX")"; then
        umask "$old_umask"
        return 1
    fi
    if ! printf '%s\n' "$value" > "$temporary"; then
        rm -f -- "$temporary"
        umask "$old_umask"
        return 1
    fi
    if ! chmod 600 "$temporary"; then
        rm -f -- "$temporary"
        umask "$old_umask"
        return 1
    fi
    if ! mv -f "$temporary" "$file"; then
        rm -f -- "$temporary"
        umask "$old_umask"
        return 1
    fi
    umask "$old_umask"
    chmod 600 "$file"
}

read_terminal_state() {
    local file="$(terminal_state_file)"
    local -a lines=()

    if [[ ! -f "$file" || ! -r "$file" ]]; then
        printf 'none\n'
        return 0
    fi
    mapfile -t lines < "$file" || {
        printf 'none\n'
        return 0
    }
    if (( ${#lines[@]} != 1 )); then
        printf 'none\n'
        return 0
    fi
    case "${lines[0]}" in
        none|herdr|tmux|zellij) printf '%s\n' "${lines[0]}" ;;
        *) printf 'none\n' ;;
    esac
}

normalize_terminal_dots_answer() {
    local answer="${1,,}"
    answer="${answer#"${answer%%[![:space:]]*}"}"
    answer="${answer%"${answer##*[![:space:]]}"}"
    case "$answer" in
        ''|n|no|0|false|off) printf 'none\n' ;;
        y|yes|s|si|1|true|on) printf 'enabled\n' ;;
        *) return 1 ;;
    esac
}

normalize_terminal_runtime_answer() {
    local answer="${1,,}"
    answer="${answer#"${answer%%[![:space:]]*}"}"
    answer="${answer%"${answer##*[![:space:]]}"}"
    case "$answer" in
        ''|h|herdr|1) printf 'herdr\n' ;;
        t|tmux|2) printf 'tmux\n' ;;
        z|zellij|3) printf 'zellij\n' ;;
        n|none|4) printf 'none\n' ;;
        *) return 1 ;;
    esac
}

normalize_terminal_shell_answer() {
    local answer="${1,,}"
    answer="${answer#"${answer%%[![:space:]]*}"}"
    answer="${answer%"${answer##*[![:space:]]}"}"
    case "$answer" in
        ''|z|zsh|2) printf 'zsh\n' ;;
        f|fish|1) printf 'fish\n' ;;
        n|nu|nushell|3) printf 'nushell\n' ;;
        *) return 1 ;;
    esac
}

prompt_terminal_shell() {
    local answer normalized
    while true; do
        read -r -p "  Shell (Fish/Zsh/Nushell, Zsh por defecto): " answer || answer=''
        if normalized="$(normalize_terminal_shell_answer "$answer")"; then
            printf '%s\n' "$normalized"
            return 0
        fi
        warn "Invalid shell. Use Fish, Zsh, or Nushell." >&2
    done
}

prompt_terminal_dots() {
    local answer normalized
    while true; do
        read -r -p "  ¿Integrar los Terminal DOTS? (s/N): " answer || answer=''
        if normalized="$(normalize_terminal_dots_answer "$answer")"; then
            printf '%s\n' "$normalized"
            return 0
        fi
        warn "Respuesta inválida. Usa s/yes o n/no." >&2
    done
}

prompt_terminal_runtime() {
    local answer normalized
    while true; do
        read -r -p "  WM/session (TMUX/Zellij/Herdr/None, Herdr por defecto): " answer || answer=''
        if normalized="$(normalize_terminal_runtime_answer "$answer")"; then
            printf '%s\n' "$normalized"
            return 0
        fi
        warn "Invalid WM/session. Use TMUX, Zellij, Herdr, or None." >&2
    done
}

preserve_herdr_config() {
    local source="$DOTFILES_DIR/dot_config/herdr/config.toml"
    local destination="$(terminal_herdr_config_file)"

    [[ -f "$source" ]] || return 0
    [[ -e "$destination" || -L "$destination" ]] && return 0
    mkdir -p "$(dirname -- "$destination")" || return 1
    cp -p -- "$source" "$destination"
}

install_gentleman_dots() {
    local shell="$1" wm="$2"
    (
        local url binary workdir
        url="$(gentleman_installer_url)" || exit 1
        umask 077
        workdir="$(mktemp -d "${TMPDIR:-/tmp}/gentleman-dots.XXXXXX")" || exit 1
        trap 'rm -rf -- "$workdir"' EXIT
        binary="$workdir/gentleman-installer"
        chmod 700 "$workdir"
        : > "$binary"
        chmod 700 "$binary"
        if ! curl --fail --location --silent --show-error --output "$binary" "$url"; then
            fail "Gentleman.Dots download failed; terminal DOTS remain disabled."
            exit 1
        fi
        chmod 700 "$binary"
        if ! (cd -- "$workdir" && "$binary" --non-interactive --terminal=kitty "--shell=$shell" "--wm=$wm" --backup=true); then
            fail "Gentleman.Dots installation failed; terminal DOTS remain disabled."
            exit 1
        fi
    )
}

configure_terminal_dots() {
    local selection shell

    selection="$(prompt_terminal_dots)"
    if ! write_terminal_state none; then
        fail "Unable to disable terminal DOTS safely."
        return 1
    fi
    if [[ "$selection" == none ]]; then
        info "Terminal DOTS disabled; existing packages and user files were preserved."
        return 0
    fi

    shell="$(prompt_terminal_shell)"
    selection="$(prompt_terminal_runtime)"
    if ! write_terminal_state none; then
        fail "Unable to reset terminal DOTS before installation."
        return 1
    fi
    case "$selection" in
        herdr|tmux|zellij|none) ;;
        *)
            fail "Invalid terminal WM/session selection."
            write_terminal_state none || true
            return 1
            ;;
    esac
    if ! install_gentleman_dots "$shell" "$selection"; then
        write_terminal_state none || true
        return 1
    fi
    if [[ "$selection" == herdr ]] && ! preserve_herdr_config; then
        write_terminal_state none || true
        return 1
    fi
    if ! write_terminal_state "$selection"; then
        write_terminal_state none || true
        fail "Unable to activate terminal DOTS safely."
        return 1
    fi
    ok "Terminal DOTS configured: $selection"
}

# ═══════════════════════════════════════════════════════════════
#  Validaciones
# ═══════════════════════════════════════════════════════════════

main() {

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

if ! configure_terminal_dots; then
    warn "Terminal DOTS no configurados; continuando con la instalación base."
fi

# ═══════════════════════════════════════════════════════════════
#  Paquetes
# ═══════════════════════════════════════════════════════════════

header "Instalando Paquetes"

CORE=(
    # Hyprland
    hyprland hyprlock hypridle hyprpaper
    xdg-desktop-portal-hyprland

    # Shell UI
    quickshell-git

    # Notificaciones
    swaync

    # Terminal emulator (Gentleman.Dots owns shell packages and configuration)
    kitty

    # Launcher
    rofi-wayland

    # Wallpaper + Screenshots
    swaybg grim slurp swappy

    # Audio / Brillo
    pavucontrol playerctl brightnessctl pamixer light easyeffects

    # Gestor de pantallas + Imagemagick (colores dinámicos)
    nwg-displays imagemagick jq

    # Wallpaper picker GUI (GTK4 + Libadwaita)
    python-gobject gtk4 libadwaita python-requests

    # Bluetooth
    bluez bluez-utils blueman

    # GitHub + Sensors
    github-cli lm_sensors

    # Red
    network-manager-applet

    # Clipboard
    wl-clipboard cliphist

    # Fuentes
    ttf-jetbrains-mono-nerd ttf-font-awesome
    noto-fonts noto-fonts-emoji

    # Sistema
    polkit-kde-agent base-devel cmake extra-cmake-modules

    # Desarrollo / Audio Service
    rust
    
    # Archivos
    dolphin file-roller unzip unrar p7zip
)

# ═══════════════════════════════════════════════════════════════
#  Despliegue de Configuraciones (Early Phase)
# ═══════════════════════════════════════════════════════════════

header "Desplegando Configuraciones"

# Directorios destino
mkdir -p ~/.config/{hypr,quickshell/components,kitty,rofi,swaync,nvim,cava,scripts,qt6ct}
mkdir -p ~/.local/bin ~/Pictures/{Screenshots,wallpapers}
mkdir -p ~/.cache

# Mapa de configs: origen (relativo a DOTFILES_DIR) → destino
deploy() {
    local src="$DOTFILES_DIR/$1"
    local dst="$2"
    [ ! -e "$src" ] && { warn "No encontrado: $1 (saltando)"; return 0; }
    
    info "Desplegando $1..."
    mkdir -p "$(dirname "$dst")" || true
    if [ -d "$src" ]; then
        mkdir -p "$dst" || true
        cp -rf "$src"/. "$dst"/ 2>/dev/null || true
    else
        mkdir -p "$(dirname "$dst")"
        cp -f "$src" "$dst" 2>/dev/null || true
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

chmod +x "$HOME/.config/scripts/"* 2>/dev/null || true
chmod +x "$HOME/.config/hypr/scripts/"* 2>/dev/null || true

ok "Configuraciones base desplegadas con éxito."

# ═══════════════════════════════════════════════════════════════
#  Instalación de Software
# ═══════════════════════════════════════════════════════════════

header "Instalando Paquetes"

# Verificar bloqueo de pacman
if [ -f /var/lib/pacman/db.lck ]; then
    warn "El gestor de paquetes está bloqueado (/var/lib/pacman/db.lck)."
    info "Si no hay otra instalación corriendo, ejecuta: sudo rm /var/lib/pacman/db.lck"
    # No morimos aquí, intentamos seguir pero avisamos.
fi

CLI_TOOLS=(
    eza bat ripgrep fd dust duf btop procs fzf
)

info "Sincronizando repositorios y actualizando el sistema (Full upgrade)..."
# Usamos --overwrite "*" para evitar fallos por conflictos de archivos (como en gemini-cli)
yay -Syu --noconfirm --overwrite "*"

info "Instalando/Actualizando paquetes core + Quickshell..."
yay -S --needed --noconfirm --overwrite "*" "${CORE[@]}"

info "Herramientas CLI modernas..."
yay -S --needed --noconfirm --overwrite "*" "${CLI_TOOLS[@]}"

[[ -n "$BROWSER" ]]    && { info "Instalando $BROWSER...";    yay -S --needed --noconfirm --overwrite "*" "$BROWSER"; }
[[ -n "$EDITOR_PKG" ]] && { info "Instalando $EDITOR_PKG..."; yay -S --needed --noconfirm --overwrite "*" "$EDITOR_PKG"; }
[[ "$_docker" == "s" ]] && { info "Instalando Docker..."; yay -S --needed --noconfirm --overwrite "*" docker docker-compose; sudo systemctl enable docker; sudo usermod -aG docker "$USER"; }
[[ "$_steam" == "s" ]]  && { info "Instalando Steam...";  yay -S --needed --noconfirm --overwrite "*" steam; }

ok "Todos los paquetes instalados"

# ═══════════════════════════════════════════════════════════════
#  Fix Permanente para Quickshell (Qt ABI Mismatch)
# ═══════════════════════════════════════════════════════════════

if command -v quickshell &>/dev/null; then
    # Chequear si quickshell alerta que debe ser recompilado por culpa de update de Qt
    if quickshell -c /dev/null 2>&1 | grep -qi "must be rebuilt\|rebuild"; then
        warn "Se detectó un desajuste de versión de Qt (Causa de que la barra desaparezca)."
        info "Eliminando caché caché anterior y forzando la recompilación pura de quickshell-git..."
        rm -rf "$HOME/.cache/yay/quickshell-git"
        yay -S --noconfirm quickshell-git
        ok "Quickshell recompilado estructuralmente para tu versión actual de Arch"
    fi
fi

# ═══════════════════════════════════════════════════════════════
#  Compilación e Instalación de eq-service
# ═══════════════════════════════════════════════════════════════

header "Instalando Servicio de Audio (eq-service)"

if [ -d "$DOTFILES_DIR/eq-service" ]; then
    info "Compilando eq-service..."
    cd "$DOTFILES_DIR/eq-service"
    if command -v cargo &>/dev/null; then
        cargo build --release
        sudo cp target/release/eq-service /usr/local/bin/
        
        info "Configurando servicio systemd para eq-service..."
        mkdir -p "$HOME/.config/systemd/user"
        cp eq-service.service "$HOME/.config/systemd/user/"
        systemctl --user daemon-reload
        systemctl --user enable --now eq-service
        ok "eq-service instalado y servicio activado"
    else
        fail "Cargo no encontrado. No se pudo compilar eq-service."
    fi
else
    warn "Directorio eq-service no encontrado. Saltando..."
fi

# Las llamadas a deploy fueron movidas al bloque inicial 


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

# Inicializar cache del tracker de apps si no existe o si el mes cambió
info "Inicializando tracker de uso de aplicaciones..."
python3 - << 'PYEOF'
import json, os, datetime
cache = os.path.expanduser('~/.cache/app_usage.json')
month = datetime.datetime.now().strftime('%Y-%m')
data = {}
try:
    data = json.load(open(cache))
except:
    pass
if data.get('_month') != month:
    data = {'_month': month}
    json.dump(data, open(cache, 'w'))
    print(f'  Cache inicializado para {month}')
else:
    print(f'  Cache existente ({month}): {len([k for k in data if k != "_month"])} apps registradas')
PYEOF

# Generar paleta inicial desde wallpaper por defecto
if [ -f "$HOME/.config/scripts/extract-colors.py" ] && command -v magick &>/dev/null && command -v python3 &>/dev/null; then
    info "Generando paleta de colores inicial..."
    DEFAULT_WP=$(ls ~/Pictures/wallpapers/*.{jpg,jpeg,png,webp} 2>/dev/null | head -1 || true)
    if [ -n "$DEFAULT_WP" ]; then
        RAW=/tmp/qs-colors-raw
        magick "$DEFAULT_WP" -resize 200x200! -colors 8 -unique-colors -depth 8 txt:- 2>/dev/null \
            | tail -n +2 | grep -oE '#[0-9A-Fa-f]{6}' | head -8 > "$RAW" || true
        python3 "$HOME/.config/scripts/extract-colors.py" "$RAW" "$HOME/.config/quickshell/.palette" 2>/dev/null || true
        rm -f "$RAW"
        
        # Generar hyprpaper.conf básico si no existe
        MONITOR=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].name' 2>/dev/null || echo 'eDP-1')
        if [ ! -f "$HOME/.config/hypr/hyprpaper.conf" ]; then
            cat > "$HOME/.config/hypr/hyprpaper.conf" <<WPEOF
wallpaper {
    monitor = $MONITOR
    path = $DEFAULT_WP
}
WPEOF
        fi
        ok "Paleta y wallpaper inicial configurados"
    else
        warn "No hay wallpapers en ~/Pictures/wallpapers/ — saltando paleta inicial"
    fi
fi

ok "Dotfiles desplegados"

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

    if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v hyprctl &>/dev/null; then
        info "Inicializando entorno Hyprland en caliente..."
        hyprctl reload &>/dev/null || true
        killall -q hyprpaper swaync quickshell hypridle || true
        nohup hyprpaper >/dev/null 2>&1 &
        nohup swaync >/dev/null 2>&1 &
        nohup hypridle >/dev/null 2>&1 &
        nohup quickshell -d > /dev/null 2>&1 &
        # Iniciar el tracker de uso de aplicaciones
        pkill -f app_tracker.py 2>/dev/null || true
        sleep 0.5
        nohup python3 "$HOME/.config/scripts/app_tracker.py" >> /tmp/app_tracker.log 2>&1 &
        ok "Servicios y barra recargados con éxito\n"
    else
        echo -e "  ${CYAN}Próximos pasos:${NC}"
        echo -e "    1. ${YELLOW}Cerrar sesión${NC}"
        echo -e "    2. Seleccionar ${YELLOW}Hyprland${NC} en el display manager"
        echo -e "    3. Iniciar sesión\n"
    fi

    echo -e "  ${CYAN}Atajos principales:${NC}"
    echo -e "    ${YELLOW}Super + Return${NC}    Terminal"
    echo -e "    ${YELLOW}Super + F1${NC}        Audio Manager"
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
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
