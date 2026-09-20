# Changelog

All notable changes to **Olvex Shell** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.2.1] - 2026-09-20

### Added
- **On-Screen Keyboard (OSK) Wayland Exclusive Zone**: Added dedicated "Exclusive Zone" toggle in OSK Settings. In docked mode, OSK automatically reserves layer-shell screen space so tiled and floating windows seamlessly adjust above the keyboard.
- **Dynamic Docked OSK Corner Rounding**: OSK docked corners dynamically adapt to Olvex screen corner decoration (`GlobalConfig.border.rounding`).
- **Dynamic Battery Glyphs & Power Saver Indicators**: Reactive multi-level battery icon rendering with charging states and visual power saver mode indicators.
- **IP Geolocation via ipwho.is**: Integrated `ipwho.is` provider with robust reverse-geocoding fallback pipeline in weather services.
- **Hardware-Accelerated Clipboard Thumbnails**: Added `QtQuick.Effects` image decoding and caching pipeline for clipboard history preview thumbnails.
- **Standalone Clipboard Application**: Installed and integrated `olvex-clipboard` standalone utility binary.
- **PickerGrid Component & Auto-Detection**: Integrated `PickerGrid` component and automatic OS glyph detection in system information utilities (`SysInfo.qml`).

### UI & UX Improvements
- **Docked OSK & Bottom Panel Overlay Flow**: Intelligent bottom panel auto-hide during docked OSK typing, sliding up as a smooth overlay when hovering the screen bottom edge.
- **OSK Entrance & Exit Motion**: Replaced abrupt toggling with smooth bottom slide transitions and synchronized entrance progress.
- **Centered Key Glyphs**: Refactored `OskKey.qml` to perfectly center Super/distro logo glyphs and control labels within key pills.
- **Dynamic Decay Kinetic Shifts**: Replaced static taskbar shifts with fluid physics decay and explicit scale transitions.
- **Workspace Indicator Pulse**: Added responsive workspace switch pulse animations and adjusted ring sizing.
- **OsIcon Styling**: Added dynamic color properties and subtle light theme borders for desktop OS icons.

### Performance & Stability
- **Offscreen Transition Rendering**: Enabled offscreen rendering caching across feature drawer wrappers to eliminate frame drops during panel open/close.
- **Screen Recorder & Notification Morph Optimization**: Streamlined screen recorder service capture logic and notification pill morph calculations.
- **Night Light & Tray Streamlining**: Streamlined Night Light service management, tray popout logic, and clock background rendering.
- **Resolved Layer Shell Property Conflicts**: Cleaned up layer-shell property assignments and input region masks across drawers.

---

## [1.2.0] - 2026-09-08

### Added
- **Kinetic Push Physics Engine**: Downward momentum transmission across taskbar elements (`wsPushForce`, `notifPushForce`, `downwardPushForce`), producing elastic cascade squash and translate reactions across older notification circles, media/active window pills, tray, clock, system status, and network speed indicators.
- **Dynamic Multi-Notification Stacking System**: Interactive notification dock supporting multiple concurrent notifications with animated push-down morphing into mini circles, real-time Y-glide dynamic stack positioning, and stagger entrance easing.
- **Notification Dismiss Lifecycle & Interaction**: Smooth upward slide-fade dismiss animations (`dismissLastAnim`), non-destructive queue management, and secondary mouse button (right-click / middle-click) quick dismissal.
- **Bottom Panel Pinned Apps Overflow Flyout**: Intelligent overflow detection and dedicated flyout container for pinned application icons when panel space is constrained.
- **Shader-Driven Toast Blob Rendering**: GPU-accelerated blob shape rendering for desktop toast containers with optimized fragment sampling and antialiasing.
- **Toplevel Workspace Occupancy Tracking**: Synchronized Hyprland window tracking to reactively update workspace active states and window visibility.
- **Expressive Soft Spatial Motion Tokens**: Added new `Tokens.anim.expressiveSoftSpatial` cubic bezier curve for fluid capsule transformations.

### UI & UX Improvements
- **Active Window & Media Morph Architecture**: Replaced state-based geometry with continuous interpolation properties (`animatedMorphProgress`, `animatedNotifProgress`) for smooth transitions without layout snapping.
- **Synchronized Media Dock Alignment**: Centralized media morph dock calculation with sub-pixel tolerance checks and debounced geometry updates.
- **Reactive Theme & Media Accent Color Extraction**: Centralized image analysis pipelines for thumbnail-derived accents with automatic contrast adaptation.
- **Pinned App Removal Motion**: Smooth animated scale-down and collapse transitions when unpinning items from the bottom panel dock.
- **Quick Settings Hot Corner**: Integrated bottom-right desktop corner interaction trigger to quickly toggle the Quick Settings panel.
- **Refined Launcher Search**: Cleaned up launcher search flow by removing redundant action prefix prefixes and updating input control styling.

### Performance & Stability
- Optimized fragment shader sampling and antialiasing in blob and gauge rendering items.
- Eliminated intermediate layout clipping during multi-notification arrivals and dismissals.
- Reduced redundant IPC roundtrips during toplevel window state synchronization.

---

## [1.1.0] - 2026-09-06

### Added
- **Dynamic Background Blur & Transparency Engine**: Configurable `blurRadius` (1–30px) and `blurPasses` (1–5) in Appearance Settings with instant Hyprland batch IPC synchronization and auto-persistence.
- **Night Light Service**: Gammastep integration for display color temperature management with dedicated Quick Settings toggle and Settings configuration.
- **Lock Screen Customization**: Card and Minimal layouts with configurable lockscreen blur radius and dimming options.
- **M3 Expressive Password Dots**: Animated `M3PasswordDots` component for masked password inputs in lockscreen and Wi-Fi authentication dialogs.
- **Interactive Automated Setup Wizard**: Replaced manual install scripts with a hardware-aware interactive installer in `setup.sh`.
- **Keybind Editor**: Built-in Hyprland keybinding browser and editor in Settings (`services/Keybinds.qml`).
- **Saved Wi-Fi Networks Manager**: Added saved network credential viewer and editor in Network Settings.
- **Bottom Panel Dock Background Toggle**: Configurable dock backdrop visibility for pinned applications.

### UI & UX Improvements
- **Settings Entrance Animations**: Fluid staggered reveal transitions across all settings subpages.
- **Centralized System Information**: Refactored hardware, OS, host, and kernel info parsing into `utils/SysInfo.qml`.
- **Redesigned Quick Settings Menus**: Enhanced Wi-Fi and Bluetooth expansion overlays with smooth spring transitions.
- **Expressive Bar & Workspaces Motion**: Improved workspace morphing indicators, contrast, and system tray popouts.
- **Polished Input Controls**: Modernized text fields, spinboxes, and auto-dismiss behavior on click-outside.

### Performance & Stability
- Optimized lockscreen and application launcher component rendering and idle resource footprint.
- Replaced unconfigured `QtCore.Settings` with `PersistentProperties` in `services/Visibilities.qml` to prevent startup warnings.
- Improved Hyprland systemd service autostart handling and idempotent profile cleanup guards.

### Fixed
- Fixed bottom-right desktop corner interaction bleed triggering Quick Settings panel unexpectedly.
- Fixed shell blur levels resetting to defaults upon shell restart.
- Fixed notification icon pixelation on the lock screen with proper icon resolution queries.
- Fixed desktop clock layout alignment and dock popup menu placement.

---

## [1.0.0] - 2026-08-25

### Initial Release
- Core Quickshell desktop environment on Hyprland.
- Material Design 3 (M3) Expressive design system with dynamic wallpaper palette theming.
- Floating Bar, Application Launcher, Control Center, Media Player (MPRIS) controls, Notification dock, and Lock screen.
- Real-time PipeWire audio visualizer (Cava) and beat tracker (aubio).
- C++ QML plugin engine (`Olvex`, `Olvex.Config`, `Olvex.Services`, `Olvex.Internal`, `Olvex.Blobs`).
