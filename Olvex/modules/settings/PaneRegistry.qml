pragma Singleton

import "../../components"
import "../../components/controls"
import "../../components/containers"
import QtQuick
import qs.services

QtObject {
    id: root

    // Bento category registry. Paths relative to modules/controlcenter/
    // accentRole: key on Colours.palette
    // Grid: 6 cols. Dual look heroes with asymmetric widths (true bento).
    //   r0–1: Appearance w6h2
    //   r2:   Network w3h1 | Sound w3h1
    //   r3:   Taskbar w2h1 | Notifs w2h1 | Panels w2h1
    //   r4:   Power w2h1   | System w2h1 | About w2h1
    readonly property var categories: [
        {
            id: "appearance",
            label: "appearance",
            icon: "palette",
            title: "Appearance",
            sub: "Theme, colors & fonts",
            accentRole: "m3tertiary",
            kind: "appearance",
            c: 0,
            r: 0,
            w: 6,
            h: 2,
            component: "appearance/AppearancePage.qml"
        },
        {
            id: "network",
            label: "network",
            icon: "wifi",
            title: "Network",
            sub: "Wi‑Fi and Bluetooth",
            accentRole: "m3primary",
            kind: "network",
            c: 0,
            r: 2,
            w: 3,
            h: 1,
            component: "network/NetworkPage.qml"
        },
        {
            id: "sound",
            label: "sound",
            icon: "volume_up",
            title: "Sound",
            sub: "Audio and inputs",
            accentRole: "m3secondary",
            kind: "sound",
            c: 3,
            r: 2,
            w: 3,
            h: 1,
            component: "sound/SoundPage.qml"
        },
        {
            id: "taskbar",
            label: "taskbar",
            icon: "dock",
            title: "Taskbar",
            sub: "Bottom dock & items",
            accentRole: "m3primary",
            kind: "taskbar",
            c: 0,
            r: 3,
            w: 2,
            h: 1,
            component: "taskbar/TaskbarPage.qml"
        },
        {
            id: "notifs",
            label: "notifs",
            icon: "notifications",
            title: "Notifications",
            sub: "Do not disturb",
            accentRole: "m3primary",
            kind: "notifs",
            c: 2,
            r: 3,
            w: 2,
            h: 1,
            component: "notifications/NotificationsPage.qml"
        },
        {
            id: "panels",
            label: "panels",
            icon: "dashboard_customize",
            title: "Panels",
            sub: "Layout & behavior",
            accentRole: "m3secondary",
            kind: "panels",
            c: 4,
            r: 3,
            w: 2,
            h: 1,
            component: "panels/PanelsPage.qml"
        },
        {
            id: "power",
            label: "power",
            icon: "battery_charging_full",
            title: "Power",
            sub: "Sleep & idle",
            accentRole: "m3secondary",
            kind: "power",
            c: 0,
            r: 4,
            w: 2,
            h: 1,
            component: "power/PowerPage.qml"
        },
        {
            id: "system",
            label: "system",
            icon: "tune",
            title: "System",
            sub: "Displays, clock & apps",
            accentRole: "m3primary",
            kind: "system",
            c: 2,
            r: 4,
            w: 2,
            h: 1,
            component: "system/SystemPage.qml"
        },
        {
            id: "about",
            label: "about",
            icon: "deployed_code",
            title: "About Olvex",
            sub: "Version, system info and links",
            accentRole: "m3primary",
            kind: "about",
            c: 4,
            r: 4,
            w: 2,
            h: 1,
            component: "about/AboutPage.qml"
        }
    ]

    readonly property int count: categories.length

    readonly property var labels: {
        const result = [];
        for (let i = 0; i < categories.length; i++)
            result.push(categories[i].id);
        return result;
    }

    // Legacy: panes list for old rail code
    readonly property var panes: categories

    function getByIndex(index) {
        if (index >= 0 && index < categories.length)
            return categories[index];
        return null;
    }

    function getIndexByLabel(label) {
        for (let i = 0; i < categories.length; i++) {
            if (categories[i].label === label || categories[i].id === label)
                return i;
        }
        return -1;
    }

    function getByLabel(label) {
        return getByIndex(getIndexByLabel(label));
    }

    function getById(id) {
        for (let i = 0; i < categories.length; i++) {
            if (categories[i].id === id)
                return categories[i];
        }
        return null;
    }

    function accentFor(cat) {
        if (!cat)
            return Colours.palette.m3primary;
        const role = cat.accentRole || "m3primary";
        return Colours.palette[role] || Colours.palette.m3primary;
    }

    // ── Deep Sub-settings Search Index ─────────────────────────────────
    // Complete catalog of all 9 pages, sub-sections, and individual options
    readonly property var searchItems: [
        // ── Appearance ──
        {
            id: "appearance_theme",
            pageId: "appearance",
            sectionId: "theme",
            title: "Theme & Colors",
            sub: "Dark/light mode, dynamic wallpaper color schemes, and contrast",
            breadcrumb: "Settings › Appearance › Theme",
            icon: "contrast",
            accentRole: "m3tertiary",
            keywords: "dark light theme color palette material scheme tint wallpaper contrast mode accent"
        },
        {
            id: "appearance_transparency",
            pageId: "appearance",
            sectionId: "transparency",
            title: "Transparency & Blur",
            sub: "Layer opacity, background blur effects, and glassmorphism",
            breadcrumb: "Settings › Appearance › Transparency",
            icon: "opacity",
            accentRole: "m3tertiary",
            keywords: "transparency blur glass glassmorphism opacity background frost opaque alpha"
        },
        {
            id: "appearance_fonts",
            pageId: "appearance",
            sectionId: "fonts",
            title: "Fonts & Typography",
            sub: "UI font family, font size scaling, and monospace font",
            breadcrumb: "Settings › Appearance › Fonts",
            icon: "font_download",
            accentRole: "m3tertiary",
            keywords: "font fonts typography text size scale family mono sans serif outfit inter roboto"
        },
        {
            id: "appearance_shape",
            pageId: "appearance",
            sectionId: "shape",
            title: "Shape & Spacing",
            sub: "Corner rounding radius, element padding, and grid spacing",
            breadcrumb: "Settings › Appearance › Shape",
            icon: "rounded_corner",
            accentRole: "m3tertiary",
            keywords: "shape corner radius rounding padding spacing border curves round"
        },
        {
            id: "appearance_motion",
            pageId: "appearance",
            sectionId: "motion",
            title: "Motion & Animations",
            sub: "Animation speed, durations, spring physics, and transitions",
            breadcrumb: "Settings › Appearance › Motion",
            icon: "animation",
            accentRole: "m3tertiary",
            keywords: "motion animation animations speed duration spring easing transition effect disable fast slow"
        },
        {
            id: "appearance_wallpapers",
            pageId: "appearance",
            sectionId: "wallpapers",
            title: "Wallpapers",
            sub: "Desktop wallpaper background, slideshow cycling, and fill mode",
            breadcrumb: "Settings › Appearance › Wallpapers",
            icon: "wallpaper",
            accentRole: "m3tertiary",
            keywords: "wallpaper background image picture photo cycle slideshow interval fit fill lockscreen"
        },
        {
            id: "appearance_lockscreen",
            pageId: "appearance",
            sectionId: "lockscreen",
            title: "Lockscreen Styling",
            sub: "Lockscreen clock format, unlock PAM auth, and blur intensity",
            breadcrumb: "Settings › Appearance › Lockscreen",
            icon: "lock",
            accentRole: "m3tertiary",
            keywords: "lock lockscreen authentication pam password security screenlock login auth"
        },

        // ── Network ──
        {
            id: "network_wifi",
            pageId: "network",
            sectionId: "wifi",
            title: "Wi-Fi Networks",
            sub: "Wireless networks, SSID selection, and Wi-Fi password connection",
            breadcrumb: "Settings › Network › Wi-Fi",
            icon: "wifi",
            accentRole: "m3primary",
            keywords: "wifi wi-fi wireless ssid hotspot internet network connect password wlan wpa access point"
        },
        {
            id: "network_bluetooth",
            pageId: "network",
            sectionId: "bluetooth",
            title: "Bluetooth Devices",
            sub: "Pair wireless devices, headsets, mice, and keyboards",
            breadcrumb: "Settings › Network › Bluetooth",
            icon: "bluetooth",
            accentRole: "m3primary",
            keywords: "bluetooth bt pair pairing headset headphones mouse keyboard audio device wireless connect"
        },
        {
            id: "network_details",
            pageId: "network",
            sectionId: "details",
            title: "Ethernet & VPN",
            sub: "Wired network connection, IP address, gateway, DNS, and VPN tunnels",
            breadcrumb: "Settings › Network › Ethernet",
            icon: "settings_ethernet",
            accentRole: "m3primary",
            keywords: "ethernet lan wire wired ip address gateway dns vpn tunnel network connection wireguard openvpn"
        },

        // ── Sound ──
        {
            id: "sound_output",
            pageId: "sound",
            sectionId: "output",
            title: "Audio Output",
            sub: "Speakers, headphones, default output device, and master volume",
            breadcrumb: "Settings › Sound › Output",
            icon: "volume_up",
            accentRole: "m3secondary",
            keywords: "sound audio volume speaker headphones output sink device master mute level balance"
        },
        {
            id: "sound_input",
            pageId: "sound",
            sectionId: "input",
            title: "Audio Input",
            sub: "Microphone selection, input level, and recording devices",
            breadcrumb: "Settings › Sound › Input",
            icon: "mic",
            accentRole: "m3secondary",
            keywords: "mic microphone input recording voice audio level sound source gain volume"
        },
        {
            id: "sound_apps",
            pageId: "sound",
            sectionId: "apps",
            title: "App Volume Streams",
            sub: "Per-application volume sliders and individual mute controls",
            breadcrumb: "Settings › Sound › App Streams",
            icon: "equalizer",
            accentRole: "m3secondary",
            keywords: "app apps applications per-app stream volume mixer equalizer mute streams"
        },
        {
            id: "sound_uisounds",
            pageId: "sound",
            sectionId: "uisounds",
            title: "UI Sounds",
            sub: "System feedback sounds, click chimes, and notification tones",
            breadcrumb: "Settings › Sound › UI Sounds",
            icon: "music_note",
            accentRole: "m3secondary",
            keywords: "ui sounds sound effects chime beep audio feedback tone ring volume enable"
        },
        {
            id: "sound_behavior",
            pageId: "sound",
            sectionId: "behavior",
            title: "Sound Behavior & Visualizer",
            sub: "Audio ducking, PipeWire backend, and Cava equalizer visualizer",
            breadcrumb: "Settings › Sound › Behavior",
            icon: "tune",
            accentRole: "m3secondary",
            keywords: "sound audio pipewire cava visualizer equalizer ducking latency behavior backend"
        },

        // ── Taskbar ──
        {
            id: "taskbar_behavior",
            pageId: "taskbar",
            sectionId: "behavior",
            title: "Taskbar & Dock Behavior",
            sub: "Position (top/bottom/left/right), autohide, and floating bar",
            breadcrumb: "Settings › Taskbar › Behavior",
            icon: "dock",
            accentRole: "m3primary",
            keywords: "taskbar dock bar position top bottom left right autohide floating size height width margin layer"
        },
        {
            id: "taskbar_quickorb",
            pageId: "taskbar",
            sectionId: "quickorb",
            title: "Quick Orb",
            sub: "Start button icon, quick orb style, and morph animations",
            breadcrumb: "Settings › Taskbar › Quick Orb",
            icon: "adjust",
            accentRole: "m3primary",
            keywords: "orb quick orb start button menu icon logo trigger launcher position style"
        },
        {
            id: "taskbar_workspaces",
            pageId: "taskbar",
            sectionId: "workspaces",
            title: "Workspaces",
            sub: "Workspace indicators, numbering, and active dot animation",
            breadcrumb: "Settings › Taskbar › Workspaces",
            icon: "grid_view",
            accentRole: "m3primary",
            keywords: "workspaces workspace virtual desktop pager hyprland indicator number dots active switch"
        },
        {
            id: "taskbar_widgets",
            pageId: "taskbar",
            sectionId: "widgets",
            title: "Widgets & System Tray",
            sub: "Clock widget format, tray icons, and status indicators",
            breadcrumb: "Settings › Taskbar › Widgets",
            icon: "widgets",
            accentRole: "m3primary",
            keywords: "widgets tray system tray status icons clock format date battery weather network audio"
        },
        {
            id: "taskbar_bottomPanel",
            pageId: "taskbar",
            sectionId: "bottomPanel",
            title: "Bottom Panel",
            sub: "Bottom quick shelf, pinned apps, and quick actions",
            breadcrumb: "Settings › Taskbar › Bottom Panel",
            icon: "bottom_panel_open",
            accentRole: "m3primary",
            keywords: "bottom panel shelf dock drawer actions shortcuts pinned quick apps"
        },

        // ── Notifications ──
        {
            id: "notifs_behavior",
            pageId: "notifs",
            sectionId: "behavior",
            title: "Do Not Disturb & General",
            sub: "DND mode, notification history, and silent alerts",
            breadcrumb: "Settings › Notifications › General",
            icon: "notifications",
            accentRole: "m3primary",
            keywords: "notifications notifs dnd do not disturb quiet silent history mute alerts sounds center"
        },
        {
            id: "notifs_toasts",
            pageId: "notifs",
            sectionId: "toasts",
            title: "Toast Notifications",
            sub: "Toast screen corner, banner timeout duration, and urgency levels",
            breadcrumb: "Settings › Notifications › Toasts",
            icon: "campaign",
            accentRole: "m3primary",
            keywords: "toast toasts popups banners timeout duration corner position urgency action dismiss"
        },

        // ── Panels & Drawers ──
        {
            id: "panels_dashboard",
            pageId: "panels",
            sectionId: "dashboard",
            title: "Dashboard Panel",
            sub: "Control center, quick toggles, media player, and sliders",
            breadcrumb: "Settings › Panels › Dashboard",
            icon: "dashboard",
            accentRole: "m3secondary",
            keywords: "dashboard control center quick settings toggles media brightness sliders volume drawer panel"
        },
        {
            id: "panels_launcher",
            pageId: "panels",
            sectionId: "launcher",
            title: "App Launcher",
            sub: "Application search grid, calculator queries, and fuzzy search",
            breadcrumb: "Settings › Panels › Launcher",
            icon: "search",
            accentRole: "m3secondary",
            keywords: "launcher app apps applications search grid fuzzy search calculator qalculate math runner"
        },
        {
            id: "panels_osd",
            pageId: "panels",
            sectionId: "osd",
            title: "On-Screen Display (OSD)",
            sub: "Volume, brightness, and keyboard backlight flyout popups",
            breadcrumb: "Settings › Panels › Flyouts",
            icon: "volume_up",
            accentRole: "m3secondary",
            keywords: "osd flyout flyouts volume brightness backlight overlay popup hud notification level indicator"
        },

        // ── Power & Idle ──
        {
            id: "power_battery",
            pageId: "power",
            sectionId: "battery",
            title: "Battery & Power Profile",
            sub: "Power profiles (performance, balanced, power saver) and status",
            breadcrumb: "Settings › Power › Battery",
            icon: "battery_charging_full",
            accentRole: "m3secondary",
            keywords: "battery power performance balanced power-saver energy charging percentage health profile governor"
        },
        {
            id: "power_idle",
            pageId: "power",
            sectionId: "idle",
            title: "Idle & Sleep Timeouts",
            sub: "Screen dimming timeout, display turn off, and system suspend",
            breadcrumb: "Settings › Power › Idle",
            icon: "bedtime",
            accentRole: "m3secondary",
            keywords: "idle sleep timeout dim turn off monitor suspend standby hibernate lock delay screen timeout"
        },
        {
            id: "power_behavior",
            pageId: "power",
            sectionId: "behavior",
            title: "Hardware Buttons & Lid",
            sub: "Laptop lid close action, power button, and sleep switch",
            breadcrumb: "Settings › Power › Hardware",
            icon: "power_settings_new",
            accentRole: "m3secondary",
            keywords: "lid laptop close button power switch shutdown suspend lock action sleep press"
        },

        // ── System Settings ──
        {
            id: "system_display",
            pageId: "system",
            sectionId: "display",
            title: "Displays & Resolution",
            sub: "Display resolution, refresh rate Hz, scaling %, and multi-monitor",
            breadcrumb: "Settings › System › Displays",
            icon: "desktop_windows",
            accentRole: "m3primary",
            keywords: "display monitor screen resolution refresh rate hz scale scaling 4k 1440p 1080p hdmi dp output"
        },
        {
            id: "system_clock",
            pageId: "system",
            sectionId: "clock",
            title: "Clock & Date Format",
            sub: "12/24 hour time format, seconds display, and date styling",
            breadcrumb: "Settings › System › Clock",
            icon: "schedule",
            accentRole: "m3primary",
            keywords: "clock time date 24h 12h seconds calendar timezone format hour minute am pm"
        },
        {
            id: "system_keybinds",
            pageId: "system",
            sectionId: "keybinds",
            title: "Keybindings & Shortcuts",
            sub: "Hyprland window manager shortcuts and shell hotkeys",
            breadcrumb: "Settings › System › Keybindings",
            icon: "keyboard",
            accentRole: "m3primary",
            keywords: "keybinds keybindings shortcuts keyboard hotkeys super bind hyprland keys combinations"
        },
        {
            id: "system_media",
            pageId: "system",
            sectionId: "media",
            title: "Media Controls & MPRIS",
            sub: "MPRIS media player controls and album art display",
            breadcrumb: "Settings › System › Media",
            icon: "play_circle",
            accentRole: "m3primary",
            keywords: "media music mpris spotify player song playback controls art album track artist"
        },
        {
            id: "system_advanced",
            pageId: "system",
            sectionId: "advanced",
            title: "Advanced & Developer",
            sub: "Shell debugging, GPU rendering loop, and system logs",
            breadcrumb: "Settings › System › Advanced",
            icon: "build",
            accentRole: "m3primary",
            keywords: "advanced developer debug logging gpu render crash reports config inspector performance"
        },

        // ── About ──
        {
            id: "about_system",
            pageId: "about",
            sectionId: "",
            title: "About Olvex Shell",
            sub: "Version, Linux kernel, CPU/GPU/RAM specs, and maintainer info",
            breadcrumb: "Settings › About",
            icon: "deployed_code",
            accentRole: "m3primary",
            keywords: "about version olvex system specs linux kernel cpu gpu ram maintainer info quickshell license"
        }
    ]

    function search(query) {
        if (!query || query.trim() === "")
            return [];
        
        const q = query.trim().toLowerCase();
        const terms = q.split(/\s+/).filter(t => t.length > 0);
        const results = [];

        for (let i = 0; i < searchItems.length; i++) {
            const item = searchItems[i];
            const title = item.title.toLowerCase();
            const sub = item.sub.toLowerCase();
            const breadcrumb = item.breadcrumb.toLowerCase();
            const kw = (item.keywords || "").toLowerCase();
            const pageId = (item.pageId || "").toLowerCase();
            const sectionId = (item.sectionId || "").toLowerCase();

            let score = 0;

            // 1. Exact full query matches
            if (title === q) {
                score += 160;
            } else if (title.startsWith(q)) {
                score += 110;
            } else if (title.includes(q)) {
                score += 75;
            }

            if (pageId === q || (sectionId && sectionId === q)) {
                score += 90;
            }

            if (sub.includes(q)) {
                score += 45;
            }

            if (breadcrumb.includes(q)) {
                score += 35;
            }

            if (kw.includes(q)) {
                score += 55;
            }

            // 2. Individual term scoring
            let termMatches = 0;
            for (let j = 0; j < terms.length; j++) {
                const term = terms[j];
                let matched = false;

                if (title.includes(term)) {
                    score += 40;
                    matched = true;
                }
                if (kw.includes(term)) {
                    score += 30;
                    matched = true;
                }
                if (sub.includes(term)) {
                    score += 20;
                    matched = true;
                }
                if (breadcrumb.includes(term)) {
                    score += 15;
                    matched = true;
                }

                if (matched)
                    termMatches++;
            }

            // Bonus if all terms matched
            if (terms.length > 1 && termMatches === terms.length) {
                score += 50;
            }

            if (score > 0) {
                results.push({
                    id: item.id,
                    pageId: item.pageId,
                    sectionId: item.sectionId,
                    title: item.title,
                    sub: item.sub,
                    breadcrumb: item.breadcrumb,
                    icon: item.icon,
                    accentRole: item.accentRole,
                    score: score
                });
            }
        }

        results.sort((a, b) => b.score - a.score);
        return results;
    }
}
