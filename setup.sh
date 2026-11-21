#!/usr/bin/env bash
# Olvex Shell & Hyprland Automated Environment Setup
# Universal V2 Architecture - Polished & Arch TTY Friendly

set -euo pipefail

# Standard POSIX ANSI Terminal Colors (100% Linux Console & TTY Safe)
CLR_CYAN='\033[0;36m'
CLR_BLUE='\033[0;34m'
CLR_GREEN='\033[0;32m'
CLR_YELLOW='\033[1;33m'
CLR_RED='\033[0;31m'
CLR_MAGENTA='\033[0;35m'
CLR_BOLD='\033[1m'
CLR_DIM='\033[2m'
CLR_RESET='\033[0m'

# Terminal Character Set & TTY Capability Detection
IS_TTY=false
if [ "${TERM:-}" = "linux" ] || [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] || [ ! -t 1 ]; then
    IS_TTY=true
fi

# Glyphs and Box-drawing tokens (Safe for pure Linux Console /dev/tty1 and GUI terminals)
if [ "$IS_TTY" = true ]; then
    GLYPH_INFO="[i]"
    GLYPH_OK="[+]"
    GLYPH_WARN="[!]"
    GLYPH_ERR="[x]"
    GLYPH_BULLET="*"
    GLYPH_ARROW=">"
    GLYPH_RADIO_ON="(*)"
    GLYPH_RADIO_OFF="( )"
    BOX_TL="+"
    BOX_TR="+"
    BOX_BL="+"
    BOX_BR="+"
    BOX_H="-"
    BOX_V="|"
    BOX_DIV="+"
else
    GLYPH_INFO="ℹ"
    GLYPH_OK="✔"
    GLYPH_WARN="▲"
    GLYPH_ERR="✖"
    GLYPH_BULLET="•"
    GLYPH_ARROW="❯"
    GLYPH_RADIO_ON="◉"
    GLYPH_RADIO_OFF="○"
    BOX_TL="╭"
    BOX_TR="╮"
    BOX_BL="╰"
    BOX_BR="╯"
    BOX_H="─"
    BOX_V="│"
    BOX_DIV="├"
fi

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
IGNORED_FAILED_PKGS=()
AUR_HELPER="pacman"
NOCONFIRM=false

banner() {
    local mode_label="${1:-Full System Deployment}"
    [ -t 1 ] && clear || true
    if [ "${TERM:-}" = "linux" ]; then
        echo ""
        printf "  ${CLR_CYAN}${CLR_BOLD}%-34s${CLR_RESET}   ${CLR_BOLD}O L V E X${CLR_RESET}  ·  Deployment Manager v2\n" ' ___  _     __   __ _____ __   __'
        printf "  ${CLR_CYAN}${CLR_BOLD}%-34s${CLR_RESET}   ${CLR_DIM}-----------------------------------------${CLR_RESET}\n" '/ _ \| |    \ \ / /| ____|\ \ / /'
        printf "  ${CLR_CYAN}${CLR_BOLD}%-34s${CLR_RESET}   %s\n" '| | | | |     \ V / |  _|   \ V /' 'Where Motion Feels Alive'
        printf "  ${CLR_CYAN}${CLR_BOLD}%-34s${CLR_RESET}   Stack   Quickshell | Qt6 | C++ | Shaders\n" '| |_| | |___   \ /  | |___  / . \'
        printf "  ${CLR_CYAN}${CLR_BOLD}%-34s${CLR_RESET}   ${CLR_DIM}Mode    %s${CLR_RESET}\n\n" ' \___/|_____|   V   |_____|/_/ \_\' "$mode_label"
    else
        echo ""
        echo -e "           \033[38;2;138;124;255m⣀⣀⣀⡀\033[0m   \033[38;2;255;176;136m⣀⣀⣀⡀\033[0m"
        echo -e "          \033[38;2;131;116;253m⣾⣿⣿⣿⡟\033[0m  \033[38;2;255;167;125m⠘⣿⣿⣿⣿⡆\033[0m            \033[1;38;2;247;224;227mO L V E X\033[0m  \033[38;2;187;166;169m·  Deployment Manager v2\033[0m"
        echo -e "         \033[38;2;124;109;252m⣼⣿⣿⣿⡟\033[0m    \033[38;2;255;159;114m⠘⣿⣿⣿⣿⡄\033[0m           \033[38;2;138;124;255m─────────\033[38;2;255;151;103m─────────\033[38;2;119;204;248m───────────────────────\033[0m"
        echo -e "        \033[38;2;118;101;251m⣼⣿⣿⣿⡟\033[0m      \033[38;2;255;151;103m⠘⣿⣿⣿⣿⡄\033[0m          \033[38;2;255;176;136mWhere Motion Feels Alive\033[0m"
        echo -e "       \033[38;2;111;94;250m⣼⣿⣿⣿⡿\033[0m        \033[38;2;255;143;93m⠸⣿⣿⣿⣿⡄\033[0m"
        echo -e "      \033[38;2;104;87;248m⣼⣿⣿⣿⡿⠁\033[0m         \033[38;2;255;134;82m⠹⣿⣿⣿⣿⡄\033[0m        \033[38;2;187;166;169mStack\033[0m   \033[38;2;138;124;255mQuickshell\033[0m · \033[38;2;255;151;103mQt6\033[0m · \033[38;2;119;204;248mC++ & Shaders\033[0m"
        echo -e "     \033[38;2;98;79;247m⣼⣿⣿⣿⡿⠁\033[0m           \033[38;2;255;126;71m⠹⣿⣿⣿⣿⡄\033[0m       \033[38;2;187;166;169mTarget\033[0m  \033[38;2;247;224;227m~/.local/Olvex\033[0m · \033[38;2;247;224;227m~/.config/hypr\033[0m"
        echo -e "     \033[38;2;128;199;246m⣛\033[0m\033[38;2;131;197;245m⣻\033[0m\033[38;2;134;195;244m⣿\033[0m\033[38;2;137;193;243m⡛\033[0m\033[38;2;91;72;246m⠁\033[0m       \033[38;2;164;177;236m⢀\033[0m\033[38;2;167;175;236m⣀\033[0m\033[38;2;170;173;235m⣀\033[0m\033[38;2;173;171;234m⣀\033[0m  \033[38;2;255;118;60m⠙⠻⠿⠛⠃\033[0m       \033[38;2;187;166;169mMode\033[0m    \033[38;2;247;224;227m${mode_label}\033[0m"
        echo -e "  \033[38;2;119;204;248m⠤\033[0m\033[38;2;122;202;247m⠒\033[0m\033[38;2;125;200;247m⠉\033[0m\033[38;2;128;199;246m⠁\033[0m  \033[38;2;137;193;243m⠉\033[0m\033[38;2;140;191;243m⠓\033[0m\033[38;2;143;190;242m⠦\033[0m\033[38;2;146;188;241m⢄\033[0m\033[38;2;149;186;240m⣀\033[0m\033[38;2;152;184;239m⣀\033[0m\033[38;2;155;182;239m⣠\033[0m\033[38;2;158;180;238m⠴\033[0m\033[38;2;161;179;237m⠚\033[0m\033[38;2;164;177;236m⠉\033[0m   \033[38;2;176;170;233m⠉\033[0m\033[38;2;179;168;232m⠓\033[0m\033[38;2;182;166;232m⠦\033[0m\033[38;2;185;164;231m⣄\033[0m\033[38;2;188;162;230m⣀\033[0m\033[38;2;191;160;229m⣀\033[0m\033[38;2;194;159;228m⡤\033[0m\033[38;2;197;157;228m⠔\033[0m\033[38;2;200;155;227m⠊\033[0m\033[38;2;203;153;226m⠁\033[0m\n"
    fi
}

repeat_str() {
    local char="$1"
    local count="${2:-0}"
    [ "$count" -le 0 ] && return 0
    local pattern
    pattern="$(printf "%${count}s" "")"
    echo -n "${pattern// /$char}"
}

section_header() {
    local title="$1"
    local step_tag="${2:-}"
    local width=72
    local label="$title"
    if [ -n "$step_tag" ]; then
        label="${step_tag} ${title}"
    fi
    local label_len=${#label}
    local fill_len=$((width - label_len - 9))
    [ $fill_len -lt 4 ] && fill_len=4
    local fill_line
    fill_line="$(repeat_str "${BOX_H}" "$fill_len")"
    local prefix_line
    prefix_line="$(repeat_str "${BOX_H}" 3)"

    echo -e "\n${CLR_CYAN}${CLR_BOLD}${prefix_line} [ ${label} ] ${fill_line}${CLR_RESET}"
}

print_wrapped_list() {
    local indent="${1:-    }"
    local max_width="${2:-70}"
    shift 2
    local line="" item
    for item in "$@"; do
        if [ -z "$line" ]; then
            line="${indent}${item}"
        elif [ $((${#line} + 1 + ${#item})) -le "$max_width" ]; then
            line="${line} ${item}"
        else
            echo -e "${CLR_DIM}${line}${CLR_RESET}"
            line="${indent}${item}"
        fi
    done
    if [ -n "$line" ]; then
        echo -e "${CLR_DIM}${line}${CLR_RESET}"
    fi
}

log_info() { echo -e " ${CLR_BLUE}${GLYPH_INFO}${CLR_RESET} $1"; }
log_success() { echo -e " ${CLR_GREEN}${GLYPH_OK}${CLR_RESET} $1"; }
log_warn() { echo -e " ${CLR_YELLOW}${GLYPH_WARN}${CLR_RESET} $1"; }
log_error() { echo -e " ${CLR_RED}${GLYPH_ERR}${CLR_RESET} $1"; }

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
    echo -ne " ${CLR_BOLD}${prompt}${CLR_RESET} [${CLR_CYAN}${hint}${CLR_RESET}]: "
    read -rp "" resp
    resp="${resp:-$default}"
    [[ "$resp" =~ ^[Yy]$ ]]
}

select_menu() {
    local prompt="$1"
    local default_idx="${2:-0}"
    shift 2
    local options=("$@")
    local count=${#options[@]}
    local selected=$default_idx

    # If non-interactive or noconfirm, return default immediately
    if [ "${NOCONFIRM:-false}" = true ] || [ ! -t 0 ]; then
        echo "$((selected + 1))"
        return 0
    fi

    # Output interactive menu to stderr so stdout only captures the return index
    local out_fd=2

    echo -e " ${CLR_BOLD}${prompt}${CLR_RESET} ${CLR_DIM}(↑/↓ or 1-${count}, Enter to confirm)${CLR_RESET}" >&$out_fd

    render_options() {
        for ((i=0; i<count; i++)); do
            local opt_num=$((i + 1))
            if [ $i -eq $selected ]; then
                echo -e "   ${CLR_CYAN}${CLR_BOLD}${GLYPH_ARROW} ${GLYPH_RADIO_ON} [${opt_num}] ${options[$i]}${CLR_RESET}\033[K" >&$out_fd
            else
                echo -e "     ${CLR_DIM}${GLYPH_RADIO_OFF} [${opt_num}] ${options[$i]}${CLR_RESET}\033[K" >&$out_fd
            fi
        done
    }

    # Hide cursor
    echo -ne "\033[?25l" >&$out_fd
    trap 'echo -ne "\033[?25h" >&2; exit 130' INT TERM

    render_options

    while true; do
        local key=""
        local key2=""
        IFS= read -rsn1 key < /dev/tty || true
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key2 < /dev/tty || true
            key="$key$key2"
        fi

        case "$key" in
            $'\x1b[A'|[kK]) # Up arrow or 'k'
                if [ $selected -gt 0 ]; then
                    ((selected--))
                else
                    selected=$((count - 1))
                fi
                echo -ne "\033[${count}A" >&$out_fd
                render_options
                ;;
            $'\x1b[B'|[jJ]) # Down arrow or 'j'
                if [ $selected -lt $((count - 1)) ]; then
                    ((selected++))
                else
                    selected=0
                fi
                echo -ne "\033[${count}A" >&$out_fd
                render_options
                ;;
            [1-9]) # Number shortcut
                local num=$((key - 1))
                if [ $num -ge 0 ] && [ $num -lt $count ]; then
                    selected=$num
                    echo -ne "\033[${count}A" >&$out_fd
                    render_options
                    break
                fi
                ;;
            "") # Enter key
                break
                ;;
        esac
    done

    # Restore cursor
    echo -ne "\033[?25h" >&$out_fd
    trap - INT TERM

    echo "$((selected + 1))"
}

check_environment() {
    if [ "$(id -u)" -eq 0 ]; then
        log_error "Do not run this script as root (avoid sudo ./setup.sh)."
        log_error "Run as your regular user; privilege escalation is requested only when needed."
        exit 1
    fi

    log_info "Preparing XDG user directories (~/.config, ~/.cache, ~/.local)..."
    mkdir -p "${HOME}/.config" "${HOME}/.cache" "${HOME}/.local/share" "${HOME}/.local/state" "${HOME}/.local/bin" "${HOME}/Pictures/Wallpapers"

    log_info "Verifying deployment bundle integrity..."
    if [[ ! -d "${SCRIPT_DIR}/Olvex" ]]; then
        log_error "Missing required directory: ${SCRIPT_DIR}/Olvex"
        exit 1
    fi

    if [[ ! -d "${SCRIPT_DIR}/.config" ]] && [[ ! -d "${SCRIPT_DIR}/hypr" ]]; then
        log_error "Missing required configuration directory in ${SCRIPT_DIR}"
        exit 1
    fi

    log_success "Environment and deployment bundle verified."
}

optimize_mirrors_and_keyring() {
    section_header "Repository & Keyring Initialization"
    
    log_info "Verifying Pacman GPG keyring..."
    if ! sudo pacman-key --list-keys &>/dev/null; then
        log_warn "Initializing local Pacman GPG keyring..."
        sudo pacman-key --init || true
        sudo pacman-key --populate archlinux || true
    fi

    log_info "Ensuring archlinux-keyring is up to date..."
    sudo -H pacman -Sy --needed --noconfirm archlinux-keyring || true

    log_info "Synchronizing package databases..."
    sudo -H pacman -Sy --noconfirm || true
    log_success "Package databases synchronized."
}

select_and_ensure_aur_helper() {
    section_header "AUR Helper Setup"

    if command -v yay &>/dev/null; then
        log_success "Detected AUR helper: yay"
        AUR_HELPER="yay"
        return 0
    elif command -v paru &>/dev/null; then
        log_success "Detected AUR helper: paru"
        AUR_HELPER="paru"
        return 0
    fi

    log_warn "No supported AUR helper (yay or paru) detected."
    local aur_choice
    aur_choice="$(select_menu "Select an AUR helper to install:" 0 \
        "yay-bin  (Precompiled binary — Recommended)" \
        "paru-bin (Rust-based AUR helper)")"

    log_info "Installing base build toolchain (base-devel, git, cmake, ninja)..."
    sudo -H pacman -S --needed --noconfirm base-devel git cmake ninja || true

    local tmp_dir
    tmp_dir="$(mktemp -d)"

    if [[ "$aur_choice" == "2" ]]; then
        log_info "Building and installing paru-bin..."
        git clone https://aur.archlinux.org/paru-bin.git "$tmp_dir/paru-bin"
        ( cd "$tmp_dir/paru-bin" && makepkg -si --noconfirm )
        AUR_HELPER="paru"
    else
        log_info "Building and installing yay-bin..."
        git clone https://aur.archlinux.org/yay-bin.git "$tmp_dir/yay-bin"
        ( cd "$tmp_dir/yay-bin" && makepkg -si --noconfirm )
        AUR_HELPER="yay"
    fi
    rm -rf "$tmp_dir"
    log_success "AUR helper ready: ${AUR_HELPER}"
}

install_pkgs() {
    local pkgs=("$@")
    [ ${#pkgs[@]} -eq 0 ] && return 0
    if [ "$AUR_HELPER" = "yay" ]; then
        yay -S --needed --diffmenu=false --cleanmenu=false --redownload=false --noconfirm "${pkgs[@]}"
    elif [ "$AUR_HELPER" = "paru" ]; then
        paru -S --needed --skipreview --nochroot --noconfirm "${pkgs[@]}"
    else
        sudo -H pacman -S --needed --noconfirm "${pkgs[@]}"
    fi
}

format_manual_install_cmd() {
    local pkgs=("$@")
    if [ "$AUR_HELPER" = "paru" ] || [ "$AUR_HELPER" = "yay" ]; then
        echo "${AUR_HELPER} -S --needed ${pkgs[*]}"
    else
        echo "sudo pacman -S --needed ${pkgs[*]}"
    fi
}

get_unsatisfied_pkgs() {
    local pkgs=("$@")
    [ ${#pkgs[@]} -eq 0 ] && return 0
    pacman -T "${pkgs[@]}" 2>/dev/null | sed '/^[[:space:]]*$/d' || true
}

install_pkgs_individually() {
    local pkgs=("$@")
    local pkg
    for pkg in "${pkgs[@]}"; do
        if ! pacman -T "$pkg" &>/dev/null; then
            log_info "Installing package individually: ${pkg}..."
            install_pkgs "$pkg" || log_warn "Failed to install '${pkg}'."
        fi
    done
}

remind_manual_ignored_pkgs() {
    [ ${#IGNORED_FAILED_PKGS[@]} -eq 0 ] && return 0
    local still_ignored=()
    mapfile -t still_ignored < <(get_unsatisfied_pkgs "${IGNORED_FAILED_PKGS[@]}")
    IGNORED_FAILED_PKGS=("${still_ignored[@]}")
    if [ ${#IGNORED_FAILED_PKGS[@]} -gt 0 ]; then
        echo ""
        log_warn "Build succeeded, but ${#IGNORED_FAILED_PKGS[@]} skipped package(s) are still not installed: ${IGNORED_FAILED_PKGS[*]}"
        log_info "For the best experience, install them manually:"
        echo -e "   ${CLR_YELLOW}$(format_manual_install_cmd "${IGNORED_FAILED_PKGS[@]}")${CLR_RESET}"
    fi
}

report_build_failure() {
    local stage="$1"
    echo ""
    log_error "${stage}."
    if [ ${#IGNORED_FAILED_PKGS[@]} -gt 0 ]; then
        local still_ignored=()
        mapfile -t still_ignored < <(get_unsatisfied_pkgs "${IGNORED_FAILED_PKGS[@]}")
        IGNORED_FAILED_PKGS=("${still_ignored[@]}")
        if [ ${#IGNORED_FAILED_PKGS[@]} -gt 0 ]; then
            log_error "Build failed after continuing without skipped package(s): ${IGNORED_FAILED_PKGS[*]}"
            log_error "One or more skipped package(s) appear required to build/install Olvex."
            log_info "Install them manually first:"
            echo -e "   ${CLR_YELLOW}$(format_manual_install_cmd "${IGNORED_FAILED_PKGS[@]}")${CLR_RESET}"
            log_info "Then re-run ${CLR_YELLOW}./setup.sh${CLR_RESET} (or ${CLR_YELLOW}./setup.sh --build${CLR_RESET})."
            return 0
        fi
    fi
    log_error "Review the CMake/compiler output above, install any missing dependencies, and re-run ./setup.sh."
}

install_missing_dependencies_step() {
    local remaining_pkgs=("${ALL_MISSING_PKGS[@]}")
    local skip_install=false
    IGNORED_FAILED_PKGS=()

    while true; do
        local install_rc=0
        if [ "$skip_install" = false ]; then
            if install_pkgs "${remaining_pkgs[@]}"; then
                install_rc=0
            else
                install_rc=$?
            fi
        fi
        skip_install=false

        local missing_arr=()
        mapfile -t missing_arr < <(get_unsatisfied_pkgs "${remaining_pkgs[@]}")

        if [ "$install_rc" -eq 0 ] && [ ${#missing_arr[@]} -eq 0 ]; then
            log_success "Dependencies successfully installed."
            return 0
        fi

        echo ""
        if [ ${#missing_arr[@]} -gt 0 ]; then
            if [ "$install_rc" -ne 0 ]; then
                log_error "Dependency installation via ${AUR_HELPER} failed (exit code: ${install_rc})."
            else
                log_error "Some dependencies failed to install via ${AUR_HELPER}."
            fi
            log_error "Failed / missing package(s) (${#missing_arr[@]}): ${missing_arr[*]}"
            log_info "You can install them manually with:"
            echo -e "   ${CLR_YELLOW}$(format_manual_install_cmd "${missing_arr[@]}")${CLR_RESET}\n"
        else
            log_error "${AUR_HELPER} exited with code ${install_rc}, though no requested packages appear missing."
        fi

        if [ "${NOCONFIRM:-false}" = true ] || [ ! -t 0 ]; then
            log_error "Non-interactive mode: aborting before configuration deployment and compilation."
            exit 1
        fi

        local choice
        local retry_choice="1"
        local one_by_one_choice=""
        local ignore_choice="2"

        if [ ${#missing_arr[@]} -gt 1 ]; then
            one_by_one_choice="2"
            ignore_choice="3"
            choice="$(select_menu "How would you like to proceed?" 0 \
                "Retry failed package(s) (or re-check if installed manually)" \
                "Install remaining one-by-one (install working packages & isolate failed ones)" \
                "Ignore failed package(s) & continue installation" \
                "Abort installation")"
        else
            choice="$(select_menu "How would you like to proceed?" 0 \
                "Retry failed package(s) (or re-check if installed manually)" \
                "Ignore failed package(s) & continue installation" \
                "Abort installation")"
        fi

        if [ "$choice" = "$retry_choice" ]; then
            if [ ${#missing_arr[@]} -gt 0 ]; then
                local recheck_arr=()
                mapfile -t recheck_arr < <(get_unsatisfied_pkgs "${missing_arr[@]}")
                if [ ${#recheck_arr[@]} -eq 0 ]; then
                    log_success "All previously failed package(s) are now installed."
                    log_success "Dependencies successfully installed."
                    return 0
                fi
                remaining_pkgs=("${recheck_arr[@]}")
            fi
            log_info "Retrying package installation (${#remaining_pkgs[@]} package(s))..."
        elif [ -n "$one_by_one_choice" ] && [ "$choice" = "$one_by_one_choice" ]; then
            install_pkgs_individually "${missing_arr[@]}"
            remaining_pkgs=("${missing_arr[@]}")
            skip_install=true
        elif [ "$choice" = "$ignore_choice" ]; then
            if [ ${#missing_arr[@]} -gt 0 ]; then
                IGNORED_FAILED_PKGS=("${missing_arr[@]}")
                log_warn "Ignoring ${#IGNORED_FAILED_PKGS[@]} failed package(s): ${IGNORED_FAILED_PKGS[*]}"
                log_info "Continuing installation. Please install them manually later:"
                echo -e "   ${CLR_YELLOW}$(format_manual_install_cmd "${IGNORED_FAILED_PKGS[@]}")${CLR_RESET}"
            else
                log_warn "Ignoring ${AUR_HELPER} error (exit code: ${install_rc}) and continuing..."
            fi
            return 0
        else
            log_error "Installation aborted. Resolve failed packages and re-run ./setup.sh."
            exit 1
        fi
    done
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
    DETECTED_HARDWARE+=("PipeWire Audio Stack")
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
        echo -e "         ${GLYPH_BULLET} ${CLR_CYAN}${item}${CLR_RESET}"
    done
}

prompt_user_configuration() {
    section_header "Configuration Wizard"
    echo -e " ${CLR_DIM}Select preferences upfront. Execution begins only after final review.${CLR_RESET}\n"

    # Check for existing configuration folders
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

    local step=1
    local total_steps=4
    if [ ${#existing_configs[@]} -gt 0 ]; then
        total_steps=5
    fi

    # 1. Config Overwrite (Only asked if existing configs are found)
    if [ ${#existing_configs[@]} -gt 0 ]; then
        echo -e " ${CLR_YELLOW}${CLR_BOLD}[${step}/${total_steps}] Existing User Configurations Detected${CLR_RESET}"
        for c in "${existing_configs[@]}"; do
            echo -e "   ${GLYPH_BULLET} ${CLR_CYAN}${c}${CLR_RESET}"
        done
        if confirm "  Backup and replace these configurations with Olvex defaults?" "Y"; then
            CONF_OVERWRITE=true
        else
            CONF_OVERWRITE=false
        fi
        echo ""
        ((step++))
    else
        CONF_OVERWRITE=true
    fi

    # 2. Hardware Drivers
    echo -e " ${CLR_BOLD}[${step}/${total_steps}] Hardware Drivers & Firmware${CLR_RESET}"
    if confirm "  Auto-detect and configure GPU, audio, Bluetooth, and CPU microcode drivers?" "N"; then
        CONF_DRIVERS=true
        probe_hardware_drivers
    else
        CONF_DRIVERS=false
        log_info "Hardware driver detection skipped."
    fi
    echo ""
    ((step++))

    # 3. Login Method
    local login_choice
    login_choice="$(select_menu "[${step}/${total_steps}] Display Manager & Session Login:" 0 \
        "Display Manager (Recommended)" \
        "TTY1 Autologin + Hyprland User Service (systemd)" \
        "Manual Console Login")"
    CONF_LOGIN_METHOD="$login_choice"

    if [[ "$CONF_LOGIN_METHOD" == "1" ]]; then
        local dm_choice
        dm_choice="$(select_menu "Select Display Manager:" 0 \
            "SDDM (Recommended for Qt6 / Wayland)" \
            "greetd + tuigreet (Lightweight Wayland greeter)" \
            "GDM (GNOME Display Manager)" \
            "Ly (Minimal TUI display manager)")"
        CONF_DM_CHOICE="$dm_choice"

        case "$CONF_DM_CHOICE" in
            2) DM_PKGS=(greetd greetd-tuigreet) ;;
            3) DM_PKGS=(gdm) ;;
            4) DM_PKGS=(ly) ;;
            *) DM_PKGS=(sddm qt6-svg qt6-declarative) ;;
        esac
    fi
    echo ""
    ((step++))

    # 4. Default Shell
    echo -e " ${CLR_BOLD}[${step}/${total_steps}] Default Login Shell${CLR_RESET}"
    CONF_SET_FISH=false
    if [[ "$(basename "${SHELL:-bash}")" != "fish" ]]; then
        if confirm "  Switch default login shell to Fish (/usr/bin/fish)?" "Y"; then
            CONF_SET_FISH=true
        fi
    else
        log_info "Fish is already set as your default login shell."
    fi
    echo ""
    ((step++))

    # 5. Post-installation session action
    echo -e " ${CLR_BOLD}[${step}/${total_steps}] Post-Install Session Action${CLR_RESET}"
    CONF_SESSION_ACTION="none"
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || pgrep -x Hyprland &>/dev/null; then
        if confirm "  Hyprland is active. Reload Hyprland and restart Olvex Shell upon completion?" "Y"; then
            CONF_SESSION_ACTION="reload"
        fi
    else
        if confirm "  Launch Hyprland automatically once deployment completes?" "Y"; then
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
    section_header "Preflight Verification & Dependency Check"

    check_environment
    optimize_mirrors_and_keyring
    select_and_ensure_aur_helper

    log_info "Resolving required system & runtime packages..."
    local base_pkgs=(
        base-devel cmake ninja git pkgconf gcc-libs glibc
        qt6-base qt6-declarative qt6-wayland qt6-shadertools qt6-5compat qt6-multimedia qt6-svg qt6-imageformats
        quickshell hyprland wl-clipboard cliphist app2unit
        libnotify upower bluez bluez-utils
        ddcutil brightnessctl libcava networkmanager lm_sensors fish aubio libpipewire pipewire wireplumber
        noto-fonts noto-fonts-emoji ttf-cascadia-code-nerd
        swappy libqalculate bash mpv ydotool grim slurp
        python-pillow python-pip python gpu-screen-recorder fprintd foot kitty
        util-linux pciutils fzf firefox rsync dconf
        thunar thunar-volman thunar-archive-plugin thunar-media-tags-plugin adw-gtk-theme xdg-desktop-portal-gtk
        tumbler ffmpegthumbnailer gvfs gvfs-mtp gvfs-gphoto2 gvfs-afc gvfs-smb polkit-gnome wtype
        gnome-keyring trash-cli gammastep geoclue
        fastfetch qps cloudflare-warp-bin
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

    if ! pacman -Qq | grep -Eiq '^bibata-cursor-theme' && \
       [ ! -d "/usr/share/icons/Bibata-Modern-Classic" ] && \
       [ ! -d "${HOME}/.local/share/icons/Bibata-Modern-Classic" ] && \
       [ ! -d "${HOME}/.icons/Bibata-Modern-Classic" ] && \
       [ ! -d "${HOME}/.cursors/Bibata-Modern-Classic" ]; then
        if [[ ! " ${ALL_MISSING_PKGS[*]:-} " =~ " bibata-cursor-theme-bin " ]]; then
            ALL_MISSING_PKGS+=("bibata-cursor-theme-bin")
        fi
    fi

    # Check conflicts interactively before proceeding
    check_package_conflicts

    section_header "Deployment Plan Summary"
    echo -e " ${CLR_DIM}Review the pending system changes before execution:${CLR_RESET}\n"
    if [ "$CONF_OVERWRITE" = true ]; then
        echo -e "   ${GLYPH_BULLET} Config Deployment  : ${CLR_GREEN}Deploy Olvex defaults (auto-backup existing)${CLR_RESET}"
    else
        echo -e "   ${GLYPH_BULLET} Config Deployment  : ${CLR_YELLOW}Preserve existing user configs${CLR_RESET}"
    fi

    if [ "$CONF_DRIVERS" = true ]; then
        echo -e "   ${GLYPH_BULLET} Hardware Drivers   : ${CLR_GREEN}Auto-configure (${#DETECTED_HARDWARE[@]} component(s))${CLR_RESET}"
        for d in "${DETECTED_HARDWARE[@]}"; do
            echo -e "       - ${CLR_CYAN}${d}${CLR_RESET}"
        done
    else
        echo -e "   ${GLYPH_BULLET} Hardware Drivers   : ${CLR_YELLOW}Skipped${CLR_RESET}"
    fi

    case "$CONF_LOGIN_METHOD" in
        1)
            local dm_name="SDDM"
            [[ "$CONF_DM_CHOICE" == "2" ]] && dm_name="greetd + tuigreet"
            [[ "$CONF_DM_CHOICE" == "3" ]] && dm_name="GDM"
            [[ "$CONF_DM_CHOICE" == "4" ]] && dm_name="Ly"
            echo -e "   ${GLYPH_BULLET} Login Session      : ${CLR_GREEN}Display Manager (${dm_name})${CLR_RESET}"
            ;;
        2)
            echo -e "   ${GLYPH_BULLET} Login Session      : ${CLR_GREEN}TTY1 Autologin + Hyprland User Service${CLR_RESET}"
            ;;
        3)
            echo -e "   ${GLYPH_BULLET} Login Session      : ${CLR_YELLOW}Manual console login${CLR_RESET}"
            ;;
    esac

    if [ "$CONF_SET_FISH" = true ]; then
        echo -e "   ${GLYPH_BULLET} Default Shell      : ${CLR_GREEN}Switch to Fish (/usr/bin/fish)${CLR_RESET}"
    else
        echo -e "   ${GLYPH_BULLET} Default Shell      : ${CLR_YELLOW}Keep $(basename "${SHELL:-bash}")${CLR_RESET}"
    fi

    case "$CONF_SESSION_ACTION" in
        reload) echo -e "   ${GLYPH_BULLET} Post-Install       : ${CLR_GREEN}Reload Hyprland & Restart Olvex Shell${CLR_RESET}" ;;
        launch) echo -e "   ${GLYPH_BULLET} Post-Install       : ${CLR_GREEN}Launch Hyprland session (start-hyprland)${CLR_RESET}" ;;
        *) echo -e "   ${GLYPH_BULLET} Post-Install       : ${CLR_YELLOW}None (print summary & CLI commands)${CLR_RESET}" ;;
    esac

    echo -e "   ${GLYPH_BULLET} AUR Helper         : ${CLR_CYAN}${AUR_HELPER}${CLR_RESET}"
    echo -e "   ${GLYPH_BULLET} Target Core        : ${CLR_CYAN}${TARGET_LOCAL}${CLR_RESET}"
    if [ ${#ALL_MISSING_PKGS[@]} -gt 0 ]; then
        echo -e "   ${GLYPH_BULLET} Packages           : ${CLR_BOLD}${#ALL_MISSING_PKGS[@]} missing package(s) queued${CLR_RESET}"
        print_wrapped_list "       " 70 "${ALL_MISSING_PKGS[@]}"
    else
        echo -e "   ${GLYPH_BULLET} Packages           : ${CLR_GREEN}All dependencies already satisfied${CLR_RESET}"
    fi
    echo ""

    if ! confirm "Proceed with deployment and apply these changes?" "Y"; then
        log_warn "Deployment cancelled by user. No changes were applied."
        exit 0
    fi
}

deploy_system_configurations() {
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
    if [ -d "${SCRIPT_DIR}/.git" ]; then
        cp -r "${SCRIPT_DIR}/.git" "${TARGET_LOCAL}/" 2>/dev/null || true
    fi
    log_success "Olvex shell core deployed."

    log_info "Deploying default wallpapers to ${HOME}/Pictures/Wallpapers..."
    mkdir -p "${HOME}/Pictures/Wallpapers"
    local wp_source=""
    if [[ -d "${SCRIPT_DIR}/Olvex/assets/Wallpapers" ]]; then
        wp_source="${SCRIPT_DIR}/Olvex/assets/Wallpapers"
    elif [[ -d "${TARGET_LOCAL}/assets/Wallpapers" ]]; then
        wp_source="${TARGET_LOCAL}/assets/Wallpapers"
    fi
    if [[ -n "$wp_source" ]]; then
        cp -r "${wp_source}"/* "${HOME}/Pictures/Wallpapers/" 2>/dev/null || true
        log_success "Default wallpapers deployed to ${HOME}/Pictures/Wallpapers."
    fi
}

save_install_configuration() {
    log_info "Writing system installation configuration to /etc/olvex/install.conf..."
    sudo mkdir -p /etc/olvex
    local current_commit="unknown"
    if [ -d "${TARGET_LOCAL}/.git" ]; then
        current_commit="$(git -C "${TARGET_LOCAL}" rev-parse HEAD 2>/dev/null || echo "unknown")"
    elif [ -d "${SCRIPT_DIR}/.git" ]; then
        current_commit="$(git -C "${SCRIPT_DIR}" rev-parse HEAD 2>/dev/null || echo "unknown")"
    fi

    sudo tee /etc/olvex/install.conf >/dev/null <<EOF
# Olvex System Installation State
REPO_URL="https://github.com/MHMNR/Olvex.git"
BRANCH="Main"
AUR_HELPER="${AUR_HELPER:-paru}"
LOGIN_METHOD="${CONF_LOGIN_METHOD:-1}"
DM_CHOICE="${CONF_DM_CHOICE:-1}"
DRIVERS="${CONF_DRIVERS:-false}"
SET_FISH="${CONF_SET_FISH:-false}"
INSTALLED_COMMIT="${current_commit}"
INSTALLED_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
EOF
    sudo chmod 644 /etc/olvex/install.conf
    log_success "System installation configuration saved (/etc/olvex/install.conf)."
}

run_cmake_pipeline() {
    local build_dir="$1"
    local jobs
    jobs="$(nproc 2>/dev/null || echo 2)"

    log_info "Configuring CMake build system (Ninja, Release)..."
    cd "$build_dir"

    if ! cmake -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/ \
        -DINSTALL_QSCONFDIR="$TARGET_QSCONF" \
        ..; then
        report_build_failure "CMake configuration failed"
        exit 1
    fi

    log_info "Building native C++ plugins and components (${jobs} parallel jobs)..."
    if ! cmake --build . -j"$jobs"; then
        report_build_failure "Native compilation failed"
        exit 1
    fi

    log_info "Installing compiled targets to system paths (sudo required)..."
    if ! sudo -H cmake --install .; then
        report_build_failure "CMake installation failed"
        exit 1
    fi
}

setup_cli_and_ydotool() {
    local source_root="$1"
    local build_dir="$2"

    log_info "Registering olvex CLI executables..."
    local standalone_olvex="${source_root}/scripts/olvex"
    chmod +x "$standalone_olvex" "${source_root}/scripts/olvex-backend.sh" "${source_root}/scripts/olvex-backend.py" 2>/dev/null || true

    mkdir -p "${TARGET_BIN}"
    ln -sfn "${standalone_olvex}" "${TARGET_BIN}/olvex"
    sudo mkdir -p "/usr/local/bin" 2>/dev/null || true
    sudo ln -sfn "${standalone_olvex}" "/usr/local/bin/olvex" 2>/dev/null || true

    if [ -f "${build_dir}/lib/olvex-clipboard" ]; then
        ln -sfn "${build_dir}/lib/olvex-clipboard" "${TARGET_BIN}/olvex-clipboard"
        sudo ln -sfn "${build_dir}/lib/olvex-clipboard" "/usr/local/bin/olvex-clipboard" 2>/dev/null || true
    fi
    log_success "CLI linked (${TARGET_BIN}/olvex -> /usr/local/bin/olvex)."

    log_info "Configuring virtual input permissions (uinput / ydotool)..."
    if ! getent group input >/dev/null 2>&1; then
        sudo groupadd input 2>/dev/null || true
    fi
    sudo usermod -aG input "$USER" 2>/dev/null || true

    sudo tee /etc/udev/rules.d/80-uinput.rules >/dev/null <<'EOF'
KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
EOF
    sudo udevadm control --reload-rules 2>/dev/null || true
    sudo udevadm trigger 2>/dev/null || true

    log_info "Enabling ydotool user daemon..."
    local ydotool_svc="ydotoold.service"
    if ! systemctl --user list-unit-files 2>/dev/null | grep -q "^ydotoold"; then
        ydotool_svc="ydotool.service"
    fi
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable "$ydotool_svc" 2>/dev/null || true
    systemctl --user reset-failed "$ydotool_svc" 2>/dev/null || true
    systemctl --user restart "$ydotool_svc" 2>/dev/null || true
    log_success "Input daemon (${ydotool_svc}) configured."
}

build_and_setup_olvex() {
    local build_dir="${TARGET_LOCAL}/build"
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    mkdir -p "$TARGET_QSCONF"
    mkdir -p "$TARGET_BIN"
    mkdir -p "${HOME}/.config/olvex/monitors"
    touch -a "${HOME}/.config/olvex/hypr-vars.conf" "${HOME}/.config/olvex/hypr-user.conf"

    run_cmake_pipeline "$build_dir"

    log_info "Restoring user ownership on shell directories..."
    sudo chown -R "$USER:$USER" "$TARGET_QSCONF" "${TARGET_LOCAL}" "${HOME}/.config/olvex" 2>/dev/null || true

    setup_cli_and_ydotool "${TARGET_LOCAL}" "$build_dir"
}

apply_driver_configurations() {
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
            log_info "Configuring SDDM..."
            sudo mkdir -p /etc/sddm.conf.d
            # Remove incomplete Wayland greeter override that causes TTY1 black screen VT freeze on Hyprland login
            sudo rm -f /etc/sddm.conf.d/10-wayland.conf 2>/dev/null || true
            sudo tee /etc/sddm.conf.d/10-olvex.conf >/dev/null <<'EOF'
[General]
InputMethod=
Numlock=none
EOF
            sudo systemctl enable sddm.service 2>/dev/null || true
            log_success "SDDM enabled with seamless VT switching."
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
    log_info "Verifying user ownership across ~/.config and ~/.local..."
    
    # Restore user ownership on any directory touched under escalated steps
    sudo chown -R "$USER:$USER" "${HOME}/.config" "${HOME}/.local" 2>/dev/null || true
    sudo find "${HOME}" -maxdepth 4 -user root -exec chown "$USER:$USER" {} + 2>/dev/null || true
    
    log_success "User directory ownership verified."
}

setup_warp_service() {
    if ! command -v warp-cli &>/dev/null; then
        log_warn "warp-cli not found; skipping Cloudflare WARP service setup."
        return 0
    fi

    log_info "Enabling and starting warp-svc.service..."
    if ! sudo systemctl enable --now warp-svc.service; then
        log_warn "Failed to enable/start warp-svc.service."
        return 0
    fi

    log_info "Waiting for warp-svc daemon to become ready..."
    local ready=0
    local i
    for i in $(seq 1 30); do
        if warp-cli --accept-tos status >/dev/null 2>&1; then
            ready=1
            break
        fi
        sleep 1
    done

    if [ "$ready" -ne 1 ]; then
        log_warn "warp-svc is not responding yet. Check later: journalctl -u warp-svc -e"
        return 0
    fi

    if warp-cli --accept-tos registration show >/dev/null 2>&1; then
        log_success "Cloudflare WARP device already registered."
    else
        log_info "Registering new Cloudflare WARP device..."
        if warp-cli --accept-tos registration new 2>/dev/null || warp-cli --accept-tos register 2>/dev/null; then
            log_success "Cloudflare WARP registered."
        else
            log_warn "Cloudflare WARP registration failed (run 'warp-cli --accept-tos registration new' later)."
        fi
    fi
}

apply_post_install_actions() {
    setup_warp_service

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
        remind_manual_ignored_pkgs
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
    local width=72
    local title="Installation Complete"
    local fill_len=$((width - ${#title} - 9))
    [ $fill_len -lt 4 ] && fill_len=4
    local fill_line
    fill_line="$(repeat_str "${BOX_H}" "$fill_len")"
    local bot_line
    bot_line="$(repeat_str "${BOX_H}" $((width - 1)))"

    echo -e "\n${CLR_CYAN}${CLR_BOLD}${BOX_TL}${BOX_H}${BOX_H} [ ${title} ] ${fill_line}${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET} ${CLR_GREEN}${CLR_BOLD}${GLYPH_OK} Olvex Shell and Hyprland environment deployed.${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET} ${CLR_BOLD}Deployed Locations${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET}   ${GLYPH_BULLET} Hyprland Config   : ${CLR_CYAN}${TARGET_HYPR}${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET}   ${GLYPH_BULLET} Shell Core        : ${CLR_CYAN}${TARGET_LOCAL}${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET}   ${GLYPH_BULLET} Quickshell Dir    : ${CLR_CYAN}${TARGET_QSCONF}${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET}   ${GLYPH_BULLET} Olvex CLI         : ${CLR_CYAN}${TARGET_BIN}/olvex${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET} ${CLR_BOLD}Quick Commands${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET}   ${GLYPH_BULLET} Start Shell       : ${CLR_YELLOW}olvex shell -d${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET}   ${GLYPH_BULLET} Restart Shell     : ${CLR_YELLOW}olvex shell restart${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET}   ${GLYPH_BULLET} Toggle Launcher   : ${CLR_YELLOW}olvex shell drawers toggle launcher${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET}   ${GLYPH_BULLET} Reload Hyprland   : ${CLR_YELLOW}hyprctl reload${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET}   ${GLYPH_BULLET} Rebuild Plugins   : ${CLR_YELLOW}./setup.sh --build${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET}   ${GLYPH_BULLET} Check Updates     : ${CLR_YELLOW}olvex update${CLR_RESET}"
    if [ "${CONF_SET_FISH:-false}" = true ] || [ "${HAS_NVIDIA:-false}" = true ] || [ "${CONF_LOGIN_METHOD:-1}" = "1" ]; then
        echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET}"
        echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET} ${CLR_BOLD}Session Notes${CLR_RESET}"
        if [ "${CONF_SET_FISH:-false}" = true ]; then
            echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET}   ${GLYPH_BULLET} Open a new login session to activate Fish as default shell."
        fi
        if [ "${CONF_LOGIN_METHOD:-1}" = "1" ]; then
            echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET}   ${GLYPH_BULLET} Display manager enabled — reboot or restart display-manager to apply."
        fi
        if [ "${HAS_NVIDIA:-false}" = true ]; then
            echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET}   ${GLYPH_BULLET} NVIDIA modeset & DKMS updated — reboot recommended before launch."
        fi
    fi
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_BL}${bot_line}${CLR_RESET}\n"
    remind_manual_ignored_pkgs
}

execute_all_changes() {
    cd "${HOME}" || true
    local total_exec_steps=6
    [ ${#ALL_MISSING_PKGS[@]} -gt 0 ] && ((total_exec_steps++))
    [ "$CONF_DRIVERS" = true ] && ((total_exec_steps++))
    local current_step=1

    # 1. Install missing packages with interactive failure recovery
    if [ ${#ALL_MISSING_PKGS[@]} -gt 0 ]; then
        section_header "Dependency Installation" "[${current_step}/${total_exec_steps}]"
        log_info "Invoking ${AUR_HELPER} for ${#ALL_MISSING_PKGS[@]} package(s)..."
        install_missing_dependencies_step
        ((current_step++))
    fi

    # 2. Deploy system configurations
    section_header "Configuration Deployment" "[${current_step}/${total_exec_steps}]"
    deploy_system_configurations
    ((current_step++))

    # 3. Build & Setup Olvex
    section_header "Native Build & System Integration" "[${current_step}/${total_exec_steps}]"
    build_and_setup_olvex
    save_install_configuration
    ((current_step++))

    # 4. Apply Driver Configurations
    if [ "$CONF_DRIVERS" = true ]; then
        section_header "Hardware Driver Configuration" "[${current_step}/${total_exec_steps}]"
        apply_driver_configurations
        ((current_step++))
    fi

    # 5. Apply Login Method
    section_header "Login & Session Management" "[${current_step}/${total_exec_steps}]"
    apply_login_method
    ((current_step++))

    # 6. Bootstrap Themes
    section_header "Theme & Environment Bootstrap" "[${current_step}/${total_exec_steps}]"
    bootstrap_scheme_and_themes
    ((current_step++))

    # 7. Ownership check
    section_header "Ownership & Permission Check" "[${current_step}/${total_exec_steps}]"
    universal_permission_sweep
    ((current_step++))

    # 8. Post-installation actions
    section_header "Post-Install Finalization" "[${current_step}/${total_exec_steps}]"
    apply_post_install_actions

    # 9. Final summary
    display_final_summary
}

build_and_install_mode() {
    local clean_build="${1:-false}"
    local mode_tag="Development Build"
    [ "$clean_build" = true ] && mode_tag="Clean Rebuild"

    banner "$mode_tag"

    if [ "$(id -u)" -eq 0 ]; then
        log_error "Do not run this script as root (avoid sudo ./setup.sh --build)."
        log_error "Run as your regular user; privilege escalation is requested when needed."
        exit 1
    fi

    local source_dir="${SCRIPT_DIR}/Olvex"
    if [[ ! -d "$source_dir" ]]; then
        log_error "Missing required source directory: $source_dir"
        exit 1
    fi

    local build_dir="${source_dir}/build"
    if [ "$clean_build" = true ]; then
        log_info "Cleaning existing build directory (${build_dir})..."
        rm -rf "$build_dir"
    fi

    section_header "Build Toolchain Check" "[1/4]"
    local missing=()
    for cmd in cmake ninja git pkgconf gcc; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log_warn "Missing required build tools: ${missing[*]}"
        log_info "Installing missing build tools via pacman..."
        sudo -H pacman -S --needed --noconfirm "${missing[@]}" || {
            log_error "Failed to install required tools. Run manually: sudo pacman -S ${missing[*]}"
            exit 1
        }
    fi
    log_success "Build toolchain verified."

    section_header "Preparing Targets & Build" "[2/4]"
    mkdir -p "$build_dir"
    mkdir -p "$TARGET_QSCONF"
    mkdir -p "$TARGET_BIN"
    mkdir -p "${HOME}/.config/olvex/monitors"
    mkdir -p "${HOME}/Pictures/Wallpapers"
    if [[ -d "${source_dir}/assets/Wallpapers" ]]; then
        cp -r "${source_dir}/assets/Wallpapers"/* "${HOME}/Pictures/Wallpapers/" 2>/dev/null || true
    fi
    touch -a "${HOME}/.config/olvex/hypr-vars.conf" "${HOME}/.config/olvex/hypr-user.conf"

    section_header "Compiling & Installing Targets" "[3/4]"
    run_cmake_pipeline "$build_dir"
    log_info "Restoring user ownership on shell directories..."
    sudo chown -R "$USER:$USER" "$TARGET_QSCONF" "${HOME}/.config/olvex" 2>/dev/null || true
    log_success "Compiled targets installed."

    section_header "CLI & Input Daemon Setup" "[4/4]"
    setup_cli_and_ydotool "$source_dir" "$build_dir"

    local width=72
    local title="Build Complete"
    local fill_len=$((width - ${#title} - 9))
    local fill_line bot_line
    fill_line="$(repeat_str "${BOX_H}" "$fill_len")"
    bot_line="$(repeat_str "${BOX_H}" $((width - 1)))"

    echo -e "\n${CLR_CYAN}${CLR_BOLD}${BOX_TL}${BOX_H}${BOX_H} [ ${title} ] ${fill_line}${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET} ${CLR_GREEN}${CLR_BOLD}${GLYPH_OK} Olvex native build and installation completed.${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET} ${CLR_BOLD}Quick Commands${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET}   ${GLYPH_BULLET} Start Shell       : ${CLR_YELLOW}olvex shell -d${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET}   ${GLYPH_BULLET} Restart Shell     : ${CLR_YELLOW}olvex shell restart${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET}   ${GLYPH_BULLET} Quickshell CLI    : ${CLR_YELLOW}qs -c olvex${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_V}${CLR_RESET}   ${GLYPH_BULLET} Rebuild Shell     : ${CLR_YELLOW}./setup.sh --build${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}${BOX_BL}${bot_line}${CLR_RESET}\n"
}

show_help() {
    echo -e "${CLR_BOLD}Olvex Shell Deployment Manager v2${CLR_RESET} — Where Motion Feels Alive"
    echo ""
    echo -e "Usage: $0 [MODE] [OPTIONS]"
    echo ""
    echo -e "Modes:"
    echo -e "  (default)             Interactive deployment wizard, dependency setup, and native build"
    echo -e "  -b, --build, build    Incremental native build and install from local source"
    echo -e "  --rebuild             Clean build directory and perform a full native rebuild"
    echo ""
    echo -e "Options:"
    echo -e "  -y, --noconfirm       Run non-interactively using default wizard selections"
    echo -e "  -h, --help            Display this help message and exit"
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
    banner "Full System Deployment"
    prompt_user_configuration
    run_preflight_and_verification
    execute_all_changes
}

main "$@"
