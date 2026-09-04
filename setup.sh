#!/usr/bin/env bash
# Olvex Shell & Hyprland Automated Environment Setup
# Universal V2 Architecture

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

# Upfront Wizard Configuration State
CONF_OVERWRITE=true
CONF_DRIVERS=false
CONF_LOGIN_METHOD=1
CONF_DM_CHOICE=1
CONF_SET_FISH=false
CONF_SESSION_ACTION="none"

HAS_NVIDIA=false
DRIVER_PKGS=()
DETECTED_HARDWARE=()
DM_PKGS=()
ALL_MISSING_PKGS=()
AUR_HELPER="pacman"
NOCONFIRM=false

banner() {
    clear
    echo -e "${CLR_CYAN}${CLR_BOLD}"
    echo "  ██████╗ ██╗     ██╗   ██╗███████╗██╗  ██╗"
    echo " ██╔═══██╗██║     ██║   ██║██╔════╝╚██╗██╔╝"
    echo " ██║   ██║██║     ██║   ██║█████╗   ╚███╔╝ "
    echo " ██║   ██║██║     ╚██╗ ██╔╝██╔══╝   ██╔██╗ "
    echo " ╚██████╔╝███████╗ ╚████╔╝ ███████╗██╔╝ ██╗"
    echo "  ╚═════╝ ╚══════╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝"
    echo -e "         ${CLR_MAGENTA}Desktop Environment Deployment Manager v2${CLR_RESET}\n"
}

section_header() {
    local title="$1"
    echo -e "\n${CLR_CYAN}${CLR_BOLD}--- [ ${title} ] ───────────────────────────────────────────${CLR_RESET}"
}

log_info() { echo -e "${CLR_BLUE}[INFO]${CLR_RESET} $1"; }
log_success() { echo -e "${CLR_GREEN}[OK]${CLR_RESET} $1"; }
log_warn() { echo -e "${CLR_YELLOW}[WARN]${CLR_RESET} $1"; }
log_error() { echo -e "${CLR_RED}[ERROR]${CLR_RESET} $1"; }

confirm() {
    if [ "${NOCONFIRM:-false}" = true ]; then
        return 0
    fi
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
    
    if [ "$(id -u)" -eq 0 ]; then
        log_error "This script must NOT be run as root (do not use sudo ./setup.sh)."
        log_error "Please run it as your normal user. The script will request sudo when needed."
        exit 1
    fi

    log_info "Pre-creating essential user directories to prevent root permission pollution..."
    mkdir -p "${HOME}/.config" "${HOME}/.cache" "${HOME}/.local/share" "${HOME}/.local/state" "${HOME}/.local/bin" "${HOME}/Pictures/Wallpapers"

    log_info "Verifying deployment package integrity..."
    if [[ ! -d "${SCRIPT_DIR}/Olvex" ]]; then
        log_error "Missing required directory: ${SCRIPT_DIR}/Olvex"
        exit 1
    fi

    if [[ ! -d "${SCRIPT_DIR}/.config" ]] && [[ ! -d "${SCRIPT_DIR}/hypr" ]]; then
        log_error "Missing required configuration directory in ${SCRIPT_DIR}"
        exit 1
    fi

    log_success "Environment ready. Package integrity verified."
}

optimize_mirrors_and_keyring() {
    section_header "System Repository & Keyring Initialization"
    
    log_info "Checking Pacman keyring status..."
    if ! sudo pacman-key --list-keys &>/dev/null; then
        log_warn "Initializing local GPG keyring..."
        sudo pacman-key --init || true
        sudo pacman-key --populate archlinux || true
    fi

    log_info "Updating archlinux-keyring package..."
    sudo -H pacman -Sy --needed --noconfirm archlinux-keyring || true

    log_info "Refreshing package databases..."
    sudo -H pacman -Sy --noconfirm || true
    log_success "Databases synchronized."
}

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
    
    local choice="1"
    if [ "${NOCONFIRM:-false}" = false ]; then
        echo -ne " ${CLR_BOLD}Selection [1/2] (Default: 1): ${CLR_RESET}"
        read -rp "" choice
        choice="${choice:-1}"
    fi

    log_info "Installing toolchain dependencies (base-devel, git, cmake, ninja)..."
    sudo -H pacman -S --needed --noconfirm base-devel git cmake ninja || true

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

install_pkgs() {
    local pkgs=("$@")
    [ ${#pkgs[@]} -eq 0 ] && return 0
    if [ "$AUR_HELPER" = "yay" ]; then
        yay -S --needed --diffmenu=false --cleanmenu=false --redownload=false --noconfirm "${pkgs[@]}" || true
    elif [ "$AUR_HELPER" = "paru" ]; then
        paru -S --needed --fm=false --ch=false --noconfirm "${pkgs[@]}" || true
    else
        sudo -H pacman -S --needed --noconfirm "${pkgs[@]}" || true
    fi
}

probe_hardware_drivers() {
    log_info "Probing system hardware..."
    DRIVER_PKGS=()
    DETECTED_HARDWARE=()

    local lspci_out=""
    local lscpu_out=""
    local lsmod_out=""
    local virt_out=""
    
    command -v lspci &>/dev/null && lspci_out="$(lspci -nnk 2>/dev/null || true)"
    command -v lscpu &>/dev/null && lscpu_out="$(lscpu 2>/dev/null || true)"
    command -v lsmod &>/dev/null && lsmod_out="$(lsmod 2>/dev/null || true)"
    command -v systemd-detect-virt &>/dev/null && virt_out="$(systemd-detect-virt 2>/dev/null || true)"

    local is_multilib=false
    if grep -qE '^\s*\[multilib\]' /etc/pacman.conf 2>/dev/null; then
        is_multilib=true
    fi

    # 1. GPU Detection
    local gpu_lines
    gpu_lines="$(echo "$lspci_out" | grep -Ei "vga compatible controller|3d controller|display controller" || true)"

    HAS_NVIDIA=false
    if echo "$gpu_lines" | grep -qi "nvidia"; then
        HAS_NVIDIA=true
        DETECTED_HARDWARE+=("NVIDIA GPU")
        
        # Detect installed kernels for matching headers
        local installed_kernels
        installed_kernels="$(pacman -Qq 2>/dev/null | grep -E '^linux(-lts|-zen|-hardened|-cachyos|-cachyos-lts)?$' || true)"
        for k in $installed_kernels; do
            DRIVER_PKGS+=("${k}-headers")
        done
        DRIVER_PKGS+=(nvidia-dkms dkms nvidia-utils egl-wayland libva-nvidia-driver)
        if [ "$is_multilib" = true ]; then
            DRIVER_PKGS+=(lib32-nvidia-utils)
        fi
    fi

    if echo "$gpu_lines" | grep -qiE "amd|radeon|advanced micro devices"; then
        DETECTED_HARDWARE+=("AMD / Radeon GPU")
        DRIVER_PKGS+=(mesa vulkan-radeon)
        if [ "$is_multilib" = true ]; then
            DRIVER_PKGS+=(lib32-mesa lib32-vulkan-radeon)
        fi
    fi

    if echo "$gpu_lines" | grep -qi "intel"; then
        DETECTED_HARDWARE+=("Intel GPU")
        DRIVER_PKGS+=(mesa vulkan-intel intel-media-driver vpl-gpu-rt)
        if [ "$is_multilib" = true ]; then
            DRIVER_PKGS+=(lib32-mesa lib32-vulkan-intel)
        fi
    fi

    # Virtualization guest drivers
    if [[ -n "$virt_out" && "$virt_out" != "none" ]]; then
        DETECTED_HARDWARE+=("Virtualization Guest ($virt_out)")
        DRIVER_PKGS+=(mesa)
        if [[ "$virt_out" =~ (kvm|qemu) ]]; then
            DRIVER_PKGS+=(qemu-guest-agent)
        elif [[ "$virt_out" =~ (oracle|vbox) ]]; then
            DRIVER_PKGS+=(virtualbox-guest-utils)
        elif [[ "$virt_out" =~ vmware ]]; then
            DRIVER_PKGS+=(open-vm-tools xf86-video-vmware)
        fi
    fi

    # 2. CPU Microcode
    if echo "$lscpu_out" | grep -qi "GenuineIntel"; then
        DETECTED_HARDWARE+=("Intel CPU (Microcode)")
        DRIVER_PKGS+=(intel-ucode)
    elif echo "$lscpu_out" | grep -qi "AuthenticAMD"; then
        DETECTED_HARDWARE+=("AMD CPU (Microcode)")
        DRIVER_PKGS+=(amd-ucode)
    fi

    # 3. Audio Stack (Pipewire)
    DETECTED_HARDWARE+=("PipeWire Modern Audio Stack")
    DRIVER_PKGS+=(pipewire wireplumber pipewire-pulse pipewire-alsa pipewire-audio)
    if echo "$lspci_out" | grep -qi "sof-audio" || echo "$lsmod_out" | grep -qi "snd_sof"; then
        DETECTED_HARDWARE+=("Sound Open Firmware (SOF DSP)")
        DRIVER_PKGS+=(sof-firmware alsa-firmware alsa-ucm-conf)
    fi

    # 4. Bluetooth
    if echo "$lspci_out" | grep -qi "bluetooth" || (command -v lsusb &>/dev/null && lsusb | grep -qi "bluetooth") || (command -v rfkill &>/dev/null && rfkill list bluetooth | grep -q "bluetooth"); then
        DETECTED_HARDWARE+=("Bluetooth Controller")
        DRIVER_PKGS+=(bluez bluez-utils)
    fi

    # Deduplicate packages
    local unique=()
    for p in "${DRIVER_PKGS[@]}"; do
        if [[ ! " ${unique[*]:-} " =~ " ${p} " ]]; then
            unique+=("$p")
        fi
    done
    DRIVER_PKGS=("${unique[@]}")

    echo -e "       ${CLR_BOLD}Detected Hardware:${CLR_RESET}"
    for item in "${DETECTED_HARDWARE[@]}"; do
        echo -e "         • ${CLR_CYAN}${item}${CLR_RESET}"
    done
}

prompt_user_configuration() {
    section_header "Installer Configuration Wizard"
    echo -e " ${CLR_DIM}Configure all options upfront. Once verified, installation runs uninterrupted.${CLR_RESET}\n"

    # 1. Config Overwrite
    local existing_configs=()
    if [[ -d "${SCRIPT_DIR}/.config" ]]; then
        for item in "${SCRIPT_DIR}/.config"/*; do
            [ -e "$item" ] || continue
            local name
            name="$(basename "$item")"
            if [[ -d "${HOME}/.config/${name}" ]]; then
                existing_configs+=("~/.config/${name}")
            fi
        done
    elif [[ -d "${SCRIPT_DIR}/hypr" && -d "${HOME}/.config/hypr" ]]; then
        existing_configs+=("~/.config/hypr")
    fi

    if [ ${#existing_configs[@]} -gt 0 ]; then
        echo -e " ${CLR_YELLOW}[1/5] Existing configurations detected in ~/.config/:${CLR_RESET}"
        for c in "${existing_configs[@]}"; do
            echo -e "       • ${CLR_CYAN}${c}${CLR_RESET}"
        done
        if confirm "      Overwrite these configuration paths with installer defaults? (timestamped backup will be created)" "Y"; then
            CONF_OVERWRITE=true
        else
            CONF_OVERWRITE=false
        fi
    else
        CONF_OVERWRITE=true
    fi
    echo ""

    # 2. Hardware Drivers
    echo -e " ${CLR_BOLD}[2/5] Hardware Driver Auto-Detection:${CLR_RESET}"
    if confirm "      Automatically detect, install, and configure all hardware drivers (GPU, Audio, Bluetooth, CPU Microcode)?" "N"; then
        CONF_DRIVERS=true
        probe_hardware_drivers
    else
        CONF_DRIVERS=false
        log_info "Hardware driver auto-detection skipped."
    fi
    echo ""

    # 3. Login Method
    echo -e " ${CLR_BOLD}[3/5] Login & Session Management:${CLR_RESET}"
    echo -e "       ${CLR_GREEN}[1] Display Manager (Recommended)${CLR_RESET}"
    echo -e "       [2] Autologin TTY + Autostart Hyprland (systemd service)"
    echo -e "       [3] Manual (Console login, start Hyprland manually)"
    
    CONF_LOGIN_METHOD=1
    if [ "${NOCONFIRM:-false}" = false ]; then
        read -rp "      Enter choice [1-3] (default: 1): " user_choice
        CONF_LOGIN_METHOD="${user_choice:-1}"
    fi

    if [[ "$CONF_LOGIN_METHOD" == "1" ]]; then
        echo -e "\n       ${CLR_BOLD}Select Display Manager to install:${CLR_RESET}"
        echo -e "         ${CLR_GREEN}[1] SDDM (Recommended for Qt6/Quickshell/Wayland)${CLR_RESET}"
        echo -e "         [2] greetd + tuigreet (Lightweight Wayland greeter)"
        echo -e "         [3] GDM (GNOME Display Manager)"
        echo -e "         [4] Ly (Minimal TUI display manager)"
        if [ "${NOCONFIRM:-false}" = false ]; then
            read -rp "        Enter choice [1-4] (default: 1): " user_dm
            CONF_DM_CHOICE="${user_dm:-1}"
        fi
        case "$CONF_DM_CHOICE" in
            2) DM_PKGS=(greetd greetd-tuigreet) ;;
            3) DM_PKGS=(gdm) ;;
            4) DM_PKGS=(ly) ;;
            *) DM_PKGS=(sddm qt6-svg qt6-declarative) ;;
        esac
    fi
    echo ""

    # 4. Default Shell
    echo -e " ${CLR_BOLD}[4/5] Default Shell Selection:${CLR_RESET}"
    CONF_SET_FISH=false
    if [[ "$(basename "${SHELL:-bash}")" != "fish" ]]; then
        if confirm "      Set Fish as your default user shell?" "Y"; then
            CONF_SET_FISH=true
        fi
    else
        log_info "Fish is already your default shell."
    fi
    echo ""

    # 5. Post-installation session action
    echo -e " ${CLR_BOLD}[5/5] Post-Installation Action:${CLR_RESET}"
    CONF_SESSION_ACTION="none"
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || pgrep -x Hyprland &>/dev/null; then
        if confirm "      Hyprland is currently running. Reload Hyprland and restart Olvex Shell when finished?" "Y"; then
            CONF_SESSION_ACTION="reload"
        fi
    else
        if confirm "      Hyprland is not running. Launch Hyprland session when installation finishes?" "Y"; then
            CONF_SESSION_ACTION="launch"
        fi
    fi
    echo ""
}

check_package_conflicts() {
    section_header "Package Conflict & Compatibility Precheck"
    log_info "Analyzing package conflicts and provider compatibility..."

    local conflicts_found=false
    local installed_pkgs
    installed_pkgs="$(pacman -Qq 2>/dev/null || true)"

    # Check known conflicting packages
    if echo "$installed_pkgs" | grep -qx "ttf-material-symbols-variable-git"; then
        log_warn "Notice: Installed 'ttf-material-symbols-variable-git' provides and conflicts with 'ttf-material-symbols-variable'."
        log_info "Preserving existing 'ttf-material-symbols-variable-git'."
        ALL_MISSING_PKGS=("${ALL_MISSING_PKGS[@]/ttf-material-symbols-variable/}")
    fi

    # Check repository conflict metadata for each package in ALL_MISSING_PKGS
    local pkgs_to_check=("${ALL_MISSING_PKGS[@]}")
    for pkg in "${pkgs_to_check[@]}"; do
        [ -z "$pkg" ] && continue
        local pkg_info
        pkg_info="$(pacman -Si "$pkg" 2>/dev/null || true)"
        [ -z "$pkg_info" ] && continue

        local conflicts_line
        conflicts_line="$(echo "$pkg_info" | grep -E '^Conflicts With' | cut -d':' -f2- || true)"
        
        for c in $conflicts_line; do
            local clean_conflict
            clean_conflict="$(echo "$c" | sed -E 's/[<>=].*//g' | tr -d ' ')"
            [ -z "$clean_conflict" ] && continue
            [[ "$clean_conflict" =~ ^(None|none)$ ]] && continue
            [[ "$clean_conflict" == "$pkg" ]] && continue

            if echo "$installed_pkgs" | grep -qx "$clean_conflict"; then
                log_warn "Conflict detected: '$pkg' conflicts with installed '$clean_conflict'."
                conflicts_found=true
                if confirm "Allow installer to replace '$clean_conflict' with '$pkg'?" "Y"; then
                    log_info "Replacement confirmed for '$clean_conflict'."
                else
                    log_warn "Skipping '$pkg' to preserve existing '$clean_conflict'."
                    ALL_MISSING_PKGS=("${ALL_MISSING_PKGS[@]/$pkg/}")
                fi
            fi
        done
    done

    # Clean array
    local cleaned=()
    for p in "${ALL_MISSING_PKGS[@]}"; do
        [[ -n "$p" ]] && cleaned+=("$p")
    done
    ALL_MISSING_PKGS=("${cleaned[@]}")

    if [ "$conflicts_found" = false ]; then
        log_success "No unresolved package conflicts detected."
    fi
}

run_preflight_and_verification() {
    section_header "Pre-flight Verification & Dependency Resolution"

    check_environment
    optimize_mirrors_and_keyring
    select_and_ensure_aur_helper

    log_info "Resolving system package dependencies..."
    local base_pkgs=(
        base-devel cmake ninja git pkgconf gcc-libs glibc
        qt6-base qt6-declarative qt6-wayland qt6-shadertools qt6-5compat qt6-multimedia qt6-svg qt6-imageformats
        quickshell hyprland wl-clipboard cliphist app2unit
        libnotify upower bluez bluez-utils
        ddcutil brightnessctl libcava networkmanager lm_sensors fish aubio libpipewire pipewire wireplumber
        noto-fonts ttf-cascadia-code-nerd
        swappy libqalculate bash mpv ydotool grim slurp
        python-pillow python-pip python gpu-screen-recorder fprintd foot kitty
        util-linux pciutils fzf firefox rsync dconf
        thunar thunar-volman thunar-archive-plugin thunar-media-tags-plugin adw-gtk-theme xdg-desktop-portal-gtk
        tumbler ffmpegthumbnailer gvfs gvfs-mtp gvfs-gphoto2 gvfs-afc gvfs-smb polkit-gnome wtype
        gnome-keyring trash-cli gammastep geoclue
    )

    local all_required_pkgs=("${base_pkgs[@]}")
    if [ "$CONF_DRIVERS" = true ]; then
        all_required_pkgs+=("${DRIVER_PKGS[@]}")
    fi
    if [ "$CONF_LOGIN_METHOD" = "1" ]; then
        all_required_pkgs+=("${DM_PKGS[@]}")
    fi

    # Deduplicate required packages
    local deduped_pkgs=()
    for p in "${all_required_pkgs[@]}"; do
        if [[ ! " ${deduped_pkgs[*]:-} " =~ " ${p} " ]]; then
            deduped_pkgs+=("$p")
        fi
    done

    ALL_MISSING_PKGS=()
    for pkg in "${deduped_pkgs[@]}"; do
        if ! pacman -Qq "$pkg" &>/dev/null; then
            ALL_MISSING_PKGS+=("$pkg")
        fi
    done

    if ! pacman -Qq | grep -Eiq 'ttf-material-symbols|material-symbols|ttf-google-material-design-icons'; then
        if [[ ! " ${ALL_MISSING_PKGS[*]:-} " =~ " ttf-material-symbols-variable " ]]; then
            ALL_MISSING_PKGS+=("ttf-material-symbols-variable")
        fi
    fi

    # Check conflicts interactively before proceeding
    check_package_conflicts

    section_header "Installation Plan Summary"
    echo -e " ${CLR_BOLD}The installer will execute the following plan:${CLR_RESET}"
    if [ "$CONF_OVERWRITE" = true ]; then
        echo -e "   • Configuration Deployment : ${CLR_GREEN}Deploy defaults (auto-backup existing)${CLR_RESET}"
    else
        echo -e "   • Configuration Deployment : ${CLR_YELLOW}Preserve existing configurations${CLR_RESET}"
    fi

    if [ "$CONF_DRIVERS" = true ]; then
        echo -e "   • Hardware Drivers         : ${CLR_GREEN}Enabled (${#DETECTED_HARDWARE[@]} components detected)${CLR_RESET}"
        for d in "${DETECTED_HARDWARE[@]}"; do
            echo -e "       - ${CLR_CYAN}${d}${CLR_RESET}"
        done
    else
        echo -e "   • Hardware Drivers         : ${CLR_YELLOW}Skipped${CLR_RESET}"
    fi

    case "$CONF_LOGIN_METHOD" in
        1)
            local dm_name="SDDM"
            [[ "$CONF_DM_CHOICE" == "2" ]] && dm_name="greetd + tuigreet"
            [[ "$CONF_DM_CHOICE" == "3" ]] && dm_name="GDM"
            [[ "$CONF_DM_CHOICE" == "4" ]] && dm_name="Ly"
            echo -e "   • Login Method             : ${CLR_GREEN}Display Manager (${dm_name})${CLR_RESET}"
            ;;
        2)
            echo -e "   • Login Method             : ${CLR_GREEN}Autologin TTY1 + Hyprland User Service (linger)${CLR_RESET}"
            ;;
        3)
            echo -e "   • Login Method             : ${CLR_YELLOW}Manual console login${CLR_RESET}"
            ;;
    esac

    if [ "$CONF_SET_FISH" = true ]; then
        echo -e "   • Default Shell            : ${CLR_GREEN}Change to Fish (/usr/bin/fish)${CLR_RESET}"
    else
        echo -e "   • Default Shell            : ${CLR_YELLOW}Keep current ($(basename "${SHELL:-bash}"))${CLR_RESET}"
    fi

    case "$CONF_SESSION_ACTION" in
        reload) echo -e "   • Post-Install Action      : ${CLR_GREEN}Reload Hyprland & Restart Olvex Shell${CLR_RESET}" ;;
        launch) echo -e "   • Post-Install Action      : ${CLR_GREEN}Launch Hyprland session (start-hyprland)${CLR_RESET}" ;;
        *) echo -e "   • Post-Install Action      : ${CLR_YELLOW}None (display summary and manual commands)${CLR_RESET}" ;;
    esac

    echo -e "   • Missing Packages         : ${CLR_BOLD}${#ALL_MISSING_PKGS[@]} package(s) to install${CLR_RESET}"
    if [ ${#ALL_MISSING_PKGS[@]} -gt 0 ]; then
        echo -e "     ${CLR_DIM}${ALL_MISSING_PKGS[*]}${CLR_RESET}"
    fi
    echo ""

    if ! confirm "Proceed with installation and apply all changes?" "Y"; then
        log_warn "Installation cancelled by user. No changes were written."
        exit 0
    fi
}

deploy_system_configurations() {
    section_header "Deploying System Configurations"

    if [ "$CONF_OVERWRITE" = true ]; then
        if [[ -d "${SCRIPT_DIR}/.config" ]]; then
            for item in "${SCRIPT_DIR}/.config"/*; do
                [ -e "$item" ] || continue
                local folder_name
                folder_name="$(basename "$item")"
                local existing_target="${HOME}/.config/${folder_name}"
                if [[ -d "$existing_target" ]]; then
                    local backup_dir="${existing_target}_backup_$(date +%Y%m%d_%H%M%S)"
                    log_info "Creating timestamped backup of existing ~/.config/${folder_name} -> ${backup_dir}"
                    cp -r "$existing_target" "$backup_dir"
                fi
            done

            log_info "Deploying configuration tree to ${HOME}/..."
            if command -v rsync &>/dev/null; then
                rsync -a --exclude='.git' "${SCRIPT_DIR}/.config/" "${HOME}/.config/"
            else
                cp -r "${SCRIPT_DIR}/.config"/* "${HOME}/.config/"
            fi
            log_success "Configuration tree deployed to ${HOME}/."
        elif [[ -d "${SCRIPT_DIR}/hypr" ]]; then
            if [[ -d "${TARGET_HYPR}" ]]; then
                local backup_dir="${TARGET_HYPR}_backup_$(date +%Y%m%d_%H%M%S)"
                log_info "Creating timestamped backup of existing ~/.config/hypr -> ${backup_dir}"
                cp -r "${TARGET_HYPR}" "$backup_dir"
            fi
            log_info "Deploying Hyprland configuration to ${TARGET_HYPR}..."
            cp -r "${SCRIPT_DIR}/hypr" "${HOME}/.config/"
            log_success "Hyprland configuration deployed."
        fi
    else
        log_info "Preserving existing configurations in ~/.config/ as requested."
    fi

    log_info "Deploying Olvex shell core to ${TARGET_LOCAL}..."
    rm -rf "$TARGET_LOCAL"
    if command -v rsync &>/dev/null; then
        rsync -a --delete --exclude='build' --exclude='.git' "${SCRIPT_DIR}/Olvex/" "${TARGET_LOCAL}/"
    else
        cp -r "${SCRIPT_DIR}/Olvex" "$TARGET_LOCAL"
        rm -rf "${TARGET_LOCAL}/build"
    fi
    log_success "Olvex shell core deployed."
}

build_and_setup_olvex() {
    section_header "Compiling C++ Plugins & System Integration"
    
    local build_dir="${TARGET_LOCAL}/build"
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    mkdir -p "$TARGET_QSCONF"
    mkdir -p "$TARGET_BIN"
    mkdir -p "${HOME}/.config/olvex/monitors"
    touch -a "${HOME}/.config/olvex/hypr-vars.conf" "${HOME}/.config/olvex/hypr-user.conf"

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
    sudo -H cmake --install .

    log_info "Restoring user ownership on shell configs..."
    sudo chown -R "$USER:$USER" "$TARGET_QSCONF" "${TARGET_LOCAL}" "${HOME}/.config/olvex" 2>/dev/null || true

    log_info "Registering olvex CLI executable..."
    local standalone_olvex="${TARGET_LOCAL}/scripts/olvex"
    chmod +x "$standalone_olvex" "${TARGET_LOCAL}/scripts/olvex-backend.sh" "${TARGET_LOCAL}/scripts/olvex-backend.py" 2>/dev/null || true
    
    mkdir -p "${TARGET_BIN}"
    ln -sfn "${standalone_olvex}" "${TARGET_BIN}/olvex"
    sudo mkdir -p "/usr/local/bin" 2>/dev/null || true
    sudo ln -sfn "${standalone_olvex}" "/usr/local/bin/olvex" 2>/dev/null || true
    log_success "CLI linked (${TARGET_BIN}/olvex & /usr/local/bin/olvex)."

    log_info "Configuring ydotool virtual input & uinput permissions..."
    if ! getent group input >/dev/null 2>&1; then
        sudo groupadd input 2>/dev/null || true
    fi
    sudo usermod -aG input "$USER" 2>/dev/null || true

    sudo tee /etc/udev/rules.d/80-uinput.rules >/dev/null <<'EOF'
KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
EOF
    sudo udevadm control --reload-rules 2>/dev/null || true
    sudo udevadm trigger 2>/dev/null || true

    log_info "Enabling ydotool user service..."
    local ydotool_svc="ydotoold.service"
    if ! systemctl --user list-unit-files 2>/dev/null | grep -q "^ydotoold"; then
        ydotool_svc="ydotool.service"
    fi
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable "$ydotool_svc" 2>/dev/null || true
    systemctl --user reset-failed "$ydotool_svc" 2>/dev/null || true
    systemctl --user restart "$ydotool_svc" 2>/dev/null || true
    log_success "ydotool service configured."
}

apply_driver_configurations() {
    section_header "Applying Driver Configurations"

    if [ "${HAS_NVIDIA:-false}" = true ]; then
        log_info "Configuring NVIDIA kernel modesetting (/etc/modprobe.d/nvidia.conf)..."
        sudo mkdir -p /etc/modprobe.d
        sudo tee /etc/modprobe.d/nvidia.conf >/dev/null <<'EOF'
options nvidia_drm modeset=1
EOF
        if command -v dkms &>/dev/null; then
            log_info "Rebuilding DKMS modules for installed kernels..."
            sudo dkms autoinstall || true
        fi
        log_success "NVIDIA configuration completed."
    fi

    if pacman -Q bluez &>/dev/null; then
        log_info "Enabling bluetooth.service..."
        sudo systemctl enable bluetooth.service 2>/dev/null || true
    fi
}

apply_login_method() {
    section_header "Applying Login & Session Configuration"

    case "$CONF_LOGIN_METHOD" in
        1)
            apply_display_manager
            ;;
        2)
            apply_autologin_tty_service
            ;;
        3)
            log_info "Manual login mode: Disabling display managers and autologin overrides..."
            sudo systemctl disable sddm gdm lightdm ly greetd 2>/dev/null || true
            sudo rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf 2>/dev/null || true
            systemctl --user disable hyprland.service 2>/dev/null || true
            sudo systemctl daemon-reload 2>/dev/null || true
            log_success "Manual console login mode configured."
            ;;
    esac
}

apply_display_manager() {
    # Disable getty autologin and hyprland user service
    sudo rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf 2>/dev/null || true
    systemctl --user disable hyprland.service 2>/dev/null || true
    sudo systemctl daemon-reload 2>/dev/null || true

    # Disable all other DMs
    sudo systemctl disable sddm gdm lightdm ly greetd 2>/dev/null || true

    case "$CONF_DM_CHOICE" in
        1)
            log_info "Configuring SDDM for Wayland..."
            sudo mkdir -p /etc/sddm.conf.d
            sudo tee /etc/sddm.conf.d/10-wayland.conf >/dev/null <<'EOF'
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell
EOF
            sudo systemctl enable sddm.service 2>/dev/null || true
            log_success "SDDM enabled with Wayland greeter support."
            ;;
        2)
            log_info "Configuring greetd with tuigreet..."
            sudo mkdir -p /etc/greetd
            sudo tee /etc/greetd/config.toml >/dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --cmd 'start-hyprland || Hyprland'"
user = "_greetd"
EOF
            sudo systemctl enable greetd.service 2>/dev/null || true
            log_success "greetd (tuigreet) enabled."
            ;;
        3)
            sudo systemctl enable gdm.service 2>/dev/null || true
            log_success "GDM enabled."
            ;;
        4)
            sudo systemctl enable ly.service 2>/dev/null || true
            log_success "Ly enabled."
            ;;
    esac
}

apply_autologin_tty_service() {
    # Step 1: Enable linger for user
    log_info "Enabling systemd lingering for user '$USER'..."
    sudo loginctl enable-linger "$USER" 2>/dev/null || true
    log_success "Lingering enabled for $USER."

    # Disable graphical display managers
    log_info "Disabling graphical display managers..."
    sudo systemctl disable sddm gdm lightdm ly greetd 2>/dev/null || true

    # Step 2: Configure getty@tty1 autologin service drop-in
    log_info "Configuring getty@tty1 autologin service..."
    local dropin_dir="/etc/systemd/system/getty@tty1.service.d"
    sudo mkdir -p "$dropin_dir"
    sudo tee "$dropin_dir/autologin.conf" >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ${USER} --noclear %I \$TERM
EOF
    sudo systemctl daemon-reload 2>/dev/null || true
    sudo systemctl enable getty@tty1.service 2>/dev/null || true
    log_success "getty@tty1 autologin configured."

    # Step 3: Configure Hyprland systemd service
    log_info "Deploying Hyprland systemd user service..."
    local user_systemd_dir="${HOME}/.config/systemd/user"
    mkdir -p "$user_systemd_dir"

    cat > "${user_systemd_dir}/hyprland.service" <<EOF
[Unit]
Description=Hyprland Wayland Compositor Session
Documentation=https://wiki.hyprland.org
After=graphical-session-pre.target
BindsTo=graphical-session.target
Wants=graphical-session-pre.target

[Service]
Type=simple
ExecStart=/usr/bin/start-hyprland
Restart=on-failure
RestartSec=1
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable hyprland.service 2>/dev/null || true

    # Inject tty1 trigger into shell profile to attach display/seat on login
    local trigger_bash='
# Autostart Hyprland service on tty1
if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ] && [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ] && [ "$(tty)" = "/dev/tty1" ]; then
    if ! pgrep -x Hyprland >/dev/null && ! systemctl --user is-active --quiet hyprland.service; then
        systemctl --user start hyprland.service
    fi
fi
'
    local trigger_fish='
# Autostart Hyprland service on tty1
if status is-login
    if test -z "$DISPLAY" -a -z "$WAYLAND_DISPLAY" -a -z "$HYPRLAND_INSTANCE_SIGNATURE" -a (tty) = "/dev/tty1"
        if not pgrep -x Hyprland >/dev/null; and not systemctl --user is-active --quiet hyprland.service
            systemctl --user start hyprland.service
        end
    end
end
'

    # Clean old trigger and inject updated guard in bash profile
    if [[ -f "${HOME}/.bash_profile" ]]; then
        sed -i '/# Autostart Hyprland/,/fi/d' "${HOME}/.bash_profile" 2>/dev/null || true
    fi
    echo "$trigger_bash" >> "${HOME}/.bash_profile"

    # Clean old trigger and inject updated guard in fish profile
    if command -v fish &>/dev/null; then
        mkdir -p "${HOME}/.config/fish"
        if [[ -f "${HOME}/.config/fish/config.fish" ]]; then
            python3 -c '
from pathlib import Path
import os, re
p = Path(os.path.expanduser("~/.config/fish/config.fish"))
if p.exists():
    t = p.read_text()
    t = re.sub(r"# Autostart Hyprland.*?end\s*\nend", "", t, flags=re.DOTALL)
    p.write_text(t.rstrip() + "\n")
' 2>/dev/null || true
        fi
        echo "$trigger_fish" >> "${HOME}/.config/fish/config.fish"
    fi

    log_success "Hyprland service & autologin configured."
}

bootstrap_scheme_and_themes() {
    section_header "Bootstrapping M3 Schemes & Themes"
    
    log_info "Generating initial Olvex Material 3 scheme..."
    if command -v olvex &>/dev/null; then
        olvex scheme set -n default 2>/dev/null || true
        log_success "M3 Scheme generated successfully."
    else
        log_warn "Olvex CLI not found in path, skipping scheme generation."
    fi

    if command -v dconf &>/dev/null; then
        log_info "Applying GTK Dark Mode preferences..."
        dconf write /org/gnome/desktop/interface/gtk-theme "'adw-gtk3-dark'" 2>/dev/null || true
        dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'" 2>/dev/null || true
        log_success "GTK preferences applied."
    fi

    # Check if bashrc needs syncing
    if [[ -f "${HOME}/.config/bash/bashrc" ]]; then
        if ! grep -q "source ~/.config/bash/bashrc" "${HOME}/.bashrc" 2>/dev/null; then
            echo -e "\n# Olvex Shell integration\n[ -f ~/.config/bash/bashrc ] && source ~/.config/bash/bashrc" >> "${HOME}/.bashrc"
        fi
    fi
}

universal_permission_sweep() {
    section_header "Universal Root Ownership Sweep"
    log_info "Sweeping ${HOME} for root-polluted files and restoring user ownership..."
    
    # Finds any file/directory inside HOME owned by root and safely chowns it to the user.
    sudo chown -R "$USER:$USER" "${HOME}/.config" "${HOME}/.local" 2>/dev/null || true
    sudo find "${HOME}" -maxdepth 4 -user root -exec chown "$USER:$USER" {} + 2>/dev/null || true
    
    log_success "Permissions restored successfully."
}

apply_post_install_actions() {
    section_header "Post-Installation Tasks"

    # Shell prompt
    if [ "$CONF_SET_FISH" = true ] && command -v fish &>/dev/null; then
        if [[ "$(basename "${SHELL:-bash}")" != "fish" ]]; then
            log_info "Changing default shell to fish..."
            sudo chsh -s "$(which fish)" "$USER" || log_warn "Failed to change shell. You may need to do it manually."
        fi
    fi

    if [[ "$CONF_SESSION_ACTION" == "reload" ]]; then
        log_info "Reloading Hyprland compositor..."
        hyprctl reload 2>/dev/null || true

        log_info "Restarting Olvex Shell daemon..."
        "${TARGET_LOCAL}/scripts/olvex" shell restart 2>/dev/null || "${TARGET_LOCAL}/scripts/olvex" shell -d 2>/dev/null || true
    elif [[ "$CONF_SESSION_ACTION" == "launch" ]]; then
        log_info "Initializing Hyprland environment..."
        if command -v start-hyprland &>/dev/null; then
            log_info "Executing start-hyprland..."
            exec start-hyprland
        elif command -v uwsm &>/dev/null; then
            log_info "Executing uwsm start hyprland-session.desktop..."
            exec uwsm start hyprland-session.desktop 2>/dev/null || exec Hyprland
        elif command -v Hyprland &>/dev/null; then
            log_info "Executing Hyprland..."
            exec Hyprland
        else
            log_warn "Hyprland executable not found in PATH."
        fi
    fi
}

display_final_summary() {
    section_header "Installation Summary"
    
    echo -e " ${CLR_GREEN}${CLR_BOLD}Olvex Shell and Hyprland environment deployed successfully.${CLR_RESET}\n"
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
    echo -e "   • Reload Hyprland : ${CLR_YELLOW}hyprctl reload${CLR_RESET}"
    echo -e "   • Launch Hyprland : ${CLR_YELLOW}start-hyprland${CLR_RESET}\n"
}

execute_all_changes() {
    cd "${HOME}" || true

    # 1. Install missing packages with zero interruptions
    if [ ${#ALL_MISSING_PKGS[@]} -gt 0 ]; then
        section_header "Installing Dependencies"
        log_info "Invoking ${AUR_HELPER}..."
        install_pkgs "${ALL_MISSING_PKGS[@]}"
        log_success "Dependencies successfully installed."
    fi

    # 2. Deploy system configurations
    deploy_system_configurations

    # 3. Build & Setup Olvex
    build_and_setup_olvex

    # 4. Apply Driver Configurations
    if [ "$CONF_DRIVERS" = true ]; then
        apply_driver_configurations
    fi

    # 5. Apply Login Method
    apply_login_method

    # 6. Bootstrap Themes
    bootstrap_scheme_and_themes

    # 7. Sweep permissions
    universal_permission_sweep

    # 8. Post-installation actions
    apply_post_install_actions

    # 9. Final summary
    display_final_summary
}

build_and_install_mode() {
    local clean_build="${1:-false}"

    banner
    section_header "Olvex Development Build & Install"
    
    if [ "$(id -u)" -eq 0 ]; then
        log_error "This script must NOT be run as root (do not use sudo ./setup.sh)."
        log_error "Please run it as your normal user. The script will request sudo when needed."
        exit 1
    fi

    local source_dir="${SCRIPT_DIR}/Olvex"
    if [[ ! -d "$source_dir" ]]; then
        log_error "Missing required directory: $source_dir"
        exit 1
    fi

    local build_dir="${source_dir}/build"
    if [ "$clean_build" = true ]; then
        log_info "Performing clean rebuild (removing $build_dir)..."
        rm -rf "$build_dir"
    fi

    log_info "[1/4] Checking build dependencies..."
    local missing=()
    for cmd in cmake ninja git pkgconf gcc; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log_warn "Missing required toolchains: ${missing[*]}"
        log_info "Installing missing build tools via pacman..."
        sudo -H pacman -S --needed --noconfirm "${missing[@]}" || {
            log_error "Failed to install required tools. Please run: sudo pacman -S ${missing[*]}"
            exit 1
        }
    fi
    log_success "Build dependencies verified."

    log_info "[2/4] Configuring build..."
    mkdir -p "$build_dir"
    mkdir -p "$TARGET_QSCONF"
    mkdir -p "$TARGET_BIN"
    mkdir -p "${HOME}/.config/olvex/monitors"
    mkdir -p "${HOME}/Pictures/Wallpapers"
    touch -a "${HOME}/.config/olvex/hypr-vars.conf" "${HOME}/.config/olvex/hypr-user.conf"

    cd "$build_dir"
    cmake -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/ \
        -DINSTALL_QSCONFDIR="$TARGET_QSCONF" \
        -DVERSION="1.0.0" \
        -DGIT_REVISION="dev-build" \
        ..
    log_success "Build configured."

    log_info "[3/4] Compiling Olvex from source..."
    cmake --build . -j"$(nproc 2>/dev/null || echo 2)"
    log_success "Build complete."

    log_info "[4/4] Installing (requires sudo)..."
    sudo -H cmake --install .

    log_info "Restoring user permissions on config directories..."
    sudo chown -R "$USER:$USER" "$TARGET_QSCONF" "${HOME}/.config/olvex" 2>/dev/null || true
    log_success "Installation complete."

    log_info "Setting up CLI and ydotool integration..."
    local standalone_olvex="${source_dir}/scripts/olvex"
    chmod +x "$standalone_olvex" "${source_dir}/scripts/olvex-backend.sh" "${source_dir}/scripts/olvex-backend.py" 2>/dev/null || true

    mkdir -p "${TARGET_BIN}"
    ln -sfn "${standalone_olvex}" "${TARGET_BIN}/olvex"
    sudo mkdir -p "/usr/local/bin" 2>/dev/null || true
    sudo ln -sfn "${standalone_olvex}" "/usr/local/bin/olvex" 2>/dev/null || true

    # Ydotool setup
    if ! getent group input >/dev/null 2>&1; then
        sudo groupadd input 2>/dev/null || true
    fi
    sudo usermod -aG input "$USER" 2>/dev/null || true

    sudo tee /etc/udev/rules.d/80-uinput.rules >/dev/null <<'EOF'
KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
EOF
    sudo udevadm control --reload-rules 2>/dev/null || true
    sudo udevadm trigger 2>/dev/null || true

    local ydotool_svc="ydotoold.service"
    if ! systemctl --user list-unit-files 2>/dev/null | grep -q "^ydotoold"; then
        ydotool_svc="ydotool.service"
    fi
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable "$ydotool_svc" 2>/dev/null || true
    systemctl --user reset-failed "$ydotool_svc" 2>/dev/null || true
    systemctl --user restart "$ydotool_svc" 2>/dev/null || true

    echo -e "\n${CLR_GREEN}${CLR_BOLD}✅ Build & Installation complete!${CLR_RESET}\n"
    echo -e " ${CLR_BOLD}Management Commands:${CLR_RESET}"
    echo -e "   • Start Shell     : ${CLR_YELLOW}olvex shell -d${CLR_RESET}"
    echo -e "   • Restart Shell   : ${CLR_YELLOW}olvex shell restart${CLR_RESET}"
    echo -e "   • Quickshell CLI  : ${CLR_YELLOW}qs -c olvex${CLR_RESET}"
    echo -e "   • Rebuild Shell   : ${CLR_YELLOW}./setup.sh --build${CLR_RESET}\n"
}

show_help() {
    echo -e "Usage: $0 [OPTIONS]"
    echo ""
    echo -e "Modes:"
    echo -e "  (no args)             Full interactive deployment (questionnaire upfront, preflight verification, automated execution)"
    echo -e "  -b, --build, build    Fast build & install from source (embedded dev build workflow)"
    echo -e "  --rebuild             Clean build directory and recompile from source"
    echo ""
    echo -e "Options:"
    echo -e "  -y, --noconfirm       Run without interactive confirmation prompts (accept defaults)"
    echo -e "  -h, --help            Show this help dialog"
    echo ""
}

main() {
    local action="install"
    NOCONFIRM=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -b|--build|build)
                action="build"
                shift
                ;;
            --rebuild)
                action="rebuild"
                shift
                ;;
            -y|--noconfirm|--yes)
                NOCONFIRM=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ "$action" == "build" ]]; then
        build_and_install_mode false
        exit 0
    elif [[ "$action" == "rebuild" ]]; then
        build_and_install_mode true
        exit 0
    fi

    # 3-Phase Execution Architecture
    banner
    prompt_user_configuration
    run_preflight_and_verification
    execute_all_changes
}

main "$@"
