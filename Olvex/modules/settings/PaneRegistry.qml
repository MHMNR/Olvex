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
    // Complete catalog of granular options, toggles, controls, and sub-sections across all 9 pages
    readonly property var searchItems: [
        // ═════════════════════════════════════════════════════════════════════
        // ── 1. APPEARANCE ───────────────────────────────────────────────────
        // ═════════════════════════════════════════════════════════════════════
        // ── Theme ──
        {
            id: "appearance_theme_mode",
            pageId: "appearance",
            sectionId: "theme",
            rowTitle: "Mode",
            title: "Dark / Light Mode",
            sub: "Follow fixed appearance (Dark / Light) or switch automatically",
            breadcrumb: "Settings › Appearance › Theme › Mode",
            icon: "contrast",
            accentRole: "m3tertiary",
            keywords: "dark light auto mode theme appearance night daylight switch fixed follow brightness",
            isOption: true
        },
        {
            id: "appearance_theme_scheme",
            pageId: "appearance",
            sectionId: "theme",
            rowTitle: "Scheme",
            title: "Color Scheme & Palette",
            sub: "Dynamic, Catppuccin, Gruvbox, Rosé Pine, Nord, Dracula, Monokai...",
            breadcrumb: "Settings › Appearance › Theme › Scheme",
            icon: "palette",
            accentRole: "m3tertiary",
            keywords: "scheme color palette theme dynamic catppuccin gruvbox rosepine nord dracula monokai oxocarbon material tint",
            isOption: true
        },
        {
            id: "appearance_theme_variant",
            pageId: "appearance",
            sectionId: "theme",
            rowTitle: "Variant",
            title: "Color Algorithm Variant",
            sub: "Tonal spot, vibrant, expressive, rainbow, fruit salad, monochrome algorithms",
            breadcrumb: "Settings › Appearance › Theme › Variant",
            icon: "color_lens",
            accentRole: "m3tertiary",
            keywords: "variant algorithm tonal spot vibrant expressive rainbow fruit salad monochrome seed palette color style",
            isOption: true
        },
        {
            id: "appearance_theme_nightlight",
            pageId: "appearance",
            sectionId: "theme",
            rowTitle: "Night light",
            title: "Night Light",
            sub: "Reduce blue light and eye strain with warm display color temperature",
            breadcrumb: "Settings › Appearance › Theme › Night light",
            icon: "bedtime",
            accentRole: "m3tertiary",
            keywords: "night light blue light eye strain warm display tint filter reading nightlight sleep sunset",
            isOption: true
        },
        {
            id: "appearance_theme_schedule",
            pageId: "appearance",
            sectionId: "theme",
            rowTitle: "Automatic schedule",
            title: "Automatic Schedule (Night Light)",
            sub: "Transition smoothly with sunset and sunrise",
            breadcrumb: "Settings › Appearance › Theme › Automatic schedule",
            icon: "schedule",
            accentRole: "m3tertiary",
            keywords: "automatic schedule sunset sunrise transition timer night light auto timer time",
            isOption: true
        },
        {
            id: "appearance_theme_temperature",
            pageId: "appearance",
            sectionId: "theme",
            rowTitle: "Color temperature",
            title: "Color Temperature (Warmth)",
            sub: "Adjust display warmth and Kelvin temperature (e.g. 4750K)",
            breadcrumb: "Settings › Appearance › Theme › Color temperature",
            icon: "thermostat",
            accentRole: "m3tertiary",
            keywords: "color temperature warmth kelvin display screen warm tint slider amber blue",
            isOption: true
        },
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

        // ── Transparency ──
        {
            id: "appearance_transparency_enable",
            pageId: "appearance",
            sectionId: "transparency",
            rowTitle: "Enable transparency",
            title: "Transparency Toggle",
            sub: "Make panels, drawers and popups translucent",
            breadcrumb: "Settings › Appearance › Transparency",
            icon: "opacity",
            accentRole: "m3tertiary",
            keywords: "transparency translucent glass glassmorphism opaque enable opacity alpha frost",
            isOption: true
        },
        {
            id: "appearance_transparency_blur",
            pageId: "appearance",
            sectionId: "transparency",
            rowTitle: "Enable blur",
            title: "Background Blur Effect",
            sub: "Blur background wallpaper behind translucent surfaces",
            breadcrumb: "Settings › Appearance › Transparency › Blur",
            icon: "blur_on",
            accentRole: "m3tertiary",
            keywords: "blur background frost gaussian fastblur glass glassmorphism enable backdrop",
            isOption: true
        },
        {
            id: "appearance_transparency_radius",
            pageId: "appearance",
            sectionId: "transparency",
            rowTitle: "Blur radius",
            title: "Blur Radius (1–30px)",
            sub: "Radius and spread of background blur effect",
            breadcrumb: "Settings › Appearance › Transparency › Radius",
            icon: "tune",
            accentRole: "m3tertiary",
            keywords: "blur radius spread size pixels intensity distance",
            isOption: true
        },
        {
            id: "appearance_transparency_passes",
            pageId: "appearance",
            sectionId: "transparency",
            rowTitle: "Blur intensity",
            title: "Blur Intensity & Quality",
            sub: "Number of blur shader passes (1–5)",
            breadcrumb: "Settings › Appearance › Transparency › Intensity",
            icon: "layers",
            accentRole: "m3tertiary",
            keywords: "blur intensity passes iterations quality strength depth",
            isOption: true
        },
        {
            id: "appearance_transparency_opacity",
            pageId: "appearance",
            sectionId: "transparency",
            rowTitle: "Base opacity",
            title: "Surface Base Opacity",
            sub: "Opacity of panel backgrounds and popup surfaces",
            breadcrumb: "Settings › Appearance › Transparency › Opacity",
            icon: "gradient",
            accentRole: "m3tertiary",
            keywords: "base opacity alpha transparency percent level surface background",
            isOption: true
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

        // ── Fonts ──
        {
            id: "appearance_fonts_sans",
            pageId: "appearance",
            sectionId: "fonts",
            rowTitle: "Sans-serif",
            title: "Primary UI Font (Sans-Serif)",
            sub: "Primary interface font family (Rubik, Inter, Roboto, Outfit...)",
            breadcrumb: "Settings › Appearance › Fonts › Sans-serif",
            icon: "font_download",
            accentRole: "m3tertiary",
            keywords: "font sans-serif ui typography typeface family rubik inter roboto outfit text sans",
            isOption: true
        },
        {
            id: "appearance_fonts_mono",
            pageId: "appearance",
            sectionId: "fonts",
            rowTitle: "Monospace",
            title: "Code & Terminal Font (Monospace)",
            sub: "Font for numbers, code and terminals (CaskaydiaCove, JetBrains Mono...)",
            breadcrumb: "Settings › Appearance › Fonts › Monospace",
            icon: "terminal",
            accentRole: "m3tertiary",
            keywords: "font monospace code terminal numbers caskaydia jetbrains fira iosevka hack mono type",
            isOption: true
        },
        {
            id: "appearance_fonts_clock",
            pageId: "appearance",
            sectionId: "fonts",
            rowTitle: "Lockscreen & Desktop Clock",
            title: "Large Clock Font",
            sub: "Typeface used for the large lockscreen & desktop time displays",
            breadcrumb: "Settings › Appearance › Fonts › Clock",
            icon: "schedule",
            accentRole: "m3tertiary",
            keywords: "font clock time lockscreen desktop large numbers typeface digits",
            isOption: true
        },
        {
            id: "appearance_fonts_install",
            pageId: "appearance",
            sectionId: "fonts",
            rowTitle: "Add Custom Font",
            title: "Install Custom Font",
            sub: "Install a TTF or OTF font file to ~/.local/share/fonts",
            breadcrumb: "Settings › Appearance › Fonts › Install",
            icon: "add",
            accentRole: "m3tertiary",
            keywords: "install add custom font ttf otf file upload import",
            isOption: true
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

        // ── Shape & Spacing ──
        {
            id: "appearance_shape_rounding",
            pageId: "appearance",
            sectionId: "shape",
            rowTitle: "Rounding scale",
            title: "Corner Rounding Radius Scale",
            sub: "Multiplier for all UI corner radii (0.5x – 1.5x)",
            breadcrumb: "Settings › Appearance › Shape › Rounding",
            icon: "rounded_corner",
            accentRole: "m3tertiary",
            keywords: "rounding radius corner curve shapes scale border rounded",
            isOption: true
        },
        {
            id: "appearance_shape_spacing",
            pageId: "appearance",
            sectionId: "shape",
            rowTitle: "Spacing scale",
            title: "Element Spacing Scale",
            sub: "Multiplier for gaps and gutters between UI elements",
            breadcrumb: "Settings › Appearance › Shape › Spacing",
            icon: "space_bar",
            accentRole: "m3tertiary",
            keywords: "spacing gaps gutters margins padding scale distance layout",
            isOption: true
        },
        {
            id: "appearance_shape_padding",
            pageId: "appearance",
            sectionId: "shape",
            rowTitle: "Padding scale",
            title: "Container Padding Scale",
            sub: "Multiplier for internal padding inside containers",
            breadcrumb: "Settings › Appearance › Shape › Padding",
            icon: "aspect_ratio",
            accentRole: "m3tertiary",
            keywords: "padding scale internal container inset margin",
            isOption: true
        },
        {
            id: "appearance_shape_drawer",
            pageId: "appearance",
            sectionId: "shape",
            rowTitle: "Drawer mode",
            title: "Drawer Screen Edge Mode (Hugging / Floating)",
            sub: "Hugging sticks panels to screen edges; Floating leaves a gap",
            breadcrumb: "Settings › Appearance › Shape › Drawer mode",
            icon: "align_horizontal_left",
            accentRole: "m3tertiary",
            keywords: "drawer mode hugging floating gap screen edge border detached attached",
            isOption: true
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

        // ── Motion ──
        {
            id: "appearance_motion_speed",
            pageId: "appearance",
            sectionId: "motion",
            rowTitle: "Animation speed",
            title: "Animation Duration Speed",
            sub: "Multiplier for all animation durations — lower is faster",
            breadcrumb: "Settings › Appearance › Motion › Speed",
            icon: "speed",
            accentRole: "m3tertiary",
            keywords: "animation speed duration motion spring easing fast slow timing",
            isOption: true
        },
        {
            id: "appearance_motion_disable",
            pageId: "appearance",
            sectionId: "motion",
            rowTitle: "No Animation",
            title: "Reduce Motion (Disable Animations)",
            sub: "Disable all animations globally for instant UI response",
            breadcrumb: "Settings › Appearance › Motion › Disable",
            icon: "motion_photos_off",
            accentRole: "m3tertiary",
            keywords: "no animation disable motion reduce turn off instant performance",
            isOption: true
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

        // ── Wallpapers ──
        {
            id: "appearance_wallpapers_select",
            pageId: "appearance",
            sectionId: "wallpapers",
            rowTitle: "Wallpaper",
            title: "Desktop Wallpaper Image",
            sub: "Set wallpaper background picture or select from collection",
            breadcrumb: "Settings › Appearance › Wallpapers",
            icon: "wallpaper",
            accentRole: "m3tertiary",
            keywords: "wallpaper background image picture desktop photo change select",
            isOption: true
        },
        {
            id: "appearance_wallpapers_cycle",
            pageId: "appearance",
            sectionId: "wallpapers",
            rowTitle: "Slideshow",
            title: "Wallpaper Slideshow Cycling",
            sub: "Automatically change desktop wallpaper at timed interval",
            breadcrumb: "Settings › Appearance › Wallpapers › Slideshow",
            icon: "autorenew",
            accentRole: "m3tertiary",
            keywords: "wallpaper slideshow cycle interval timer rotate random auto timer",
            isOption: true
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

        // ── Lockscreen ──
        {
            id: "appearance_lockscreen_style",
            pageId: "appearance",
            sectionId: "lockscreen",
            rowTitle: "Lockscreen",
            title: "Lockscreen Authentication & Clock",
            sub: "Lockscreen clock format, PAM password unlock, and blur",
            breadcrumb: "Settings › Appearance › Lockscreen",
            icon: "lock",
            accentRole: "m3tertiary",
            keywords: "lock lockscreen authentication pam password security screenlock login auth",
            isOption: true
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

        // ═════════════════════════════════════════════════════════════════════
        // ── 2. NETWORK ──────────────────────────────────────────────────────
        // ═════════════════════════════════════════════════════════════════════
        // ── Wi-Fi ──
        {
            id: "network_wifi_toggle",
            pageId: "network",
            sectionId: "wifi",
            rowTitle: "Wi‑Fi",
            title: "Wi-Fi Switch",
            sub: "Turn wireless network adapter on or off",
            breadcrumb: "Settings › Network › Wi-Fi",
            icon: "wifi",
            accentRole: "m3primary",
            keywords: "wifi wi-fi wireless toggle on off adapter wlan internet connect switch",
            isOption: true
        },
        {
            id: "network_wifi_scan",
            pageId: "network",
            sectionId: "wifi",
            rowTitle: "Scan",
            title: "Scan Available Wi-Fi Networks",
            sub: "Refresh and scan nearby wireless access points",
            breadcrumb: "Settings › Network › Wi-Fi › Scan",
            icon: "refresh",
            accentRole: "m3primary",
            keywords: "scan rescan refresh wifi wireless networks ssid access points nearby",
            isOption: true
        },
        {
            id: "network_wifi_saved",
            pageId: "network",
            sectionId: "wifi",
            rowTitle: "Saved Networks",
            title: "Saved Wi-Fi Networks & Profiles",
            sub: "Manage remembered wireless connections and network passwords",
            breadcrumb: "Settings › Network › Wi-Fi › Saved",
            icon: "bookmark",
            accentRole: "m3primary",
            keywords: "saved networks wifi profiles remembered passwords forget auto connect",
            isOption: true
        },
        {
            id: "network_wifi_add",
            pageId: "network",
            sectionId: "wifi",
            rowTitle: "Add Network",
            title: "Add Hidden Wi-Fi Network",
            sub: "Connect manually to a hidden SSID with WPA2/WPA3",
            breadcrumb: "Settings › Network › Wi-Fi › Add",
            icon: "add",
            accentRole: "m3primary",
            keywords: "add network hidden ssid manual wpa2 wpa3 enterprise custom join",
            isOption: true
        },
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

        // ── Bluetooth ──
        {
            id: "network_bluetooth_toggle",
            pageId: "network",
            sectionId: "bluetooth",
            rowTitle: "Bluetooth",
            title: "Bluetooth Switch",
            sub: "Enable or disable Bluetooth wireless adapter",
            breadcrumb: "Settings › Network › Bluetooth",
            icon: "bluetooth",
            accentRole: "m3primary",
            keywords: "bluetooth bt wireless radio toggle enable disable switch",
            isOption: true
        },
        {
            id: "network_bluetooth_pair",
            pageId: "network",
            sectionId: "bluetooth",
            rowTitle: "Pairing",
            title: "Pair New Bluetooth Device",
            sub: "Scan and pair wireless headsets, mice, and keyboards",
            breadcrumb: "Settings › Network › Bluetooth › Pair",
            icon: "bluetooth_searching",
            accentRole: "m3primary",
            keywords: "bluetooth pair pairing headset headphones mouse keyboard audio device wireless connect discoverable",
            isOption: true
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

        // ── Ethernet & VPN ──
        {
            id: "network_ethernet_info",
            pageId: "network",
            sectionId: "details",
            rowTitle: "Ethernet",
            title: "Ethernet Wired Connection",
            sub: "Wired network adapter, IP address, gateway, subnet, and DNS",
            breadcrumb: "Settings › Network › Ethernet",
            icon: "settings_ethernet",
            accentRole: "m3primary",
            keywords: "ethernet wired lan cable ip address gateway subnet dns connection speed mac",
            isOption: true
        },
        {
            id: "network_vpn_tunnel",
            pageId: "network",
            sectionId: "details",
            rowTitle: "VPN",
            title: "VPN Tunnels (WireGuard / OpenVPN)",
            sub: "Virtual Private Network secure tunnel connections",
            breadcrumb: "Settings › Network › VPN",
            icon: "vpn_key",
            accentRole: "m3primary",
            keywords: "vpn wireguard openvpn tunnel secure network proxy encrypted connection",
            isOption: true
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

        // ═════════════════════════════════════════════════════════════════════
        // ── 3. SOUND ────────────────────────────────────────────────────────
        // ═════════════════════════════════════════════════════════════════════
        // ── Output ──
        {
            id: "sound_output_volume",
            pageId: "sound",
            sectionId: "output",
            rowTitle: "Volume",
            title: "Master Output Volume",
            sub: "Master speaker output level slider and mute switch",
            breadcrumb: "Settings › Sound › Output › Volume",
            icon: "volume_up",
            accentRole: "m3secondary",
            keywords: "volume sound audio master speaker headphones output level mute slider loudness",
            isOption: true
        },
        {
            id: "sound_output_devices",
            pageId: "sound",
            sectionId: "output",
            rowTitle: "Output Devices",
            title: "Audio Output Device Selector",
            sub: "Select active output device (Built-in Speakers, Headphones, HDMI)",
            breadcrumb: "Settings › Sound › Output › Devices",
            icon: "speaker",
            accentRole: "m3secondary",
            keywords: "audio output device sink speakers headphones hdmi displayport bluetooth sound card",
            isOption: true
        },
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

        // ── Input ──
        {
            id: "sound_input_volume",
            pageId: "sound",
            sectionId: "input",
            rowTitle: "Input Volume",
            title: "Microphone Input Volume",
            sub: "Recording input level, gain sensitivity, and mic mute",
            breadcrumb: "Settings › Sound › Input › Volume",
            icon: "mic",
            accentRole: "m3secondary",
            keywords: "mic microphone input recording level gain voice volume mute sensitivity",
            isOption: true
        },
        {
            id: "sound_input_devices",
            pageId: "sound",
            sectionId: "input",
            rowTitle: "Input Devices",
            title: "Microphone Input Source",
            sub: "Select active recording microphone or headset audio source",
            breadcrumb: "Settings › Sound › Input › Devices",
            icon: "mic_none",
            accentRole: "m3secondary",
            keywords: "microphone input source device internal headset mic audio capture",
            isOption: true
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

        // ── App Streams ──
        {
            id: "sound_apps_mixer",
            pageId: "sound",
            sectionId: "apps",
            rowTitle: "App Streams",
            title: "Per-App Volume Mixer",
            sub: "Individual volume sliders and mute for active media applications",
            breadcrumb: "Settings › Sound › App Streams",
            icon: "equalizer",
            accentRole: "m3secondary",
            keywords: "app application streams volume mixer spotify discord browser per-app individual levels",
            isOption: true
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

        // ── UI Sounds ──
        {
            id: "sound_uisounds_toggle",
            pageId: "sound",
            sectionId: "uisounds",
            rowTitle: "UI Sounds",
            title: "System Feedback Sounds",
            sub: "System click chimes, alert tones, and feedback beeps",
            breadcrumb: "Settings › Sound › UI Sounds",
            icon: "music_note",
            accentRole: "m3secondary",
            keywords: "ui sounds feedback click chime beep alerts tone enable audio effects",
            isOption: true
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

        // ── Sound Behavior ──
        {
            id: "sound_behavior_cava",
            pageId: "sound",
            sectionId: "behavior",
            rowTitle: "Cava Visualizer",
            title: "Cava Equalizer Visualizer",
            sub: "Real-time audio spectrum visualizer bars and sensitivity",
            breadcrumb: "Settings › Sound › Behavior › Visualizer",
            icon: "graphic_eq",
            accentRole: "m3secondary",
            keywords: "cava visualizer audio equalizer spectrum bars music wave animation",
            isOption: true
        },
        {
            id: "sound_behavior_ducking",
            pageId: "sound",
            sectionId: "behavior",
            rowTitle: "Audio Ducking",
            title: "Audio Ducking",
            sub: "Lower background media volume during voice calls and audio events",
            breadcrumb: "Settings › Sound › Behavior › Ducking",
            icon: "hearing",
            accentRole: "m3secondary",
            keywords: "audio ducking volume lower voice calls background media pipewire",
            isOption: true
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

        // ═════════════════════════════════════════════════════════════════════
        // ── 4. TASKBAR ──────────────────────────────────────────────────────
        // ═════════════════════════════════════════════════════════════════════
        // ── Behavior ──
        {
            id: "taskbar_behavior_pos",
            pageId: "taskbar",
            sectionId: "behavior",
            rowTitle: "Position",
            title: "Taskbar Screen Position",
            sub: "Dock edge position: Top, Bottom, Left, or Right",
            breadcrumb: "Settings › Taskbar › Behavior › Position",
            icon: "dock",
            accentRole: "m3primary",
            keywords: "taskbar dock position top bottom left right screen edge bar placement",
            isOption: true
        },
        {
            id: "taskbar_behavior_autohide",
            pageId: "taskbar",
            sectionId: "behavior",
            rowTitle: "Autohide",
            title: "Taskbar Autohide",
            sub: "Automatically hide dock when not mouse hovered",
            breadcrumb: "Settings › Taskbar › Behavior › Autohide",
            icon: "visibility_off",
            accentRole: "m3primary",
            keywords: "autohide auto hide taskbar dock peek reveal hover invisible",
            isOption: true
        },
        {
            id: "taskbar_behavior_floating",
            pageId: "taskbar",
            sectionId: "behavior",
            rowTitle: "Floating bar",
            title: "Floating Dock Margin",
            sub: "Detached floating bar with margins vs edge attached",
            breadcrumb: "Settings › Taskbar › Behavior › Floating",
            icon: "picture_in_picture_center",
            accentRole: "m3primary",
            keywords: "floating dock margin attached gap pill bar rounded",
            isOption: true
        },
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

        // ── Quick Orb ──
        {
            id: "taskbar_quickorb_style",
            pageId: "taskbar",
            sectionId: "quickorb",
            rowTitle: "Quick Orb",
            title: "Quick Orb Start Button",
            sub: "Launcher trigger button style, logo icon, and morph animations",
            breadcrumb: "Settings › Taskbar › Quick Orb",
            icon: "adjust",
            accentRole: "m3primary",
            keywords: "quick orb start button menu icon logo trigger launcher position style morph",
            isOption: true
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

        // ── Workspaces ──
        {
            id: "taskbar_workspaces_indicator",
            pageId: "taskbar",
            sectionId: "workspaces",
            rowTitle: "Workspaces",
            title: "Workspaces Pager Indicator",
            sub: "Virtual desktop indicators, numbering, and active dot animation",
            breadcrumb: "Settings › Taskbar › Workspaces",
            icon: "grid_view",
            accentRole: "m3primary",
            keywords: "workspaces virtual desktop pager hyprland indicator number dots active switch transition",
            isOption: true
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

        // ── Widgets ──
        {
            id: "taskbar_widgets_tray",
            pageId: "taskbar",
            sectionId: "widgets",
            rowTitle: "Widgets",
            title: "System Tray & Clock Widget",
            sub: "Clock widget format, system tray icons, and status indicators",
            breadcrumb: "Settings › Taskbar › Widgets",
            icon: "widgets",
            accentRole: "m3primary",
            keywords: "widgets tray system tray status icons clock format date battery weather network audio",
            isOption: true
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

        // ── Bottom Panel ──
        {
            id: "taskbar_bottompanel_shelf",
            pageId: "taskbar",
            sectionId: "bottomPanel",
            rowTitle: "Bottom Panel",
            title: "Bottom Shelf & Pinned Apps",
            sub: "Bottom quick shelf, pinned applications, and quick actions",
            breadcrumb: "Settings › Taskbar › Bottom Panel",
            icon: "bottom_panel_open",
            accentRole: "m3primary",
            keywords: "bottom panel shelf dock drawer actions shortcuts pinned quick apps shelf",
            isOption: true
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

        // ═════════════════════════════════════════════════════════════════════
        // ── 5. NOTIFICATIONS ────────────────────────────────────────────────
        // ═════════════════════════════════════════════════════════════════════
        // ── General ──
        {
            id: "notifs_behavior_dnd",
            pageId: "notifs",
            sectionId: "behavior",
            rowTitle: "Do Not Disturb",
            title: "Do Not Disturb (DND)",
            sub: "Silence all notification popups, banners, and alert chimes",
            breadcrumb: "Settings › Notifications › DND",
            icon: "do_not_disturb_on",
            accentRole: "m3primary",
            keywords: "do not disturb dnd quiet silent mute notifications banners alerts silence",
            isOption: true
        },
        {
            id: "notifs_behavior_history",
            pageId: "notifs",
            sectionId: "behavior",
            rowTitle: "Notification History",
            title: "Notification History Center",
            sub: "Keep notification history log in drawer notification center",
            breadcrumb: "Settings › Notifications › History",
            icon: "history",
            accentRole: "m3primary",
            keywords: "notification history log notification center past dismissed log center",
            isOption: true
        },
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

        // ── Toasts ──
        {
            id: "notifs_toasts_pos",
            pageId: "notifs",
            sectionId: "toasts",
            rowTitle: "Position",
            title: "Toast Banner Corner Position",
            sub: "Screen corner: Top-Right, Top-Left, Bottom-Right, Bottom-Left",
            breadcrumb: "Settings › Notifications › Toasts › Position",
            icon: "campaign",
            accentRole: "m3primary",
            keywords: "toast banner popup position corner top right left bottom placement",
            isOption: true
        },
        {
            id: "notifs_toasts_timeout",
            pageId: "notifs",
            sectionId: "toasts",
            rowTitle: "Timeout duration",
            title: "Toast Timeout Duration",
            sub: "Banner display duration before auto-dismissing (in seconds)",
            breadcrumb: "Settings › Notifications › Toasts › Duration",
            icon: "timer",
            accentRole: "m3primary",
            keywords: "toast timeout duration seconds auto dismiss time banner popup display",
            isOption: true
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

        // ═════════════════════════════════════════════════════════════════════
        // ── 6. PANELS & DRAWERS ─────────────────────────────────────────────
        // ═════════════════════════════════════════════════════════════════════
        {
            id: "panels_dashboard_toggles",
            pageId: "panels",
            sectionId: "dashboard",
            rowTitle: "Dashboard",
            title: "Dashboard Quick Toggles",
            sub: "Control center quick settings, brightness, volume, and media widgets",
            breadcrumb: "Settings › Panels › Dashboard",
            icon: "dashboard",
            accentRole: "m3secondary",
            keywords: "dashboard control center quick settings toggles brightness sliders volume drawer panel media",
            isOption: true
        },
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
            id: "panels_launcher_grid",
            pageId: "panels",
            sectionId: "launcher",
            rowTitle: "Launcher",
            title: "App Launcher & Calculator",
            sub: "Application search grid, fuzzy search, and Qalculate math queries",
            breadcrumb: "Settings › Panels › Launcher",
            icon: "search",
            accentRole: "m3secondary",
            keywords: "launcher app apps applications search grid fuzzy search calculator qalculate math runner",
            isOption: true
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
            id: "panels_osd_flyouts",
            pageId: "panels",
            sectionId: "osd",
            rowTitle: "OSD",
            title: "On-Screen Display (OSD) HUD",
            sub: "Volume, brightness, and keyboard backlight HUD flyouts",
            breadcrumb: "Settings › Panels › OSD",
            icon: "volume_up",
            accentRole: "m3secondary",
            keywords: "osd flyout flyouts volume brightness backlight overlay popup hud notification level indicator",
            isOption: true
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

        // ═════════════════════════════════════════════════════════════════════
        // ── 7. POWER & BATTERY ──────────────────────────────────────────────
        // ═════════════════════════════════════════════════════════════════════
        // ── Battery ──
        {
            id: "power_battery_profile",
            pageId: "power",
            sectionId: "battery",
            rowTitle: "Power Profile",
            title: "Power Governor Profile",
            sub: "Performance, Balanced, or Power Saver battery mode",
            breadcrumb: "Settings › Power › Battery › Profile",
            icon: "bolt",
            accentRole: "m3secondary",
            keywords: "power profile governor performance balanced power saver battery mode energy cpu",
            isOption: true
        },
        {
            id: "power_battery_health",
            pageId: "power",
            sectionId: "battery",
            rowTitle: "Battery Status",
            title: "Battery Health & Status",
            sub: "Battery charge percentage, charging rate, and health metrics",
            breadcrumb: "Settings › Power › Battery › Status",
            icon: "battery_charging_full",
            accentRole: "m3secondary",
            keywords: "battery percentage health charging status power capacity energy discharge",
            isOption: true
        },
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

        // ── Timeouts ──
        {
            id: "power_idle_dim",
            pageId: "power",
            sectionId: "idle",
            rowTitle: "Screen Dimming",
            title: "Screen Dimming Delay",
            sub: "Idle delay before dimming screen brightness",
            breadcrumb: "Settings › Power › Idle › Dim",
            icon: "brightness_medium",
            accentRole: "m3secondary",
            keywords: "idle dim screen brightness timeout delay sleep minutes brightness",
            isOption: true
        },
        {
            id: "power_idle_turnoff",
            pageId: "power",
            sectionId: "idle",
            rowTitle: "Turn off display",
            title: "Display Turn-off Timeout",
            sub: "Idle delay before turning off monitors and display outputs",
            breadcrumb: "Settings › Power › Idle › Display off",
            icon: "display_settings",
            accentRole: "m3secondary",
            keywords: "display screen turn off monitor timeout idle sleep turnoff",
            isOption: true
        },
        {
            id: "power_idle_suspend",
            pageId: "power",
            sectionId: "idle",
            rowTitle: "System Suspend",
            title: "System Sleep / Suspend Delay",
            sub: "Idle timeout before suspending PC to RAM",
            breadcrumb: "Settings › Power › Idle › Suspend",
            icon: "bedtime",
            accentRole: "m3secondary",
            keywords: "suspend sleep hibernate system pc idle delay timeout standby",
            isOption: true
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

        // ── Hardware ──
        {
            id: "power_behavior_lid",
            pageId: "power",
            sectionId: "behavior",
            rowTitle: "Lid Action",
            title: "Laptop Lid Close Action",
            sub: "Action when closing laptop lid: Suspend, Screen off, or Do nothing",
            breadcrumb: "Settings › Power › Hardware › Lid",
            icon: "laptop",
            accentRole: "m3secondary",
            keywords: "laptop lid close action suspend display lock shutdown nothing",
            isOption: true
        },
        {
            id: "power_behavior_button",
            pageId: "power",
            sectionId: "behavior",
            rowTitle: "Power Button",
            title: "Power Button Action",
            sub: "Action when pressing hardware power button",
            breadcrumb: "Settings › Power › Hardware › Button",
            icon: "power_settings_new",
            accentRole: "m3secondary",
            keywords: "power button hardware press shutdown suspend menu lock",
            isOption: true
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

        // ═════════════════════════════════════════════════════════════════════
        // ── 8. SYSTEM ───────────────────────────────────────────────────────
        // ═════════════════════════════════════════════════════════════════════
        // ── Displays ──
        {
            id: "system_display_resolution",
            pageId: "system",
            sectionId: "display",
            rowTitle: "Resolution",
            title: "Display Resolution",
            sub: "Monitor resolution (1080p, 1440p, 4K UHD, Ultrawide)",
            breadcrumb: "Settings › System › Displays › Resolution",
            icon: "desktop_windows",
            accentRole: "m3primary",
            keywords: "display resolution monitor screen 1920x1080 2560x1440 4k ultrawide width height pixel",
            isOption: true
        },
        {
            id: "system_display_refreshrate",
            pageId: "system",
            sectionId: "display",
            rowTitle: "Refresh Rate",
            title: "Display Refresh Rate (Hz)",
            sub: "Display refresh rate (60Hz, 120Hz, 144Hz, 165Hz, 240Hz)",
            breadcrumb: "Settings › System › Displays › Refresh Rate",
            icon: "speed",
            accentRole: "m3primary",
            keywords: "refresh rate hz 60hz 120hz 144hz 165hz 240hz framerate smoothness vrr monitor",
            isOption: true
        },
        {
            id: "system_display_scaling",
            pageId: "system",
            sectionId: "display",
            rowTitle: "Scaling",
            title: "Display UI Scaling %",
            sub: "Wayland display scale factor (100%, 125%, 150%, 200%)",
            breadcrumb: "Settings › System › Displays › Scaling",
            icon: "zoom_in",
            accentRole: "m3primary",
            keywords: "display scale scaling dpi factor 100% 125% 150% 200% size zoom fractional",
            isOption: true
        },
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

        // ── Clock ──
        {
            id: "system_clock_format",
            pageId: "system",
            sectionId: "clock",
            rowTitle: "Time Format",
            title: "Time Format (12h / 24h)",
            sub: "12-hour AM/PM or 24-hour military time format",
            breadcrumb: "Settings › System › Clock › Format",
            icon: "schedule",
            accentRole: "m3primary",
            keywords: "clock time format 12h 24h 12-hour 24-hour am pm military format",
            isOption: true
        },
        {
            id: "system_clock_seconds",
            pageId: "system",
            sectionId: "clock",
            rowTitle: "Seconds",
            title: "Show Seconds in Clock",
            sub: "Display seconds in desktop and taskbar clocks",
            breadcrumb: "Settings › System › Clock › Seconds",
            icon: "timer",
            accentRole: "m3primary",
            keywords: "clock seconds show display taskbar desktop timer",
            isOption: true
        },
        {
            id: "system_clock_date",
            pageId: "system",
            sectionId: "clock",
            rowTitle: "Date Format",
            title: "Date Display Format",
            sub: "Calendar date style, day of week, and year display",
            breadcrumb: "Settings › System › Clock › Date",
            icon: "calendar_today",
            accentRole: "m3primary",
            keywords: "date calendar day week format clock month year",
            isOption: true
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

        // ── Keybindings ──
        {
            id: "system_keybinds_list",
            pageId: "system",
            sectionId: "keybinds",
            rowTitle: "Keybindings",
            title: "Hyprland Keybindings & Hotkeys",
            sub: "Window manager shortcuts, hotkeys, and super key binds",
            breadcrumb: "Settings › System › Keybindings",
            icon: "keyboard",
            accentRole: "m3primary",
            keywords: "keybinds keybindings shortcuts keyboard hotkeys super bind hyprland keys combinations",
            isOption: true
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

        // ── Media ──
        {
            id: "system_media_mpris",
            pageId: "system",
            sectionId: "media",
            rowTitle: "Media",
            title: "MPRIS Media Controls",
            sub: "Music player integration, Spotify, album art, playback controls",
            breadcrumb: "Settings › System › Media",
            icon: "play_circle",
            accentRole: "m3primary",
            keywords: "media music mpris spotify player song playback album track controls sound art",
            isOption: true
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

        // ── Advanced ──
        {
            id: "system_advanced_debug",
            pageId: "system",
            sectionId: "advanced",
            rowTitle: "Advanced",
            title: "Developer & Debug Logging",
            sub: "Shell debugging, GPU rendering loop, and system logs",
            breadcrumb: "Settings › System › Advanced",
            icon: "build",
            accentRole: "m3primary",
            keywords: "advanced developer debug logging gpu render crash reports config inspector performance logs",
            isOption: true
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

        // ═════════════════════════════════════════════════════════════════════
        // ── 9. ABOUT ────────────────────────────────────────────────────────
        // ═════════════════════════════════════════════════════════════════════
        {
            id: "about_system",
            pageId: "about",
            sectionId: "",
            rowTitle: "About",
            title: "About Olvex Shell",
            sub: "Version, Linux kernel, CPU/GPU/RAM specs, and maintainer info",
            breadcrumb: "Settings › About",
            icon: "deployed_code",
            accentRole: "m3primary",
            keywords: "about version olvex system specs linux kernel cpu gpu ram maintainer info quickshell license hardware",
            isOption: true
        }
    ]

    function search(query) {
        if (!query || query.trim() === "")
            return [];
        
        const q = query.trim().toLowerCase();
        const rawTerms = q.split(/\s+/).filter(t => t.length > 0);
        const results = [];

        for (let i = 0; i < searchItems.length; i++) {
            const item = searchItems[i];
            const title = (item.title || "").toLowerCase();
            const rowTitle = (item.rowTitle || "").toLowerCase();
            const sub = (item.sub || "").toLowerCase();
            const breadcrumb = (item.breadcrumb || "").toLowerCase();
            const kw = (item.keywords || "").toLowerCase();
            const pageId = (item.pageId || "").toLowerCase();
            const sectionId = (item.sectionId || "").toLowerCase();
            const kwList = kw.split(/\s+/);

            let score = 0;

            // 1. Exact full query matches
            if (title === q || rowTitle === q) {
                score += 240;
            } else if (title.startsWith(q) || rowTitle.startsWith(q)) {
                score += 170;
            } else if (title.includes(q) || rowTitle.includes(q)) {
                score += 120;
            }

            // Keyword exact word match (e.g. searching "dark" exactly matches keyword "dark")
            if (kwList.includes(q)) {
                score += 140;
            } else if (kw.includes(q)) {
                score += 70;
            }

            if (pageId === q || (sectionId && sectionId === q)) {
                score += 80;
            }

            if (sub.includes(q)) {
                score += 45;
            }

            if (breadcrumb.includes(q)) {
                score += 35;
            }

            // 2. Individual term scoring
            let termMatches = 0;
            for (let j = 0; j < rawTerms.length; j++) {
                const term = rawTerms[j];
                let matched = false;

                if (title.includes(term) || rowTitle.includes(term)) {
                    score += 50;
                    matched = true;
                }
                if (kwList.includes(term)) {
                    score += 40;
                    matched = true;
                } else if (kw.includes(term)) {
                    score += 25;
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
            if (rawTerms.length > 1 && termMatches === rawTerms.length) {
                score += 60;
            }

            // Granularity boost: specific options get priority over broad categories
            if (item.isOption && score > 0) {
                score += 20;
            }

            if (score > 0) {
                results.push({
                    id: item.id,
                    pageId: item.pageId,
                    sectionId: item.sectionId,
                    rowTitle: item.rowTitle || item.title,
                    title: item.title,
                    sub: item.sub,
                    breadcrumb: item.breadcrumb,
                    icon: item.icon,
                    accentRole: item.accentRole,
                    keywords: item.keywords || "",
                    searchQuery: query,
                    score: score
                });
            }
        }

        results.sort((a, b) => b.score - a.score);
        return results;
    }

    // ── Global highlight state for SettingRow & Section deep-link flash ─────
    property string highlightKey: ""
    property string highlightSection: ""
    property string highlightPage: ""
    property string highlightQuery: ""
    property string highlightTitle: ""
    property string highlightId: ""
    property real highlightTimestamp: 0

    function flashHighlight(key, section, page, query, title, id) {
        highlightKey = key || "";
        highlightSection = section || "";
        highlightPage = page || "";
        highlightQuery = query || "";
        highlightTitle = title || "";
        highlightId = id || "";
        highlightTimestamp = Date.now();
    }
}
