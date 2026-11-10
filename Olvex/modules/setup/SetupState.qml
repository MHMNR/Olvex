import QtQuick
import Quickshell.Io
import Olvex.Config
import qs.services
import qs.utils

// Pure local wizard state + mock data. No system access whatsoever.
QtObject {
    id: root

    // ── Unified Theme Surface Colors (matching Settings App & Dashboard) ──
    readonly property color windowBackground: Qt.alpha(Colours.shellTint, transparency ? Colours.transparencyBase : 1.0)

    function cardColor(layerLevel) {
        const lvl = layerLevel ?? 2;
        if (transparency) {
            return Colours.layer(Colours.palette.m3surfaceContainer, lvl);
        }
        if (Colours.light) {
            return Colours.opaqueLightContainer(lvl);
        }
        return Colours.alterColour(Colours.palette.m3surfaceContainer, 1.0, lvl);
    }

    function cardHoverColor(layerLevel) {
        const lvl = layerLevel ?? 3;
        if (transparency) {
            return Colours.layer(Colours.palette.m3surfaceContainerHighest, lvl);
        }
        if (Colours.light) {
            return Colours.opaqueLightContainer(lvl);
        }
        return Colours.alterColour(Colours.palette.m3surfaceContainerHighest, 1.0, lvl);
    }

    // ── Navigation ──
    property int step: 0
    readonly property int stepCount: 6   // 0 hello · 1 display · 2 theme · 3 apps · 4 shortcuts · 5 finish

    // ── Choices ──
    property real scale: (DisplayManager && DisplayManager.monitors && DisplayManager.monitors.length > 0) ? (DisplayManager.monitors[0].scale || 1.0) : 1.0
    property int themeMode: {
        const m = (GlobalConfig.appearance && GlobalConfig.appearance.themeMode) ? GlobalConfig.appearance.themeMode : "dark";
        return m === "light" ? 0 : (m === "auto" ? 2 : 1);
    }
    property int wallpaperIdx: findCurrentWallpaperIdx()
    property bool wallpaperApplied: wallpaperIdx >= 0
    property bool transparency: (GlobalConfig.appearance && GlobalConfig.appearance.transparency) ? GlobalConfig.appearance.transparency.enabled : true
    property bool blur: (GlobalConfig.appearance && GlobalConfig.appearance.transparency) ? GlobalConfig.appearance.transparency.blur : true
    property string selectedTerminal: (GlobalConfig.general && GlobalConfig.general.apps && GlobalConfig.general.apps.terminal && GlobalConfig.general.apps.terminal.length > 0) ? GlobalConfig.general.apps.terminal[0] : "kitty"
    property string selectedBrowser: "firefox"
    property string selectedFileManager: (GlobalConfig.general && GlobalConfig.general.apps && GlobalConfig.general.apps.explorer && GlobalConfig.general.apps.explorer.length > 0) ? GlobalConfig.general.apps.explorer[0] : "thunar"
    property var triedKeys: ({})              // shortcut-tour progress

    function findCurrentWallpaperIdx() {
        if (!root.wallpapers) return -1;
        const cur = (typeof Wallpapers !== "undefined" && Wallpapers.actualCurrent) ? Wallpapers.actualCurrent : "";
        if (!cur) return -1;
        for (let i = 0; i < root.wallpapers.length; i++) {
            if (root.wallpapers[i].path === cur)
                return i;
        }
        return -1;
    }

    function formatWallpaperName(filename) {
        let base = filename.replace(/\.[^/.]+$/, "");
        base = base.replace(/[-_]+/g, " ").trim();
        return base.replace(/\b\w/g, c => c.toUpperCase());
    }

    function hashHue(str) {
        let hash = 0;
        for (let i = 0; i < str.length; i++) {
            hash = (hash << 5) - hash + str.charCodeAt(i);
            hash |= 0;
        }
        return Math.abs(hash % 100) / 100.0;
    }

    function mergeDiscoveredWallpapers(filePaths) {
        const existingPaths = new Set(root.wallpapers.map(w => w.path));
        const extra = [];
        for (let i = 0; i < filePaths.length; i++) {
            const p = filePaths[i].trim();
            if (!p || existingPaths.has(p))
                continue;
            const parts = p.split("/");
            const fn = parts[parts.length - 1];
            extra.push({
                id: fn.replace(/[^a-zA-Z0-9]/g, "_").toLowerCase(),
                name: formatWallpaperName(fn),
                path: p,
                hue: hashHue(fn)
            });
        }
        if (extra.length > 0) {
            root.wallpapers = root.wallpapers.concat(extra);
            const curIdx = root.findCurrentWallpaperIdx();
            if (curIdx >= 0) {
                root.wallpaperIdx = curIdx;
                root.wallpaperApplied = true;
            }
        }
    }

    // ── Available Apps (Installed at TOP · uninstalled below with pkg name) ──
    property var availableTerminals: [
        { id: "kitty", label: "Kitty", installed: true },
        { id: "foot", label: "Foot", installed: true },
        { id: "alacritty", label: "Alacritty", installed: false, pkg: "alacritty" },
        { id: "ghostty", label: "Ghostty", installed: false, pkg: "ghostty-bin" },
        { id: "wezterm", label: "WezTerm", installed: false, pkg: "wezterm" },
        { id: "konsole", label: "Konsole", installed: false, pkg: "konsole" },
        { id: "xterm", label: "XTerm", installed: false, pkg: "xterm" }
    ]
    property var availableBrowsers: [
        { id: "firefox", label: "Firefox", installed: true },
        { id: "chromium", label: "Chromium", installed: true },
        { id: "zen-browser", label: "Zen Browser", installed: false, pkg: "zen-browser-bin" },
        { id: "google-chrome", label: "Google Chrome", installed: false, pkg: "google-chrome" },
        { id: "brave", label: "Brave", installed: false, pkg: "brave-bin" },
        { id: "librewolf", label: "LibreWolf", installed: false, pkg: "librewolf-bin" }
    ]
    property var availableFileManagers: [
        { id: "thunar", label: "Thunar", installed: true },
        { id: "dolphin", label: "Dolphin", installed: false, pkg: "dolphin" },
        { id: "nautilus", label: "Nautilus", installed: false, pkg: "nautilus" },
        { id: "nemo", label: "Nemo", installed: false, pkg: "nemo" },
        { id: "pcmanfm", label: "PCManFM", installed: false, pkg: "pcmanfm" }
    ]

    function indexOfAppId(list, id) {
        if (!list) return 0;
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id)
                return i;
        }
        return 0;
    }

    // ── Mock data (replaced by backend sockets later) ──
    readonly property var mockMonitors: [
        { name: "DP-1", width: 2560, height: 1440, refreshRate: 165 }
    ]
    property var wallpapers: [
        {
            id: "sunset_overlook",
            name: qsTr("Sunset Overlook"),
            path: `${Paths.pictures}/Wallpapers/sunset-overlook.jpg`,
            hue: 0.69
        },
        {
            id: "japan_street",
            name: qsTr("Japan Street"),
            path: `${Paths.pictures}/Wallpapers/japan-street.png`,
            hue: 0.60
        },
        {
            id: "mount_fuji",
            name: qsTr("Mount Fuji"),
            path: `${Paths.pictures}/Wallpapers/mount-fuji.png`,
            hue: 0.83
        },
        {
            id: "nocturnal_forest",
            name: qsTr("Nocturnal Forest"),
            path: `${Paths.pictures}/Wallpapers/nocturnal-forest.png`,
            hue: 0.59
        },
        {
            id: "crimson_night",
            name: qsTr("Crimson Night"),
            path: `${Paths.pictures}/Wallpapers/crimson-night.png`,
            hue: 0.97
        },
        {
            id: "riverside_twilight",
            name: qsTr("Riverside Twilight"),
            path: `${Paths.pictures}/Wallpapers/riverside-twilight.png`,
            hue: 0.62
        }
    ]
    readonly property var themeModeNames: ["Light", "Dark", "Auto"]
    readonly property var themeModeIds: ["light", "dark", "auto"]

    // Fake M3-ish tonal palette from a hue (preview swatches only).
    function tone(hue: real, s: real, l: real): color {
        return Qt.hsla(((hue % 1) + 1) % 1, s, l, 1);
    }

    function palette(hue) {
        const dark = root.themeMode !== 0;
        return [
            { label: "Primary", color: tone(hue, 0.55, dark ? 0.72 : 0.42) },
            { label: "Secondary", color: tone(hue + 0.04, 0.28, dark ? 0.64 : 0.46) },
            { label: "Tertiary", color: tone(hue + 0.16, 0.42, dark ? 0.70 : 0.44) },
            { label: "Surface", color: tone(hue, 0.14, dark ? 0.13 : 0.94) }
        ];
    }

    function markTried(id) {
        const copy = Object.assign({}, root.triedKeys);
        copy[id] = true;
        root.triedKeys = copy;
    }

    function refreshInstalledApps(foundSet) {
        function mapList(list) {
            return list.map(item => {
                const isInst = foundSet.has(item.id);
                return Object.assign({}, item, { installed: isInst });
            });
        }
        availableTerminals = mapList(availableTerminals);
        availableBrowsers = mapList(availableBrowsers);
        availableFileManagers = mapList(availableFileManagers);
    }

    property Process checkInstalledProc: Process {
        command: ["sh", "-c", "which kitty foot alacritty ghostty wezterm konsole xterm firefox chromium zen-browser google-chrome brave librewolf thunar dolphin nautilus nemo pcmanfm 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text) return;
                const lines = text.trim().split("\n");
                const found = new Set();
                for (let line of lines) {
                    const base = line.trim().split("/").pop();
                    if (base) found.add(base);
                }
                root.refreshInstalledApps(found);
            }
        }
    }

    property var shortcutBinds: ({
        "launcher": ["Super"],
        "drawers": ["Super", "K"],
        "clipboard": ["Super", "V"],
        "screenshot": ["Super", "Shift", "S"],
        "terminal": ["Super", "T"],
        "browser": ["Super", "B"],
        "fileManager": ["Super", "E"],
        "cheatsheet": ["Super", "/"]
    })

    property Process parseShortcutsProc: Process {
        command: ["python3", Qt.resolvedUrl("../cheatsheet/shortcuts_parser.py").toString().replace(/^file:\/\//, "")]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text) return;
                try {
                    const data = JSON.parse(text);
                    const map = Object.assign({}, root.shortcutBinds);
                    for (let sec of data) {
                        for (let item of (sec.items || [])) {
                            const t = (item.title || "").toLowerCase();
                            const mods = item.mods || [];
                            const key = item.key || "";
                            const combo = mods.concat(key && (key !== "Super" || !mods.includes("Super")) ? [key] : []);
                            if (t.includes("application launcher") && combo.length > 0) map["launcher"] = combo;
                            else if (t.includes("drawers") && combo.length > 0) map["drawers"] = combo;
                            else if (t.includes("clipboard history") && combo.length > 0) map["clipboard"] = combo;
                            else if (t.includes("screenshot region") && combo.length > 0) map["screenshot"] = combo;
                            else if (t.includes("terminal") && combo.length > 0) map["terminal"] = combo;
                            else if (t.includes("web browser") && combo.length > 0) map["browser"] = combo;
                            else if (t.includes("file manager") && combo.length > 0) map["fileManager"] = combo;
                            else if (t.includes("cheatsheet") && combo.length > 0) map["cheatsheet"] = combo;
                        }
                    }
                    root.shortcutBinds = map;
                } catch (e) {
                    console.log("[SetupState] Failed parsing shortcuts:", e);
                }
            }
        }
    }

    property Process scanWallpapersProc: Process {
        command: ["bash", "-c", `
            dir="${Paths.wallsdir}";
            if [ -d "$dir" ]; then
                find "$dir" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort
            fi
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text) return;
                const lines = text.trim().split("\n").filter(l => l.trim().length > 0);
                root.mergeDiscoveredWallpapers(lines);
            }
        }
    }

    Component.onCompleted: {
        checkInstalledProc.running = true;
        parseShortcutsProc.running = true;
        scanWallpapersProc.running = true;
    }
}
