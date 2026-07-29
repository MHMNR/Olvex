<div align="center">

  <img src=".github/banner.svg" alt="Olvex Shell Banner" width="100%" />

  <br />

  <p align="center">
    <a href="#about"><img src="https://img.shields.io/badge/Design-Material_3_Expressive-675FFF?style=for-the-badge&logo=materialdesign&logoColor=white" alt="M3 Expressive"></a>
    <a href="#installation"><img src="https://img.shields.io/badge/Framework-Quickshell_Qt6-FF8A5B?style=for-the-badge&logo=qt&logoColor=white" alt="Quickshell Qt6"></a>
    <a href="#keybindings"><img src="https://img.shields.io/badge/Compositor-Hyprland_Wayland-6ED2FB?style=for-the-badge&logo=hyprland&logoColor=black" alt="Hyprland"></a>
  </p>

  <h3>A GPU-accelerated Linux desktop environment shell built on Quickshell and Hyprland.</h3>

</div>

---

## Overview

**Olvex** is a desktop environment shell engineered for Linux systems running the **Hyprland** Wayland compositor. Built using **Quickshell** (a Qt6 QML framework) and native C++ plugins, Olvex implements Google's Material Design 3 (M3 Expressive) design system, complete with dynamic theme extraction, hardware-accelerated rendering, and modular multi-monitor window management.

### Key Architectural Capabilities

- **Dynamic Theme Extraction**: Dynamically parses wallpaper color palettes to generate Material Design 3 color tokens (`scheme.json`).
- **Hardware Acceleration**: C++ plugin extensions for real-time PipeWire audio spectral analysis via Cava and beat tracking via Aubio.
- **Shader Pipeline**: Low-latency GPU layer-shell rendering for glassmorphic blurs, shape morphs, and spring physics.
- **Multi-Monitor Orchestration**: Per-screen drawer management with isolated monitor configuration targets (`~/.config/olvex/monitors/`).
- **XDG Terminal Integration**: Native Fish and Bash prompt integrations with subpixel Braille branding aligned to active system accents.

---

## Desktop Components

Olvex includes a comprehensive suite of shell interfaces:

| Component | Description |
| :--- | :--- |
| **Status Bar** | Top and bottom panel surfaces hosting workspace selectors, status indicators, and active window metadata. |
| **Dashboard** | Central overlay containing hardware performance graphs, media controls, weather reports, and quick toggles. |
| **Application Launcher** | Rapid application dispatcher featuring inline mathematical calculations and wallpaper selection. |
| **Control Center** | Independent Qt window providing fine-grained desktop environment preferences and system controls. |
| **Clipboard Manager** | Dedicated floating interface (`olvex-clipboard`) backed by `cliphist` for text and image history. |
| **Notification Daemon** | Desktop notification service implementing Material Design 3 toast alerts and persistent history. |
| **Screen Locker** | Security lock surface rendered via Qt Quick with authentication feedback and power management. |

---

## Prerequisites & Dependencies

### Package Requirements (Arch Linux)

Ensure the following packages are installed before compiling and launching Olvex:

#### 1. Core Build & Qt6 Framework
- `base-devel`, `cmake`, `ninja`, `git`, `pkgconf`, `gcc-libs`, `glibc`
- `qt6-base`, `qt6-declarative`, `qt6-shadertools`, `qt6-wayland`, `qt6-5compat`, `qt6-svg`, `qt6-imageformats`

#### 2. Compositor, Shell & Wallpaper Engine
- `hyprland` (Wayland Compositor)
- `quickshell-git` (AUR) (Qt6 QML Desktop Shell Framework)
- `swww` (Wallpaper Daemon)
- `matugen` (Material Design 3 Dynamic Color Generator)
- `m3shapes` (C++ Shape Mask Library)

#### 3. Audio, Display & Hardware Services
- `pipewire`, `libpipewire`, `wireplumber`
- `cava`, `libcava`, `aubio` (Audio Spectral Analysis & Beat Tracking)
- `brightnessctl`, `ddcutil` (Backlight & Monitor DDC Controls)
- `lm-sensors`, `upower` (Hardware Temperature & Battery)
- `networkmanager`, `bluez`, `bluez-utils` (Network & Bluetooth)
- `fprintd` (Fingerprint PAM Integration)

#### 4. File Management, Authentication & Browser
- `thunar`, `thunar-volman`, `thunar-archive-plugin`, `thunar-media-tags-plugin` (File Manager & Extensions)
- `tumbler`, `ffmpegthumbnailer` (Thumbnail Generators)
- `gvfs`, `gvfs-mtp`, `gvfs-gphoto2`, `gvfs-afc`, `gvfs-smb` (Virtual File System & Mounting)
- `polkit-gnome` (Authentication Agent)
- `firefox` (Web Browser)

#### 5. Desktop Utilities, Capture & Terminal
- `cliphist`, `wl-clipboard` (Clipboard History & Selection)
- `grim`, `slurp`, `swappy` (Interactive Screenshot & Annotation)
- `gpu-screen-recorder` (Hardware-Accelerated Screen Recorder)
- `ydotool` (Virtual Input Controls & Gestures)
- `libqalculate` (Launcher Calculator Backend)
- `libnotify` (Desktop Notification Protocol)
- `mpv` (Media Engine)
- `app2unit` (Systemd Application Unit Manager)
- `foot` (Terminal Emulator)
- `bash`, `fish`, `xdg-utils`

#### 6. Fonts & Icon Typography
- `ttf-material-symbols` / `material-symbols`
- `caskaydia-cove-nerd`
- `ttf-rubik`

#### 7. Python Runtime & Image Libraries
- `python3`, `python-pip`, `python-pillow`

---

## Installation Guide

### Option A: Automated Setup

Clone the repository and run the setup script:

```bash
git clone https://github.com/MHMNR/Olvex.git
cd Olvex
./setup.sh
```

---

### Option B: Full Manual Installation (Step-by-Step)

If you prefer building and installing all components manually, follow these detailed steps:

#### Step 1: Install Package Dependencies

**Arch Linux / CachyOS Repository Packages:**
```bash
sudo pacman -S --needed \
    base-devel cmake ninja git pkgconf gcc-libs glibc \
    qt6-base qt6-declarative qt6-shadertools qt6-wayland qt6-5compat qt6-svg qt6-imageformats \
    hyprland swww pipewire libpipewire wireplumber cava aubio \
    brightnessctl ddcutil lm-sensors upower networkmanager bluez bluez-utils fprintd \
    thunar thunar-volman thunar-archive-plugin thunar-media-tags-plugin tumbler ffmpegthumbnailer \
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-afc gvfs-smb polkit-gnome firefox \
    cliphist wl-clipboard grim slurp swappy gpu-screen-recorder ydotool \
    libqalculate libnotify mpv foot bash fish xdg-utils \
    ttf-rubik python3 python-pip python-pillow
```

**AUR Packages (via `yay` or `paru`):**
```bash
yay -S --needed \
    quickshell-git matugen m3shapes app2unit \
    material-symbols caskaydia-cove-nerd
```

---

#### Step 2: Clone the Repository
```bash
git clone https://github.com/MHMNR/Olvex.git
cd Olvex
```

---

#### Step 3: Build & Install C++ Plugins

Olvex relies on custom native C++ QML plugins (`Olvex`, `Olvex.Config`, `Olvex.Services`, `Olvex.Internal`, etc.) located in `plugin/`:

```bash
# Create build directory
mkdir -p build && cd build

# Configure CMake project with Ninja generator
cmake -G Ninja -DCMAKE_BUILD_TYPE=Release ..

# Build C++ modules
ninja

# Install plugin to Qt QML import path
sudo cmake --install .
cd ..
```

---

#### Step 4: Deploy Shell Files & Executable Scripts

Copy the QML shell code to Quickshell's configuration path and install the `olvex` CLI helper:

```bash
# Create configuration directories
mkdir -p ~/.config/quickshell/olvex
mkdir -p ~/.config/olvex
mkdir -p ~/.local/bin

# Copy QML shell files
cp -r Olvex/* ~/.config/quickshell/olvex/

# Install olvex CLI executable
cp scripts/olvex ~/.local/bin/
chmod +x ~/.local/bin/olvex

# Ensure ~/.local/bin is in your PATH
export PATH="$HOME/.local/bin:$PATH"
```

---

#### Step 5: Setup Virtual Input (`ydotool`)

Olvex uses `ydotool` for virtual keypresses and gesture controls:

```bash
# Enable and start ydotool daemon
sudo systemctl enable --now ydotool

# Add current user to input group for permissions
sudo usermod -aG input $USER
```

---

#### Step 6: Configure Hyprland Autostart

Add the following execution lines to your Hyprland configuration file (`~/.config/hypr/hyprland.conf` or `~/.config/hypr/hyprland/execs.conf`):

```ini
# Start ydotool daemon
exec-once = ydotool daemon

# Launch Olvex Shell via Quickshell (standard deployed path)
exec-once = quickshell -p ~/.config/quickshell/olvex/

# Or launch directly from your custom clone/development directory:
# exec-once = quickshell -p /PATH_TO_YOUR_DIR/Olvex/
```

---

#### Step 7: Launch Olvex Shell

Start the shell manually for testing or live development:

```bash
# Standard deployed configuration path:
quickshell -p ~/.config/quickshell/olvex/

# Or launch directly from custom development directory:
quickshell -p /PATH_TO_YOUR_DIR/Olvex/
```

Or run via the CLI dispatcher:
```bash
olvex shell -d
```

---

## Default Keybindings (Hyprland)

Keybindings are configured within `~/.config/hypr/hyprland/keybinds.conf`:

| Keybinding | Action |
| :--- | :--- |
| `Super` | Toggle Application Launcher |
| `Super + Space` | Toggle Application Launcher |
| `Super + D` | Toggle Dashboard |
| `Super + C` | Open Control Center |
| `Super + V` | Toggle Clipboard Manager |
| `Super + Period` | Open Emoji Picker |
| `Super + L` | Trigger Lock Screen |
| `Print` | Capture Fullscreen to Clipboard |
| `Super + Shift + S` | Capture Region (Interactive) |
| `Super + Alt + R` | Record Screen (Audio Enabled) |
| `Ctrl + Alt + R` | Record Screen |
| `Ctrl + Super + Shift + R` | Terminate Shell Process |
| `Ctrl + Super + Alt + R` | Restart Shell Daemon |

---

## IPC Command Interface

Olvex exposes an IPC interface via the `olvex` CLI binary for programmatic control:

### Interface Control
```bash
olvex shell drawers toggle launcher       # Toggle Application Launcher
olvex shell drawers toggle dashboard      # Toggle System Dashboard
olvex shell drawers toggle session        # Toggle Session / Power Menu
olvex shell drawers toggle utilities      # Toggle Quick Utilities Drawer
olvex shell drawers toggle wallpapers     # Open Wallpaper Selector
olvex shell controlCenter open            # Launch Control Center
olvex shell lock open                     # Engage Lock Screen
olvex shell notifs clear                  # Dismiss All Active Notifications
```

### Process Management
```bash
olvex shell restart                       # Soft-restart shell background process
olvex shell kill                          # Terminate shell process
```

---

## Configuration Paths

- **QML Shell Target**: `~/.config/quickshell/olvex/`
- **Global Configuration**: `~/.config/olvex/shell.json`
- **Per-Monitor Overrides**: `~/.config/olvex/monitors/<MONITOR_NAME>/shell.json`
- **System Accent Tokens**: `~/.local/state/olvex/scheme.json`

---

## Credits

Olvex began as a fork of [**Caelestia**](https://github.com/caelestia-dots/shell) and has since been substantially redesigned — the majority of the UI, component architecture, and the native C++ plugin layer are original to this project. That said, none of this exists in a vacuum, and it would be dishonest not to name the work this project stands on.

### Special thanks

- **[Caelestia](https://github.com/caelestia-dots/shell)** ([@caelestia-dots](https://github.com/caelestia-dots)) — the original base this shell was forked from, and the project that first showed what a fluid, morphing Quickshell environment for Hyprland could look like. Large parts of Olvex's architecture trace their lineage back here, even where the implementation has since diverged completely.
- **[Dank Material Shell](https://github.com/AvengeMedia/DankMaterialShell)** ([@AvengeMedia](https://github.com/AvengeMedia)) — several UI ideas and interaction patterns in Olvex were inspired by DMS's take on Material theming for Quickshell.
- **[illogical-impulse](https://github.com/end-4/dots-hyprland)** ([@end-4](https://github.com/end-4)) — an early and ongoing influence on the Hyprland + Quickshell rice scene, and the source of a few conventions adapted into Olvex.
- **[Quickshell](https://github.com/quickshell-mirror/quickshell)** ([@outfoxxed](https://github.com/outfoxxed)) — for building and maintaining the framework all of this runs on.
- **[Hyprland](https://github.com/hyprwm/Hyprland)** ([@vaxry](https://github.com/vaxry) and contributors) — the compositor Olvex is built for.

If you recognize a component, animation, or pattern from your own project and think it deserves a more specific mention here, please open an issue — attribution gaps are bugs, not decisions.

---