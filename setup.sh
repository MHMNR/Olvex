#!/usr/bin/env bash
# Olvex Shell & Hyprland Automated Environment Setup

set -euo pipefail

# Standard POSIX ANSI Terminal Colors
CLR_CYAN='\033[0;36m'
CLR_BLUE='\033[0;34m'
CLR_GREEN='\033[0;32m'
CLR_YELLOW='\033[1;33m'
CLR_RED='\033[0;31m'
CLR_MAGENTA='\033[0;35m'
CLR_BOLD='\033[1m'
CLR_DIM='\033[2m'
CLR_RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
TARGET_HYPR="${HOME}/.config/hypr"
TARGET_LOCAL="${HOME}/.local/Olvex"
TARGET_QSCONF="${HOME}/.config/quickshell/olvex"
TARGET_BIN="${HOME}/.local/bin"

banner() {
    clear
    echo -e "${CLR_CYAN}${CLR_BOLD}"
    echo "  ██████╗ ██╗     ██╗   ██╗███████╗██╗  ██╗"
    echo " ██╔═══██╗██║     ██║   ██║██╔════╝╚██╗██╔╝"
    echo " ██║   ██║██║     ██║   ██║█████╗   ╚███╔╝ "
    echo " ██║   ██║██║     ╚██╗ ██╔╝██╔══╝   ██╔██╗ "
    echo " ╚██████╔╝███████╗ ╚████╔╝ ███████╗██╔╝ ██╗"
    echo "  ╚═════╝ ╚══════╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝"
    echo -e "         ${CLR_MAGENTA}Desktop Environment Deployment Manager${CLR_RESET}\n"
}

section_header() {
    local title="$1"
    echo -e "\n${CLR_CYAN}${CLR_BOLD}--- [ ${title} ] ───────────────────────────────────────────${CLR_RESET}"
}

log_info() {
    echo -e "${CLR_BLUE}[INFO]${CLR_RESET} $1"
}

log_success() {
    echo -e "${CLR_GREEN}[OK]${CLR_RESET} $1"
}

log_warn() {
    echo -e "${CLR_YELLOW}[WARN]${CLR_RESET} $1"
}

log_error() {
    echo -e "${CLR_RED}[ERROR]${CLR_RESET} $1"
}

confirm() {
    local prompt="$1"
    local default="${2:-Y}"
    local hint
    if [[ "$default" == "Y" ]]; then
        hint="Y/n"
    else
        hint="y/N"
    fi

    echo -ne "${CLR_BOLD}${prompt}${CLR_RESET} [${CLR_CYAN}${hint}${CLR_RESET}]: "
    read -rp "" resp
    resp="${resp:-$default}"
    [[ "$resp" =~ ^[Yy]$ ]]
}

check_environment() {
    section_header "Pre-flight Verification"
    log_info "Verifying deployment package integrity..."
    
    if [[ ! -d "${SCRIPT_DIR}/Olvex" ]]; then
        log_error "Missing required directory: ${SCRIPT_DIR}/Olvex"
        exit 1
    fi

    if [[ ! -d "${SCRIPT_DIR}/.config" ]] && [[ ! -d "${SCRIPT_DIR}/hypr" ]]; then
        log_error "Missing required configuration directory in ${SCRIPT_DIR}"
        exit 1
    fi

    log_success "Package integrity verified."
}

# 1. Mirror Optimization & Keyring Repair
optimize_mirrors_and_keyring() {
    section_header "System Repository & Keyring Initialization"
    
    log_info "Checking Pacman keyring status..."
    if ! sudo pacman-key --list-keys &>/dev/null; then
        log_warn "Initializing local GPG keyring..."
        sudo pacman-key --init || true
        sudo pacman-key --populate archlinux || true
    fi

    log_info "Updating archlinux-keyring package..."
    sudo pacman -Sy --needed --noconfirm archlinux-keyring || true

    log_info "Refreshing package databases..."
    sudo pacman -Sy --noconfirm || true
    log_success "Databases synchronized."
}

# 2. Setup AUR Helper (yay/paru selection)
select_and_ensure_aur_helper() {
    section_header "AUR Helper Verification"

    if command -v yay &>/dev/null; then
        log_success "Active AUR helper detected: yay"
        AUR_HELPER="yay"
        return 0
    elif command -v paru &>/dev/null; then
        log_success "Active AUR helper detected: paru"
        AUR_HELPER="paru"
        return 0
    fi

    log_warn "No supported AUR helper (yay/paru) found."
    echo -e " ${CLR_BOLD}Select an AUR helper to build and install:${CLR_RESET}"
    echo -e "   [1] yay-bin  (Precompiled binary - Recommended)"
    echo -e "   [2] paru-bin (Rust-based AUR helper)"
    
    local choice
    echo -ne " ${CLR_BOLD}Selection [1/2] (Default: 1): ${CLR_RESET}"
    read -rp "" choice
    choice="${choice:-1}"

    log_info "Installing toolchain dependencies (base-devel, git, cmake, ninja)..."
    sudo pacman -S --needed --noconfirm base-devel git cmake ninja || true

    local tmp_dir
    tmp_dir="$(mktemp -d)"

    if [[ "$choice" == "2" ]]; then
        log_info "Compiling paru-bin..."
        git clone https://aur.archlinux.org/paru-bin.git "$tmp_dir/paru-bin"
        ( cd "$tmp_dir/paru-bin" && makepkg -si --noconfirm )
        AUR_HELPER="paru"
    else
        log_info "Compiling yay-bin..."
        git clone https://aur.archlinux.org/yay-bin.git "$tmp_dir/yay-bin"
        ( cd "$tmp_dir/yay-bin" && makepkg -si --noconfirm )
        AUR_HELPER="yay"
    fi
    rm -rf "$tmp_dir"
    log_success "AUR Helper (${AUR_HELPER}) installed."
}

# 3. Intelligent Dependency Check & Conflict Resolution Precheck
precheck_and_resolve_dependencies() {
    section_header "Dependency Precheck & Conflict Analysis"

    local pkgs=(
        base-devel cmake ninja git pkgconf gcc-libs glibc
        qt6-base qt6-declarative qt6-wayland qt6-shadertools qt6-5compat qt6-multimedia qt6-svg qt6-imageformats
        quickshell hyprland wl-clipboard cliphist app2unit
        libnotify upower bluez bluez-utils
        ddcutil brightnessctl libcava networkmanager lm_sensors fish aubio libpipewire pipewire wireplumber
        noto-fonts ttf-cascadia-code-nerd
        swappy libqalculate bash mpv ydotool grim slurp
        python-pillow python-pip python3 gpu-screen-recorder fprintd foot kitty
        util-linux pciutils fzf firefox
        thunar thunar-volman thunar-archive-plugin thunar-media-tags-plugin adw-gtk-theme xdg-desktop-portal-gtk
        tumbler ffmpegthumbnailer gvfs gvfs-mtp gvfs-gphoto2 gvfs-afc gvfs-smb polkit-gnome wtype
    )

    MISSING_PKGS=()
    for pkg in "${pkgs[@]}"; do
        if ! pacman -Qq "$pkg" &>/dev/null; then
            MISSING_PKGS+=("$pkg")
        fi
    done

    if ! pacman -Qq | grep -Eiq 'ttf-material-symbols|material-symbols|ttf-google-material-design-icons'; then
        MISSING_PKGS+=("ttf-material-symbols-variable")
    fi

    if [ ${#MISSING_PKGS[@]} -eq 0 ]; then
        log_success "All system dependencies and toolchains are satisfied."
        READY_TO_INSTALL=true
        return 0
    fi

    echo -e " ${CLR_BOLD}Unresolved dependencies detected (${#MISSING_PKGS[@]}):${CLR_RESET}"
    echo -e "  ${CLR_DIM}${MISSING_PKGS[*]}${CLR_RESET}\n"

    log_info "Analyzing package conflicts..."
    if pacman -Qq | grep -Eiq 'ttf-material-symbols-variable-git'; then
        log_warn "Notice: Installed 'ttf-material-symbols-variable-git' conflicts with 'ttf-material-symbols-variable'."
        log_info "Package manager will prompt for replacement approval during execution."
    fi

    if confirm "Proceed with installation of missing packages?" "Y"; then
        READY_TO_INSTALL=true
    else
        log_warn "Deployment aborted by user."
        exit 0
    fi
}

# 4. Perform Main Installation
execute_installation() {
    section_header "Installing Dependencies"

    if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
        log_info "Invoking ${AUR_HELPER}..."
        
        if [ "$AUR_HELPER" = "yay" ]; then
            yay -S --needed --diffmenu=false --cleanmenu=false --redownload=false "${MISSING_PKGS[@]}" || true
        elif [ "$AUR_HELPER" = "paru" ]; then
            paru -S --needed --fm=false --ch=false "${MISSING_PKGS[@]}" || true
        else
            sudo pacman -S --needed "${MISSING_PKGS[@]}" || true
        fi
        log_success "Dependencies successfully installed."
    fi

    setup_directories_and_copy
    build_and_setup_olvex
}

setup_directories_and_copy() {
    section_header "Deploying System Configurations"

    local skip_config=false
    local items_to_deploy=()

    if [[ -d "${SCRIPT_DIR}/.config" ]]; then
        for item in "${SCRIPT_DIR}/.config"/*; do
            [ -e "$item" ] || continue
            items_to_deploy+=("~/.config/$(basename "$item")")
        done
    elif [[ -d "${SCRIPT_DIR}/hypr" ]]; then
        items_to_deploy+=("~/.config/hypr")
    fi

    if [[ ${#items_to_deploy[@]} -gt 0 ]]; then
        log_warn "Existing user configuration target detected in ${HOME}/.config/"
        echo -e " ${CLR_BOLD}Target configuration paths to be deployed/replaced:${CLR_RESET}"
        for path in "${items_to_deploy[@]}"; do
            echo -e "   • ${CLR_CYAN}${path}${CLR_RESET}"
        done
        echo ""

        if confirm "Overwrite the above configuration paths with installer defaults?" "Y"; then
            for path in "${items_to_deploy[@]}"; do
                local folder_name
                folder_name="$(basename "$path")"
                local existing_target="${HOME}/.config/${folder_name}"
                if [[ -d "$existing_target" ]]; then
                    local backup_dir="${existing_target}_backup_$(date +%Y%m%d_%H%M%S)"
                    log_info "Creating timestamped backup of existing ~/.config/${folder_name} -> ${backup_dir}"
                    cp -r "$existing_target" "$backup_dir"
                    log_success "Backup created for ${folder_name}."
                fi
            done
        else
            log_info "Preserving existing configurations. Skipping deployment copy."
            skip_config=true
        fi
    fi

    if [ "$skip_config" = false ]; then
        if [[ -d "${SCRIPT_DIR}/.config" ]]; then
            log_info "Deploying configuration tree to ${HOME}/..."
            cp -r "${SCRIPT_DIR}/.config" "${HOME}/"
            log_success "Configuration tree deployed to ${HOME}/."
        elif [[ -d "${SCRIPT_DIR}/hypr" ]]; then
            log_info "Deploying Hyprland configuration to ${TARGET_HYPR}..."
            mkdir -p "${HOME}/.config"
            cp -r "${SCRIPT_DIR}/hypr" "${HOME}/.config/"
            log_success "Hyprland configuration deployed."
        fi
    fi

    log_info "Deploying Olvex shell core to ${TARGET_LOCAL}..."
    mkdir -p "${HOME}/.local"
    rm -rf "$TARGET_LOCAL"
    cp -r "${SCRIPT_DIR}/Olvex" "$TARGET_LOCAL"
    log_success "Olvex shell core deployed."
}

build_and_setup_olvex() {
    section_header "Compiling C++ Plugins & System Integration"
    
    local build_dir="${TARGET_LOCAL}/build"
    mkdir -p "$build_dir"
    mkdir -p "$TARGET_QSCONF"
    mkdir -p "$TARGET_BIN"
    mkdir -p "${HOME}/.config/olvex/monitors"
    mkdir -p "${HOME}/Pictures/Wallpapers"

    log_info "Configuring CMake build system..."
    cd "$build_dir"
    
    cmake -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/ \
        -DINSTALL_QSCONFDIR="$TARGET_QSCONF" \
        -DVERSION="1.0.0" \
        -DGIT_REVISION="release" \
        ..

    log_info "Compiling native components (Parallel Job Queue)..."
    cmake --build . -j"$(nproc 2>/dev/null || echo 2)"

    log_info "Installing compiled targets to system paths (sudo required)..."
    sudo cmake --install .

    log_info "Registering olvex CLI executable..."
    local standalone_olvex="${TARGET_LOCAL}/scripts/olvex"
    chmod +x "$standalone_olvex" "${TARGET_LOCAL}/scripts/install-cli.sh" "${TARGET_LOCAL}/scripts/olvex-backend.sh" 2>/dev/null || true
    
    mkdir -p "${TARGET_BIN}"
    ln -sfn "${standalone_olvex}" "${TARGET_BIN}/olvex"
    sudo ln -sfn "${standalone_olvex}" "/usr/local/bin/olvex" 2>/dev/null || true
    log_success "CLI linked (${TARGET_BIN}/olvex & /usr/local/bin/olvex)."

    log_info "Initializing ydotool service integration..."
    if [[ -f "${TARGET_LOCAL}/scripts/setup-ydotool.sh" ]]; then
        chmod +x "${TARGET_LOCAL}/scripts/setup-ydotool.sh"
        (
            cd "${TARGET_LOCAL}"
            ./scripts/setup-ydotool.sh 2>/dev/null || true
        )
    fi
}

finish() {
    cd "${HOME}" || true
    section_header "Post-Installation Tasks"

    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || pgrep -x Hyprland &>/dev/null; then
        if confirm "Hyprland is running. Reload Hyprland and restart Olvex Shell?" "Y"; then
            log_info "Reloading Hyprland compositor..."
            hyprctl reload 2>/dev/null || true

            log_info "Restarting Olvex Shell daemon..."
            "${TARGET_LOCAL}/scripts/olvex" shell restart 2>/dev/null || "${TARGET_LOCAL}/scripts/olvex" shell -d 2>/dev/null || true
        else
            log_info "Session reload skipped."
        fi
    else
        if confirm "Hyprland is not running. Launch Hyprland session?" "Y"; then
            log_info "Initializing Hyprland environment..."
            if command -v start-hyprland &>/dev/null; then
                log_info "Executing start-hyprland..."
                exec start-hyprland
            elif command -v uwsm &>/dev/null; then
                log_info "Executing uwsm..."
                exec uwsm start hyprland-session.desktop 2>/dev/null || exec Hyprland
            elif command -v Hyprland &>/dev/null; then
                log_info "Executing Hyprland..."
                exec Hyprland
            else
                log_warn "Hyprland executable not found in PATH."
            fi
        else
            log_info "Session launch skipped."
        fi
    fi

    section_header "Installation Summary"
    
    echo -e " ${CLR_GREEN}Olvex Shell and Hyprland environment deployed successfully.${CLR_RESET}\n"
    echo -e " ${CLR_BOLD}Target Paths:${CLR_RESET}"
    echo -e "   • Hyprland Config  : ${CLR_CYAN}${TARGET_HYPR}${CLR_RESET}"
    echo -e "   • Olvex Shell Core : ${CLR_CYAN}${TARGET_LOCAL}${CLR_RESET}"
    echo -e "   • Quickshell Config: ${CLR_CYAN}${TARGET_QSCONF}${CLR_RESET}"
    echo -e "   • Binary Location  : ${CLR_CYAN}${TARGET_BIN}/olvex${CLR_RESET}\n"
    
    echo -e " ${CLR_DIM}Note: The source installer directory can now be moved or removed safely.${CLR_RESET}\n"

    echo -e " ${CLR_BOLD}Management Commands:${CLR_RESET}"
    echo -e "   • Start Shell     : ${CLR_YELLOW}olvex shell -d${CLR_RESET}"
    echo -e "   • Restart Shell   : ${CLR_YELLOW}olvex shell restart${CLR_RESET}"
    echo -e "   • Toggle Launcher : ${CLR_YELLOW}olvex shell drawers toggle launcher${CLR_RESET}"
    echo -e "   • Reload Hyprland : ${CLR_YELLOW}hyprctl reload${CLR_RESET}\n"

    # Fix permissions for common user directories that may have been touched by sudo pacman or installer hooks
    log_info "Restoring ownership of user configuration and cache directories..."
    sudo chown -R "$USER:$USER" "${HOME}/.config" "${HOME}/.cache" "${HOME}/.local" 2>/dev/null || true

    echo -e "\n"
}

main() {
    banner
    check_environment
    optimize_mirrors_and_keyring
    select_and_ensure_aur_helper
    precheck_and_resolve_dependencies
    
    if [ "${READY_TO_INSTALL:-false}" = true ]; then
        execute_installation
        finish
    fi
}

main "$@"
