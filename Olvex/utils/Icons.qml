pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Olvex.Config
import Olvex
import qs.utils

Singleton {
    id: root

    readonly property var weatherIcons: ({
            "0": "clear_day",
            "1": "clear_day",
            "2": "partly_cloudy_day",
            "3": "cloud",
            "45": "foggy",
            "48": "foggy",
            "51": "rainy",
            "53": "rainy",
            "55": "rainy",
            "56": "rainy",
            "57": "rainy",
            "61": "rainy",
            "63": "rainy",
            "65": "rainy",
            "66": "rainy",
            "67": "rainy",
            "71": "cloudy_snowing",
            "73": "cloudy_snowing",
            "75": "snowing_heavy",
            "77": "cloudy_snowing",
            "80": "rainy",
            "81": "rainy",
            "82": "rainy",
            "85": "cloudy_snowing",
            "86": "snowing_heavy",
            "95": "thunderstorm",
            "96": "thunderstorm",
            "99": "thunderstorm"
        })

    readonly property var categoryIcons: ({
            WebBrowser: "web",
            Printing: "print",
            Security: "security",
            Network: "chat",
            Archiving: "archive",
            Compression: "archive",
            Development: "code",
            IDE: "code",
            TextEditor: "edit_note",
            Audio: "music_note",
            Music: "music_note",
            Player: "music_note",
            Recorder: "mic",
            Game: "sports_esports",
            FileTools: "files",
            FileManager: "files",
            Filesystem: "files",
            FileTransfer: "files",
            Settings: "settings",
            DesktopSettings: "settings",
            HardwareSettings: "settings",
            TerminalEmulator: "terminal",
            ConsoleOnly: "terminal",
            Utility: "build",
            Monitor: "monitor_heart",
            Midi: "graphic_eq",
            Mixer: "graphic_eq",
            AudioVideoEditing: "video_settings",
            AudioVideo: "music_video",
            Video: "videocam",
            Building: "construction",
            Graphics: "photo_library",
            "2DGraphics": "photo_library",
            RasterGraphics: "photo_library",
            TV: "tv",
            System: "host",
            Office: "content_paste"
        })

    property var _iconResolveCache: ({})
    property var _iconSearchDirs: []

    readonly property var iconRoots: [
        Paths.home + "/.local/share/icons",
        Paths.home + "/.icons",
        Paths.home + "/.local/share/flatpak/exports/share/icons",
        "/var/lib/flatpak/exports/share/icons",
        "/usr/local/share/icons",
        "/usr/share/icons"
    ]
    readonly property var iconPixmapDirs: [
        Paths.home + "/.local/share/pixmaps/",
        "/usr/local/share/pixmaps/",
        "/usr/share/pixmaps/"
    ]
    readonly property var iconThemes: ["hicolor", "Papirus", "Papirus-Dark", "Papirus-Light", "breeze", "breeze-dark", "Adwaita", "AdwaitaLegacy"]
    readonly property var iconSizeDirs: ["scalable", "1024x1024", "512x512", "384x384", "256x256", "192x192", "160x160", "128x128", "96x96", "84x84", "72x72", "64x64", "48x48", "42x42", "32x32", "24x24", "22x22", "16x16", "8x8", "symbolic"]
    readonly property var iconNumericDirs: ["1024", "512", "384", "256", "192", "160", "128", "96", "84", "72", "64", "48", "42", "32", "24", "22", "16", "12", "8"]
    readonly property var iconCategories: ["apps", "actions", "devices", "status", "places", "categories", "mimetypes", "emblems", "emotes", "legacy", "panel", "preferences", "applets", "animations", "ui"]
    readonly property var iconExtensions: ["", ".png", ".svg", ".svgz", ".xpm", ".ico"]

    // Checks if a name matches an icon config. Icon configs can have the following keys:
    // - name: The exact name of the icon
    // - regex: A regex to match against the name (takes priority over name)
    // - flags: The regex flags (only used if regex is set)
    // - icon: The icon to use
    function matchIconConfig(name: string, iconConfig: var): bool {
        if (!iconConfig.icon)
            return false;

        if (iconConfig.regex) {
            const re = new RegExp(iconConfig.regex, iconConfig.flags ?? "");
            if (re.test(name))
                return true;
        } else if (iconConfig.name === name) {
            return true;
        }

        return false;
    }

    function getAppIcon(name: string, fallback: string): string {
        const icon = DesktopEntries.heuristicLookup(name)?.icon;
        if (fallback !== "undefined")
            return resolveIcon(icon, fallback);
        return resolveIcon(icon, "");
    }

    function getNotificationIcon(notif: var, fallback = ""): string {
        if (!notif) return "";
        
        const fb = (typeof fallback === "string" && fallback.length > 0) ? fallback : "application-x-executable";

        // 1. Direct explicit appIcon from notification
        if (notif.appIcon && typeof notif.appIcon === "string" && notif.appIcon.length > 0) {
            let direct = resolveIcon(notif.appIcon, "");
            if (direct)
                return direct;
        }

        // 2. Desktop entry property if present
        if (notif.desktopEntry && typeof notif.desktopEntry === "string" && notif.desktopEntry.length > 0) {
            let appIcon = getAppIcon(notif.desktopEntry, "");
            if (appIcon)
                return appIcon;
            let direct = resolveIcon(notif.desktopEntry, "");
            if (direct)
                return direct;
        }

        // 3. Heuristic / desktop entry lookup by appName
        if (notif.appName && typeof notif.appName === "string" && notif.appName.length > 0) {
            let appIcon = getAppIcon(notif.appName, "");
            if (appIcon)
                return appIcon;
            let direct = resolveIcon(notif.appName, "");
            if (direct)
                return direct;
        }

        // 4. Extracted theme icon or direct file path from image URL (only if no app icon found)
        if (notif.image && typeof notif.image === "string" && notif.image.length > 0) {
            const iconName = iconNameFromUrl(notif.image);
            if (iconName) {
                let resolved = resolveIcon(iconName, "");
                if (resolved)
                    return resolved;
            } else if (notif.image.startsWith("/") || notif.image.startsWith("file://") || notif.image.startsWith("~")) {
                let fileUrl = _fileIconUrl(notif.image);
                if (fileUrl)
                    return fileUrl;
            }
        }

        // 5. Fallback
        return resolveIcon(fb, "application-x-executable");
    }

    function _withTrailingSlash(path: string): string {
        return path && path.endsWith("/") ? path : path + "/";
    }

    function _addIconSearchDir(dirs: var, seen: var, dir: string): void {
        if (!dir || seen[dir] || !CUtils.fileExists(dir))
            return;

        seen[dir] = true;
        dirs.push(dir);
    }

    function _getIconSearchDirs(): var {
        if (_iconSearchDirs.length > 0)
            return _iconSearchDirs;

        const dirs = [];
        const seen = ({});

        for (let i = 0; i < iconPixmapDirs.length; i++)
            _addIconSearchDir(dirs, seen, iconPixmapDirs[i]);

        for (let r = 0; r < iconRoots.length; r++) {
            const rootDir = _withTrailingSlash(iconRoots[r]);
            _addIconSearchDir(dirs, seen, rootDir);

            for (let t = 0; t < iconThemes.length; t++) {
                const themeRoot = rootDir + iconThemes[t] + "/";
                if (!CUtils.fileExists(themeRoot))
                    continue;

                _addIconSearchDir(dirs, seen, themeRoot);

                for (let s = 0; s < iconSizeDirs.length; s++) {
                    const sizeRoot = themeRoot + iconSizeDirs[s] + "/";
                    _addIconSearchDir(dirs, seen, sizeRoot);

                    for (let c = 0; c < iconCategories.length; c++) {
                        _addIconSearchDir(dirs, seen, sizeRoot + iconCategories[c] + "/");
                        _addIconSearchDir(dirs, seen, sizeRoot + "symbolic/" + iconCategories[c] + "/");
                    }
                }

                for (let c = 0; c < iconCategories.length; c++) {
                    const categoryRoot = themeRoot + iconCategories[c] + "/";
                    _addIconSearchDir(dirs, seen, categoryRoot);
                    _addIconSearchDir(dirs, seen, themeRoot + "symbolic/" + iconCategories[c] + "/");
                    _addIconSearchDir(dirs, seen, themeRoot + "scalable/" + iconCategories[c] + "/");

                    for (let s = 0; s < iconNumericDirs.length; s++) {
                        _addIconSearchDir(dirs, seen, categoryRoot + iconNumericDirs[s] + "/");
                        _addIconSearchDir(dirs, seen, themeRoot + "symbolic/" + iconCategories[c] + "/" + iconNumericDirs[s] + "/");
                    }
                }
            }
        }

        _iconSearchDirs = dirs;
        return _iconSearchDirs;
    }

    function _fileIconUrl(path: string): string {
        if (!path)
            return "";

        let localPath = String(path);
        if (localPath.startsWith("file://"))
            localPath = localPath.slice(7);
        if (localPath.startsWith("~"))
            localPath = Paths.absolutePath(localPath);

        return CUtils.fileExists(localPath) ? "file://" + localPath : "";
    }

    function _hasIconExtension(path: string): bool {
        const lower = String(path).toLowerCase();
        for (let i = 1; i < iconExtensions.length; i++) {
            if (lower.endsWith(iconExtensions[i]))
                return true;
        }

        return false;
    }

    // Only accept real filesystem paths. image://icon/* still fails at arbitrary
    // sourceSize (e.g. 36x36 for dialog-information-symbolic) — never return those.
    function _normalisedResolvedIcon(path: string): string {
        if (!path)
            return "";
        const s = String(path);
        if (s.startsWith("image://icon/")) {
            const name = s.slice("image://icon/".length).split("?")[0];
            let manual = name ? _manualIcon(name) : "";
            if (manual)
                return manual;
            return s;
        }
        if (s.startsWith("/") || s.startsWith("file://") || s.startsWith("~"))
            return _fileIconUrl(s);
        return "";
    }

    function _themeIcon(icon: string): string {
        if (!icon)
            return "";

        let resolved = _manualIcon(icon);
        if (resolved)
            return resolved;

        let path = Quickshell.iconPath(icon, true);
        resolved = _normalisedResolvedIcon(path);
        if (resolved)
            return resolved;

        if (Quickshell.hasThemeIcon(icon)) {
            path = Quickshell.iconPath(icon, "");
            resolved = _normalisedResolvedIcon(path);
            if (resolved)
                return resolved;
        }

        if (icon.endsWith("-symbolic")) {
            resolved = _manualIcon(icon.slice(0, -9)) || _normalisedResolvedIcon(Quickshell.iconPath(icon.slice(0, -9), true));
            if (resolved)
                return resolved;
        }

        return "";
    }

    function iconNameFromUrl(url: string): string {
        const s = String(url ?? "");
        if (s.startsWith("image://icon/"))
            return s.slice("image://icon/".length).split("?")[0];
        return "";
    }

    function _addIconName(names: var, seen: var, name: string): void {
        if (!name || seen[name])
            return;

        seen[name] = true;
        names.push(name);
    }

    function _iconNameVariants(icon: string): var {
        const names = [];
        const seen = ({});

        _addIconName(names, seen, icon);

        const lowercase = icon.toLowerCase();
        _addIconName(names, seen, lowercase);

        let base = icon;
        for (let i = 1; i < iconExtensions.length; i++) {
            const ext = iconExtensions[i];
            if (base.endsWith(ext)) {
                base = base.slice(0, -ext.length);
                _addIconName(names, seen, base);
                break;
            }
        }

        if (!base.endsWith("-symbolic")) {
            _addIconName(names, seen, base + "-symbolic");
        } else {
            _addIconName(names, seen, base.slice(0, -9));
        }

        if (!base.endsWith("_app") && !base.includes(".")) {
            _addIconName(names, seen, base + "_app");
            _addIconName(names, seen, base + "-app");
            _addIconName(names, seen, "org." + base + "." + base);
            _addIconName(names, seen, "org." + base + "." + base + "_app");
            _addIconName(names, seen, "com." + base + "." + base);
            _addIconName(names, seen, "io." + base + "." + base);
        }

        if (base.includes(".")) {
            const parts = base.split(".");
            const lastPart = parts[parts.length - 1];
            _addIconName(names, seen, lastPart);
            _addIconName(names, seen, lastPart.toLowerCase());
            if (lastPart.endsWith("_app"))
                _addIconName(names, seen, lastPart.slice(0, -4));
        }

        return names;
    }

    function _manualIcon(icon: string): string {
        if (!icon)
            return "";
        if (icon.startsWith("/") || icon.startsWith("file://") || icon.startsWith("~"))
            return _fileIconUrl(icon);

        const iconNames = _iconNameVariants(icon);
        const searchDirs = _getIconSearchDirs();

        for (let k = 0; k < iconNames.length; k++) {
            const currentIcon = iconNames[k];
            const firstExt = _hasIconExtension(currentIcon) ? 0 : 1;
            for (let i = 0; i < searchDirs.length; i++) {
                const dir = searchDirs[i];
                for (let j = firstExt; j < iconExtensions.length; j++) {
                    const fullPath = dir + currentIcon + iconExtensions[j];
                    if (CUtils.fileExists(fullPath))
                        return "file://" + fullPath;
                }
            }
        }

        return "";
    }

    function resolveIcon(icon: string, fallback: string): string {
        const key = (icon || "") + "\u001f" + (fallback || "");
        if (_iconResolveCache.hasOwnProperty(key))
            return _iconResolveCache[key];

        let resolved = _manualIcon(icon) || _themeIcon(icon) || _manualIcon(fallback) || _themeIcon(fallback);
        _iconResolveCache[key] = resolved;
        return resolved;
    }

    function getAppCategoryIcon(name: string, fallback: string): string {
        for (const iconConfig of GlobalConfig.bar.workspaces.windowIcons)
            if (matchIconConfig(name, iconConfig))
                return iconConfig.icon;

        const categories = DesktopEntries.heuristicLookup(name)?.categories;

        if (categories)
            for (const [key, value] of Object.entries(categoryIcons))
                if (categories.includes(key))
                    return value;
        return fallback;
    }

    function getNetworkIcon(strength: int, isSecure = false): string {
        if (isSecure) {
            if (strength >= 80)
                return "network_wifi_locked";
            if (strength >= 60)
                return "network_wifi_3_bar_locked";
            if (strength >= 40)
                return "network_wifi_2_bar_locked";
            if (strength >= 20)
                return "network_wifi_1_bar_locked";
            return "signal_wifi_0_bar";
        } else {
            if (strength >= 80)
                return "network_wifi";
            if (strength >= 60)
                return "network_wifi_3_bar";
            if (strength >= 40)
                return "network_wifi_2_bar";
            if (strength >= 20)
                return "network_wifi_1_bar";
            return "signal_wifi_0_bar";
        }
    }

    function getBluetoothIcon(icon: string): string {
        if (icon.includes("headset") || icon.includes("headphones"))
            return "headphones";
        if (icon.includes("audio"))
            return "speaker";
        if (icon.includes("phone"))
            return "smartphone";
        if (icon.includes("mouse"))
            return "mouse";
        if (icon.includes("keyboard"))
            return "keyboard";
        return "bluetooth";
    }

    function getWeatherIcon(code: string): string {
        if (weatherIcons.hasOwnProperty(code))
            return weatherIcons[code];
        return "air";
    }

    function getNotifIcon(summary: string, urgency: int): string {
        summary = summary.toLowerCase();
        if (summary.includes("reboot"))
            return "restart_alt";
        if (summary.includes("recording"))
            return "screen_record";
        if (summary.includes("battery"))
            return "power";
        if (summary.includes("screenshot"))
            return "screenshot_monitor";
        if (summary.includes("welcome"))
            return "waving_hand";
        if (summary.includes("time") || summary.includes("a break"))
            return "schedule";
        if (summary.includes("installed"))
            return "download";
        if (summary.includes("update"))
            return "update";
        if (summary.includes("unable to"))
            return "deployed_code_alert";
        if (summary.includes("profile"))
            return "person";
        if (summary.includes("file"))
            return "folder_copy";
        if (urgency === NotificationUrgency.Critical)
            return "release_alert";
        return "chat";
    }

    function getVolumeIcon(volume: real, isMuted: bool): string {
        if (isMuted)
            return "no_sound";
        if (volume >= 0.5)
            return "volume_up";
        if (volume > 0)
            return "volume_down";
        return "volume_mute";
    }

    function getMicVolumeIcon(volume: real, isMuted: bool): string {
        if (!isMuted && volume > 0)
            return "mic";
        return "mic_off";
    }

    function getSpecialWsIcon(name: string): string {
        name = name.toLowerCase().slice("special:".length);

        for (const iconConfig of GlobalConfig.bar.workspaces.specialWorkspaceIcons)
            if (matchIconConfig(name, iconConfig))
                return iconConfig.icon;

        if (name === "special")
            return "star";
        if (name === "communication")
            return "forum";
        if (name === "music")
            return "music_cast";
        if (name === "todo")
            return "checklist";
        if (name === "sysmon")
            return "monitor_heart";
        return name[0].toUpperCase();
    }

    function getTrayIcon(id: string, icon: string): string {
        if (!icon)
            return "";

        for (const sub of GlobalConfig.bar.tray.iconSubs)
            if (sub.id === id)
                return sub.image ? Qt.resolvedUrl(sub.image) : Quickshell.iconPath(sub.icon);

        if (icon.includes("?path=")) {
            const [name, path] = icon.split("?path=");
            return Qt.resolvedUrl(`${path}/${name.slice(name.lastIndexOf("/") + 1)}`);
        }

        if (icon.startsWith("file:") || icon.startsWith("http:") || icon.startsWith("https:") || icon.startsWith("image:"))
            return icon;

        if (icon.startsWith("/"))
            return "file://" + icon;

        const resolved = Quickshell.iconPath(icon);
        return resolved !== "" ? resolved : icon;
    }

    function getBatteryIcon(charge: int): string {
        if (charge > 0 && charge < 5)
            return "battery_0_bar";
        if (charge >= 5 && charge < 20)
            return "battery_1_bar";
        if (charge >= 20 && charge < 35)
            return "battery_2_bar";
        if (charge >= 35 && charge < 50)
            return "battery_3_bar";
        if (charge >= 50 && charge < 65)
            return "battery_4_bar";
        if (charge >= 65 && charge < 80)
            return "battery_5_bar";
        if (charge >= 80 && charge < 95)
            return "battery_6_bar";
        if (charge >= 95)
            return "battery_full";
        return "battery_alert";
    }
}
