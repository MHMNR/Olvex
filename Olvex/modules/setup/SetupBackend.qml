import QtQuick
import Quickshell
import Quickshell.Io
import Olvex.Config
import qs.services
import qs.utils

// ─────────────────────────────────────────────────────────────────────────────
// SetupBackend: THE ONLY place where the wizard touches the real system.
//
// Connected to live Olvex singletons:
//   monitors          <- DisplayManager.monitors
//   applyScale()      -> hyprctl keyword monitor
//   applyThemeMode()  -> Colours.setMode(mode)
//   applyWallpaper()  -> Wallpapers.setWallpaper(path)
//   applyTransparency()-> GlobalConfig.appearance.transparency.enabled
//   applyBlur()       -> GlobalConfig.appearance.transparency.blur
//   applyDefaultApps()-> GlobalConfig.general.apps + variables.lua + xdg-settings
//   finish()          -> GlobalConfig.save()
// ─────────────────────────────────────────────────────────────────────────────
QtObject {
    id: root

    // Master switch. Now CONNECTED.
    property bool connected: true

    // Live data sockets
    readonly property var monitors: (DisplayManager && DisplayManager.monitors && DisplayManager.monitors.length > 0)
        ? DisplayManager.monitors
        : null

    function applyScale(monitorName, scale) {
        if (!root.connected)
            return;
        const list = DisplayManager.monitors || [];
        const m = list.find(mon => mon.name === monitorName) || list[0];
        const name = m ? m.name : (monitorName || "eDP-1");
        const s = Number(scale) || 1.0;
        Quickshell.execDetached(["hyprctl", "keyword", "monitor", `${name},preferred,auto,${s}`]);
    }

    function applyThemeMode(mode) {
        if (!root.connected)
            return;
        Colours.setMode(mode);
    }

    function applyWallpaper(path) {
        if (!root.connected)
            return;
        // Kill third-party background wallpaper services so Olvex owns wallpaper rendering cleanly
        Quickshell.execDetached(["sh", "-c", "pkill -x swww-daemon 2>/dev/null; pkill -x swww 2>/dev/null; pkill -x hyprpaper 2>/dev/null; pkill -x mpvpaper 2>/dev/null; pkill -x wpaperd 2>/dev/null; pkill -x swaybg 2>/dev/null; pkill -x feh 2>/dev/null; pkill -x nitrogen 2>/dev/null; true"]);
        Wallpapers.setWallpaper(path);
    }

    function applyTransparency(enabled) {
        if (!root.connected)
            return;
        if (GlobalConfig.appearance && GlobalConfig.appearance.transparency) {
            GlobalConfig.appearance.transparency.enabled = enabled;
            GlobalConfig.save();
        }
    }

    function applyBlur(enabled) {
        if (!root.connected)
            return;
        if (GlobalConfig.appearance && GlobalConfig.appearance.transparency) {
            GlobalConfig.appearance.transparency.blur = enabled;
            GlobalConfig.save();
        }
    }

    function applyDefaultApps(terminal, browser, fileManager) {
        if (!root.connected)
            return;

        // 1. Olvex Config
        if (GlobalConfig.general && GlobalConfig.general.apps) {
            if (terminal)
                GlobalConfig.general.apps.terminal = [terminal];
            if (fileManager)
                GlobalConfig.general.apps.explorer = [fileManager];
            GlobalConfig.save();
        }

        // 2. System XDG default browser
        if (browser) {
            Quickshell.execDetached(["xdg-settings", "set", "default-web-browser", `${browser}.desktop`]);
        }

        // 3. Update ~/.config/hypr/variables.lua & sync Github/.config/hypr/variables.lua
        const pyScript = Qt.resolvedUrl("sync_variables.py").toString().replace(/^file:\/\//, "");
        Quickshell.execDetached(["python3", pyScript, terminal || "", browser || "", fileManager || ""]);
    }

    function finish() {
        if (!root.connected)
            return;
        GlobalConfig.save();
    }
}
