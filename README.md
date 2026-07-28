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

## System Requirements

Ensure the following dependencies are installed prior to deploying Olvex:

- **Compositor**: `hyprland`
- **Shell Engine**: `quickshell-git` (Qt 6.7+ QML framework)
- **Audio Infrastructure**: `pipewire`, `wireplumber`, `cava`, `aubio`
- **System Utilities**: `fastfetch`, `micro`, `fish`, `bash`, `python3`, `cliphist`, `slurp`, `grim`, `wf-recorder`

---

## Installation

### Automated Deployment
Clone the repository and run the setup script:

```bash
git clone https://github.com/your-username/QS-Config.git
cd QS-Config/Github
./setup.sh
```

### Manual Configuration
To configure the shell manually:

1. **Deploy Configuration Files**:
   ```bash
   cp -r .config/* ~/.config/
   ```

2. **Configure Bash Shell Environment**:
   Include the XDG bash entry point in your user `~/.bashrc`:
   ```bash
   echo '[ -f "$HOME/.config/bash/bashrc" ] && source "$HOME/.config/bash/bashrc"' >> ~/.bashrc
   ```

3. **Configure Fish Shell Environment**:
   Fish configuration is automatically loaded from `~/.config/fish/config.fish`.

4. **Initialize Olvex Daemon**:
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

- **Global Configuration**: `~/.config/olvex/shell.json`
- **Per-Monitor Overrides**: `~/.config/olvex/monitors/<MONITOR_NAME>/shell.json`
- **System Accent Tokens**: `~/.local/state/olvex/scheme.json`

---

<div align="center">
  <p>Olvex Shell &mdash; Qt Quick & Material Design 3 Interface Engine</p>
</div>
