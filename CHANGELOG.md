# Changelog

All notable changes to **Olvex Shell** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-09-06

### 🚀 Added
- **Dynamic Background Blur & Transparency Engine**: Configurable `blurRadius` (1–30px) and `blurPasses` (1–5) in Appearance Settings with instant Hyprland batch IPC synchronization and auto-persistence.
- **Night Light Service**: Gammastep integration for display color temperature management with dedicated Quick Settings toggle and Settings configuration.
- **Lock Screen Customization**: Card and Minimal layouts with configurable lockscreen blur radius and dimming options.
- **M3 Expressive Password Dots**: Animated `M3PasswordDots` component for masked password inputs in lockscreen and Wi-Fi authentication dialogs.
- **Interactive Automated Setup Wizard**: Replaced manual install scripts with a hardware-aware interactive installer in `setup.sh`.
- **Keybind Editor**: Built-in Hyprland keybinding browser and editor in Settings (`services/Keybinds.qml`).
- **Saved Wi-Fi Networks Manager**: Added saved network credential viewer and editor in Network Settings.
- **Bottom Panel Dock Background Toggle**: Configurable dock backdrop visibility for pinned applications.

### 🎨 UI & UX Improvements
- **Settings Entrance Animations**: Fluid staggered reveal transitions across all settings subpages.
- **Centralized System Information**: Refactored hardware, OS, host, and kernel info parsing into `utils/SysInfo.qml`.
- **Redesigned Quick Settings Menus**: Enhanced Wi-Fi and Bluetooth expansion overlays with smooth spring transitions.
- **Expressive Bar & Workspaces Motion**: Improved workspace morphing indicators, contrast, and system tray popouts.
- **Polished Input Controls**: Modernized text fields, spinboxes, and auto-dismiss behavior on click-outside.

### ⚡ Performance & Stability
- Optimized lockscreen and application launcher component rendering and idle resource footprint.
- Replaced unconfigured `QtCore.Settings` with `PersistentProperties` in `services/Visibilities.qml` to prevent startup warnings.
- Improved Hyprland systemd service autostart handling and idempotent profile cleanup guards.

### 🐛 Fixed
- Fixed bottom-right desktop corner interaction bleed triggering Quick Settings panel unexpectedly.
- Fixed shell blur levels resetting to defaults upon shell restart.
- Fixed notification icon pixelation on the lock screen with proper icon resolution queries.
- Fixed desktop clock layout alignment and dock popup menu placement.

---

## [1.0.0] - 2026-08-25

### 🚀 Initial Release
- Core Quickshell desktop environment on Hyprland.
- Material Design 3 (M3) Expressive design system with dynamic wallpaper palette theming.
- Floating Bar, Application Launcher, Control Center, Media Player (MPRIS) controls, Notification dock, and Lock screen.
- Real-time PipeWire audio visualizer (Cava) and beat tracker (aubio).
- C++ QML plugin engine (`Olvex`, `Olvex.Config`, `Olvex.Services`, `Olvex.Internal`, `Olvex.Blobs`).
