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

terminal_shell_state_file() {
    printf '%s/terminal-shell.conf\n' "$(terminal_state_dir)"
}

terminal_herdr_config_file() {
    printf '%s/herdr/config.toml\n' "$(terminal_config_root)"
}

upstream_managed_config_paths() {
    printf '%s\n' \
        "$HOME/.config/nvim" \
        "$HOME/.config/fish" \
        "$HOME/.zshrc" \
        "$HOME/.oh-my-zsh" \
        "$HOME/.config/nushell" \
        "$HOME/.tmux.conf" \
        "$HOME/.tmux" \
        "$HOME/.config/zellij" \
        "$HOME/.config/herdr" \
        "$HOME/.config/alacritty" \
        "$HOME/.config/wezterm" \
        "$HOME/.wezterm.lua" \
        "$HOME/.config/kitty" \
        "$HOME/.config/ghostty" \
        "$HOME/.config/starship.toml"
}

managed_config_has_special_entry() {
    local path special
    while IFS= read -r path; do
        [[ -e "$path" || -L "$path" ]] || continue
        if ! special="$(find -P -- "$path" \( -type s -o -type p -o -type b -o -type c \) -print -quit 2>/dev/null)"; then
            return 1
        fi
        [[ -z "$special" ]] || return 0
    done < <(upstream_managed_config_paths)
    return 2
}

create_safe_config_backup() {
    local backup_dir archive path relative
    local -a existing_paths=()

    backup_dir="$(mktemp -d "$HOME/.gentleman-safe-backup-$(date +%Y%m%d-%H%M%S)-XXXXXX")" || return 1
    archive="$backup_dir/configs.tar.gz"
    while IFS= read -r path; do
        if [[ -e "$path" || -L "$path" ]]; then
            relative="${path#"$HOME/"}"
            existing_paths+=("$relative")
        fi
    done < <(upstream_managed_config_paths)

    if ((${#existing_paths[@]} == 0)) || ! tar -C "$HOME" -czf "$archive" -- "${existing_paths[@]}"; then
        rm -rf -- "$backup_dir"
        return 1
    fi
    chmod 700 "$backup_dir" || { rm -rf -- "$backup_dir"; return 1; }
    printf '%s\n' "$backup_dir"
}

restore_safe_config_backup() {
    local backup_dir="$1" archive="$1/configs.tar.gz"

    [[ -f "$archive" ]] || return 1
    tar -C "$HOME" --extract --gzip --file "$archive" --overwrite
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

write_terminal_shell_state() {
    local value="$1"
    local directory="$(terminal_state_dir)"
    local file="$(terminal_shell_state_file)"
    local temporary old_umask

    case "$value" in
        none|fish|zsh|nushell) ;;
        *) fail "Invalid terminal shell state: $value"; return 1 ;;
    esac

    mkdir -p "$directory" || return 1
    chmod 700 "$directory" || return 1
    old_umask="$(umask)"
    umask 077
    if ! temporary="$(mktemp "$directory/.terminal-shell.conf.XXXXXX")"; then
        umask "$old_umask"
        return 1
    fi
    if ! printf '%s\n' "$value" > "$temporary" || ! chmod 600 "$temporary" || ! mv -f "$temporary" "$file"; then
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

read_terminal_shell_state() {
    local file="$(terminal_shell_state_file)" value
    local -a lines=()
    [[ -f "$file" && -r "$file" ]] || { printf 'none\n'; return 0; }
    mapfile -t lines < "$file" || { printf 'none\n'; return 0; }
    (( ${#lines[@]} == 1 )) || { printf 'none\n'; return 0; }
    value="${lines[0]}"
    case "$value" in
        none|fish|zsh|nushell) printf '%s\n' "$value" ;;
        *) printf 'none\n' ;;
    esac
}

terminal_shell_executable() {
    case "$1" in
        fish) printf 'fish\n' ;;
        zsh) printf 'zsh\n' ;;
        nushell) printf 'nu\n' ;;
        *) return 1 ;;
    esac
}

terminal_shell_config_file() {
    case "$1" in
        fish) printf '%s\n' "$HOME/.config/fish/config.fish" ;;
        zsh) printf '%s\n' "$HOME/.zshrc" ;;
        nushell) printf '%s\n' "$HOME/.config/nushell/config.nu" ;;
        *) return 1 ;;
    esac
}

configure_kitty_shell() {
    local shell="$1" executable config temporary
    executable="$(terminal_shell_executable "$shell")" || return 1
    config="$HOME/.config/kitty/kitty.conf"
    [[ -f "$config" ]] || return 1
    temporary="$(mktemp "${config}.XXXXXX")" || return 1
    if ! awk -v executable="$executable" '
        /^[[:space:]]*shell[[:space:]]+/ {
            if (!replaced) { print "shell " executable; replaced = 1 }
            next
        }
        { print }
        END { if (!replaced) print "\n# Managed by Gentleman.Dots selection\nshell " executable }
    ' "$config" > "$temporary"; then
        rm -f -- "$temporary"
        return 1
    fi
    chmod 600 "$temporary" && mv -f "$temporary" "$config" || { rm -f -- "$temporary"; return 1; }
}

kitty_effective_shell() {
    local config="${1:-$HOME/.config/kitty/kitty.conf}"
    [[ -r "$config" ]] || return 1
    awk '/^[[:space:]]*shell[[:space:]]+/ { value=$2 } END { if (value) print value; else exit 1 }' "$config"
}

normalize_terminal_dots_answer() {
    local answer="${1,,}"
    answer="${answer#"${answer%%[![:space:]]*}"}"
    answer="${answer%"${answer##*[![:space:]]}"}"
    case "$answer" in
        ''|n|no|0|false|off|2) printf 'none\n' ;;
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
        printf '  1) Fish\n  2) Zsh\n  3) Nushell\n' >&2
        read -r -p "  Opción (1-3, Zsh por defecto): " answer || answer=''
        if normalized="$(normalize_terminal_shell_answer "$answer")"; then
            printf '%s\n' "$normalized"
            return 0
        fi
        warn "Invalid shell. Use a number between 1 and 3." >&2
    done
}

prompt_terminal_dots() {
    local answer normalized
    while true; do
        printf '  1) Sí\n  2) No\n' >&2
        read -r -p "  Opción (1-2, No por defecto): " answer || answer=''
        if normalized="$(normalize_terminal_dots_answer "$answer")"; then
            printf '%s\n' "$normalized"
            return 0
        fi
        warn "Respuesta inválida. Usa un número entre 1 y 2." >&2
    done
}

prompt_terminal_runtime() {
    local answer normalized
    while true; do
        printf '  1) Herdr\n  2) TMUX\n  3) Zellij\n  4) None\n' >&2
        read -r -p "  Opción (1-4, Herdr por defecto): " answer || answer=''
        if normalized="$(normalize_terminal_runtime_answer "$answer")"; then
            printf '%s\n' "$normalized"
            return 0
        fi
        warn "Invalid WM/session. Use a number between 1 and 4." >&2
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
    local backup_flag='--backup=true' safe_backup_dir

    if managed_config_has_special_entry; then
        safe_backup_dir="$(create_safe_config_backup)" || {
            fail "Unable to create a safe backup for special config entries; terminal DOTS remain disabled."
            return 1
        }
        backup_flag='--backup=false'
        info "Special config entry detected; safe backup saved at: $safe_backup_dir"
    elif [[ "$?" -ne 2 ]]; then
        fail "Unable to inspect managed config entries; terminal DOTS remain disabled."
        return 1
    fi
    if ! (
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
        if ! (cd -- "$workdir" && "$binary" --non-interactive --terminal=kitty "--shell=$shell" "--wm=$wm" "$backup_flag"); then
            fail "Gentleman.Dots installation failed; terminal DOTS remain disabled."
            exit 1
        fi
    ); then
        if [[ -n "${safe_backup_dir:-}" ]]; then
            # The upstream process may have changed managed files before failing.
            if ! restore_safe_config_backup "$safe_backup_dir"; then
                fail "Unable to restore the safe config snapshot; terminal DOTS remain disabled."
                return 1
            fi
            ok "Safe config snapshot restored after Gentleman.Dots failure."
        fi
        return 1
    fi
}

configure_terminal_dots() {
    local selection shell

    selection="$(prompt_terminal_dots)"
    if ! write_terminal_state none || ! write_terminal_shell_state none; then
        fail "Unable to disable terminal DOTS safely."
        return 1
    fi
    if [[ "$selection" == none ]]; then
        info "Terminal DOTS disabled; no shell/session selected and existing files were preserved."
        return 0
    fi

    shell="$(prompt_terminal_shell)"
    selection="$(prompt_terminal_runtime)"
    if ! write_terminal_state none || ! write_terminal_shell_state none; then
        fail "Unable to reset terminal DOTS before installation."
        return 1
    fi
    case "$selection" in
        herdr|tmux|zellij|none) ;;
        *)
            fail "Invalid terminal WM/session selection."
            write_terminal_state none || true
            write_terminal_shell_state none || true
            return 1
            ;;
    esac
    if ! install_gentleman_dots "$shell" "$selection"; then
        write_terminal_state none || true
        write_terminal_shell_state none || true
        return 1
    fi
    if [[ "$selection" == herdr ]] && ! preserve_herdr_config; then
        write_terminal_state none || true
        write_terminal_shell_state none || true
        return 1
    fi
    if ! write_terminal_state "$selection" || ! write_terminal_shell_state "$shell"; then
        write_terminal_state none || true
        write_terminal_shell_state none || true
        fail "Unable to activate terminal DOTS safely."
        return 1
    fi
    ok "Terminal DOTS configured: $shell / $selection"
}

validate_terminal_selection() {
    local selected_shell selected_session shell_executable shell_config session_label session_command effective_shell

    selected_shell="$(read_terminal_shell_state)"
    selected_session="$(read_terminal_state)"
    if [[ "$selected_shell" == none ]]; then
        info "Selected shell: None; config: None"
        info "Selected session: None (no shell/session selected)"
        return 0
    fi

    shell_executable="$(terminal_shell_executable "$selected_shell")"
    shell_config="$(terminal_shell_config_file "$selected_shell")"
    info "Selected shell: $selected_shell ($shell_executable); config: $shell_config"
    if [[ -f "$shell_config" ]]; then
        ok "$(basename "$shell_config") deployed"
    else
        fail "$(basename "$shell_config") NOT found"
        all_ok=false
    fi
    if command -v "$shell_executable" &>/dev/null; then
        ok "$shell_executable available"
    else
        fail "$shell_executable NOT available"
        all_ok=false
    fi

    case "$selected_session" in
        herdr) session_label="Herdr"; session_command="$HOME/.local/bin/herdr" ;;
        tmux) session_label="TMUX"; session_command="$(command -v tmux 2>/dev/null || true)" ;;
        zellij) session_label="Zellij"; session_command="$(command -v zellij 2>/dev/null || true)" ;;
        *) selected_session=none; session_label="None"; session_command='' ;;
    esac
    if [[ "$selected_session" == none ]]; then
        info "Selected session: None"
    elif [[ -x "$session_command" ]]; then
        ok "Selected session: $session_label (available)"
    else
        fail "Selected session: $session_label (unavailable)"
        all_ok=false
    fi

    effective_shell="$(kitty_effective_shell 2>/dev/null || true)"
    if [[ "$effective_shell" == "$shell_executable" ]]; then
        ok "Kitty effective shell matches selection: $effective_shell"
    else
        fail "Kitty effective shell '$effective_shell' does not match selection '$shell_executable'"
        all_ok=false
    fi
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

selected_shell="$(read_terminal_shell_state)"
if [[ "$selected_shell" != none ]]; then
    if ! configure_kitty_shell "$selected_shell"; then
        write_terminal_state none || true
        write_terminal_shell_state none || true
        warn "Kitty shell configuration failed; terminal DOTS remain disabled."
    else
        ok "Kitty configured for $(terminal_shell_executable "$selected_shell")"
    fi
fi

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
for cfg in ~/.config/quickshell/shell.qml ~/.config/hypr/hyprland.conf; do
    if [ -f "$cfg" ]; then
        ok "$(basename "$cfg") desplegado"
    else
        fail "$(basename "$cfg") NO encontrado"
        all_ok=false
    fi
done

validate_terminal_selection

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
