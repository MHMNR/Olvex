pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Olvex
import Olvex.Config
import qs.services
import qs.modules.settings

QtObject {
    id: root

    readonly property var toggles: [
        {
            id: "toggle_wifi",
            settingId: "network_wifi_toggle",
            name: qsTr("Wi-Fi"),
            pageId: "network",
            sectionId: "wifi",
            accentRole: "m3primary",
            keywords: "wifi wi-fi wireless wlan internet network toggle on off connect switch adapter ssid",
            getter: function() { return Boolean(Network.wifiEnabled); },
            setter: function(val) { Network.wifiEnabled = Boolean(val); },
            toggle: function() { Network.wifiEnabled = !Network.wifiEnabled; },
            statusText: function() {
                return Network.wifiEnabled
                    ? (Network.primarySsid ? qsTr("Connected to %1").arg(Network.primarySsid) : qsTr("Enabled"))
                    : qsTr("Disabled");
            },
            icon: function() { return Network.wifiEnabled ? "wifi" : "wifi_off"; }
        },
        {
            id: "toggle_bluetooth",
            settingId: "network_bluetooth_toggle",
            name: qsTr("Bluetooth"),
            pageId: "network",
            sectionId: "bluetooth",
            accentRole: "m3primary",
            keywords: "bluetooth bt wireless radio toggle enable disable switch adapter pair devices",
            getter: function() {
                return (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled) ? true : false;
            },
            setter: function(val) {
                if (Bluetooth.defaultAdapter) {
                    Bluetooth.defaultAdapter.enabled = Boolean(val);
                    if (val) Bluetooth.defaultAdapter.discovering = true;
                }
            },
            toggle: function() {
                if (Bluetooth.defaultAdapter) {
                    Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
                    if (Bluetooth.defaultAdapter.enabled)
                        Bluetooth.defaultAdapter.discovering = true;
                }
            },
            statusText: function() {
                const isEnabled = (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled) ? true : false;
                return isEnabled ? qsTr("Bluetooth enabled") : qsTr("Bluetooth disabled");
            },
            icon: function() {
                const isEnabled = (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled) ? true : false;
                return isEnabled ? "bluetooth" : "bluetooth_disabled";
            }
        },
        {
            id: "toggle_dark_mode",
            settingId: "appearance_theme_mode",
            name: qsTr("Dark Mode"),
            pageId: "appearance",
            sectionId: "theme",
            accentRole: "m3primary",
            keywords: "dark light mode theme appearance night daylight switch fixed color style theme",
            getter: function() { return !Colours.light; },
            setter: function(val) { Colours.setMode(val ? "dark" : "light"); },
            toggle: function() { Colours.setMode(Colours.light ? "dark" : "light"); },
            statusText: function() {
                return Colours.light ? qsTr("Light mode active") : qsTr("Dark mode active");
            },
            icon: function() { return Colours.light ? "light_mode" : "dark_mode"; }
        },
        {
            id: "toggle_night_light",
            settingId: "appearance_theme_nightlight",
            name: qsTr("Night Light"),
            pageId: "appearance",
            sectionId: "theme",
            accentRole: "m3tertiary",
            keywords: "night light blue light eye strain warm display tint filter reading nightlight sleep sunset",
            getter: function() { return Boolean(NightLight.enabled); },
            setter: function(val) { NightLight.setEnabled(Boolean(val)); },
            toggle: function() { NightLight.toggle(); },
            statusText: function() {
                return NightLight.enabled
                    ? qsTr("Warm display tint active (%1K)").arg(NightLight.temperature)
                    : qsTr("Disabled");
            },
            icon: function() { return NightLight.enabled ? "nightlight" : "bedtime"; }
        },
        {
            id: "toggle_dnd",
            settingId: "notifs_behavior_dnd",
            name: qsTr("Do Not Disturb"),
            pageId: "notifs",
            sectionId: "dnd",
            accentRole: "m3error",
            keywords: "do not disturb dnd quiet silent mute notifications banners alerts silence",
            getter: function() { return Boolean(Notifs.dnd); },
            setter: function(val) { Notifs.dnd = Boolean(val); },
            toggle: function() {
                if (Notifs.toggleDnd) Notifs.toggleDnd();
                else Notifs.dnd = !Notifs.dnd;
            },
            statusText: function() {
                return Notifs.dnd ? qsTr("Notification banners silenced") : qsTr("Notifications active");
            },
            icon: function() { return Notifs.dnd ? "do_not_disturb_on" : "notifications"; }
        },
        {
            id: "toggle_blur",
            settingId: "appearance_transparency_blur",
            name: qsTr("Background Blur"),
            pageId: "appearance",
            sectionId: "transparency",
            accentRole: "m3secondary",
            keywords: "blur background frost gaussian fastblur glass glassmorphism enable backdrop transparency",
            getter: function() {
                return Boolean(GlobalConfig.appearance && GlobalConfig.appearance.transparency && GlobalConfig.appearance.transparency.blur);
            },
            setter: function(val) {
                if (GlobalConfig.appearance && GlobalConfig.appearance.transparency) {
                    GlobalConfig.appearance.transparency.blur = Boolean(val);
                    GlobalConfig.save();
                }
            },
            toggle: function() {
                if (GlobalConfig.appearance && GlobalConfig.appearance.transparency) {
                    GlobalConfig.appearance.transparency.blur = !GlobalConfig.appearance.transparency.blur;
                    GlobalConfig.save();
                }
            },
            statusText: function() {
                const blurOn = Boolean(GlobalConfig.appearance && GlobalConfig.appearance.transparency && GlobalConfig.appearance.transparency.blur);
                return blurOn ? qsTr("Glass blur effect enabled") : qsTr("Disabled");
            },
            icon: function() {
                const blurOn = Boolean(GlobalConfig.appearance && GlobalConfig.appearance.transparency && GlobalConfig.appearance.transparency.blur);
                return blurOn ? "blur_on" : "blur_off";
            }
        },
        {
            id: "toggle_live_wallpaper",
            settingId: "appearance_wallpapers",
            name: qsTr("Live Wallpaper"),
            pageId: "appearance",
            sectionId: "wallpapers",
            accentRole: "m3tertiary",
            keywords: "live wallpaper video animated moving motion background mp4 playback",
            getter: function() {
                return Boolean(GlobalConfig.background && GlobalConfig.background.liveWallpaper && GlobalConfig.background.liveWallpaper.enabled);
            },
            setter: function(val) {
                if (GlobalConfig.background && GlobalConfig.background.liveWallpaper) {
                    GlobalConfig.background.liveWallpaper.enabled = Boolean(val);
                    GlobalConfig.save();
                }
            },
            toggle: function() {
                if (GlobalConfig.background && GlobalConfig.background.liveWallpaper) {
                    GlobalConfig.background.liveWallpaper.enabled = !GlobalConfig.background.liveWallpaper.enabled;
                    GlobalConfig.save();
                }
            },
            statusText: function() {
                const liveOn = Boolean(GlobalConfig.background && GlobalConfig.background.liveWallpaper && GlobalConfig.background.liveWallpaper.enabled);
                return liveOn ? qsTr("Animated live video wallpaper enabled") : qsTr("Disabled");
            },
            icon: function() {
                const liveOn = Boolean(GlobalConfig.background && GlobalConfig.background.liveWallpaper && GlobalConfig.background.liveWallpaper.enabled);
                return liveOn ? "motion_photos_on" : "motion_photos_off";
            }
        },
        {
            id: "toggle_wallpaper_cycling",
            settingId: "appearance_wallpapers_cycle",
            name: qsTr("Wallpaper Slideshow"),
            pageId: "appearance",
            sectionId: "wallpapers",
            accentRole: "m3secondary",
            keywords: "wallpaper slideshow cycle interval timer rotate random auto change",
            getter: function() {
                return Boolean(GlobalConfig.background && GlobalConfig.background.wallpaperCycling && GlobalConfig.background.wallpaperCycling.enabled);
            },
            setter: function(val) {
                if (GlobalConfig.background && GlobalConfig.background.wallpaperCycling) {
                    GlobalConfig.background.wallpaperCycling.enabled = Boolean(val);
                    GlobalConfig.save();
                }
            },
            toggle: function() {
                if (GlobalConfig.background && GlobalConfig.background.wallpaperCycling) {
                    GlobalConfig.background.wallpaperCycling.enabled = !GlobalConfig.background.wallpaperCycling.enabled;
                    GlobalConfig.save();
                }
            },
            statusText: function() {
                const cycleOn = Boolean(GlobalConfig.background && GlobalConfig.background.wallpaperCycling && GlobalConfig.background.wallpaperCycling.enabled);
                const interval = (GlobalConfig.background && GlobalConfig.background.wallpaperCycling) ? GlobalConfig.background.wallpaperCycling.intervalSeconds : 300;
                return cycleOn ? qsTr("Auto-changing every %1s").arg(interval) : qsTr("Disabled");
            },
            icon: function() {
                const cycleOn = Boolean(GlobalConfig.background && GlobalConfig.background.wallpaperCycling && GlobalConfig.background.wallpaperCycling.enabled);
                return cycleOn ? "timer" : "timer_off";
            }
        },
        {
            id: "toggle_desktop_clock",
            settingId: "appearance_wallpapers",
            name: qsTr("Desktop Clock"),
            pageId: "appearance",
            sectionId: "wallpapers",
            accentRole: "m3primary",
            keywords: "desktop clock time date widget wallpaper screen clock display",
            getter: function() {
                return Boolean(GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.enabled);
            },
            setter: function(val) {
                if (GlobalConfig.background && GlobalConfig.background.desktopClock) {
                    GlobalConfig.background.desktopClock.enabled = Boolean(val);
                    GlobalConfig.save();
                }
            },
            toggle: function() {
                if (GlobalConfig.background && GlobalConfig.background.desktopClock) {
                    GlobalConfig.background.desktopClock.enabled = !GlobalConfig.background.desktopClock.enabled;
                    GlobalConfig.save();
                }
            },
            statusText: function() {
                const clockOn = Boolean(GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.enabled);
                return clockOn ? qsTr("Desktop clock widget visible") : qsTr("Disabled");
            },
            icon: function() {
                const clockOn = Boolean(GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.enabled);
                return clockOn ? "schedule" : "timer_off";
            }
        },
        {
            id: "toggle_keep_awake",
            settingId: "power_sleep",
            name: qsTr("Keep Awake"),
            pageId: "power",
            sectionId: "sleep",
            accentRole: "m3secondary",
            keywords: "keep awake caffeine sleep idle inhibitor prevent suspend screen lock display power",
            getter: function() { return Boolean(IdleInhibitor.enabled); },
            setter: function(val) { IdleInhibitor.enabled = Boolean(val); },
            toggle: function() { IdleInhibitor.enabled = !IdleInhibitor.enabled; },
            statusText: function() {
                return IdleInhibitor.enabled ? qsTr("System sleep and idle suspend inhibited") : qsTr("Disabled");
            },
            icon: function() { return IdleInhibitor.enabled ? "coffee" : "bedtime"; }
        },
        {
            id: "toggle_game_mode",
            settingId: "system_performance",
            name: qsTr("Game Mode"),
            pageId: "system",
            sectionId: "performance",
            accentRole: "m3primary",
            keywords: "game mode gaming performance disable animations tear low latency hyprland fps",
            getter: function() { return Boolean(GameMode.enabled); },
            setter: function(val) { GameMode.enabled = Boolean(val); },
            toggle: function() { GameMode.enabled = !GameMode.enabled; },
            statusText: function() {
                return GameMode.enabled
                    ? qsTr("Low latency, no blur/animations for gaming")
                    : qsTr("Disabled");
            },
            icon: function() { return "sports_esports"; }
        },
        {
            id: "toggle_audio_mute",
            settingId: "sound_volume",
            name: qsTr("Mute Audio"),
            pageId: "sound",
            sectionId: "volume",
            accentRole: "m3error",
            keywords: "audio mute sound volume silence quiet speakers output",
            getter: function() {
                return (Audio.sink && Audio.sink.audio) ? Boolean(Audio.sink.audio.muted) : false;
            },
            setter: function(val) {
                if (Audio.sink && Audio.sink.audio) Audio.sink.audio.muted = Boolean(val);
            },
            toggle: function() {
                if (Audio.sink && Audio.sink.audio) Audio.sink.audio.muted = !Audio.sink.audio.muted;
            },
            statusText: function() {
                const isMuted = (Audio.sink && Audio.sink.audio) ? Boolean(Audio.sink.audio.muted) : false;
                const vol = (Audio.sink && Audio.sink.audio) ? Audio.sink.audio.volume : 0;
                return isMuted
                    ? qsTr("Audio output muted")
                    : qsTr("Volume at %1%").arg(Math.round(vol * 100));
            },
            icon: function() {
                const isMuted = (Audio.sink && Audio.sink.audio) ? Boolean(Audio.sink.audio.muted) : false;
                return isMuted ? "volume_off" : "volume_up";
            }
        },
        {
            id: "toggle_mic_mute",
            settingId: "sound_inputs",
            name: qsTr("Mute Microphone"),
            pageId: "sound",
            sectionId: "inputs",
            accentRole: "m3error",
            keywords: "mic microphone mute input voice record silence quiet sound",
            getter: function() {
                return (Audio.source && Audio.source.audio) ? Boolean(Audio.source.audio.muted) : false;
            },
            setter: function(val) {
                if (Audio.source && Audio.source.audio) Audio.source.audio.muted = Boolean(val);
            },
            toggle: function() {
                if (Audio.source && Audio.source.audio) Audio.source.audio.muted = !Audio.source.audio.muted;
            },
            statusText: function() {
                const isMuted = (Audio.source && Audio.source.audio) ? Boolean(Audio.source.audio.muted) : false;
                return isMuted ? qsTr("Microphone muted") : qsTr("Microphone active");
            },
            icon: function() {
                const isMuted = (Audio.source && Audio.source.audio) ? Boolean(Audio.source.audio.muted) : false;
                return isMuted ? "mic_off" : "mic";
            }
        }
    ]

    function search(query) {
        if (!query || query.trim() === "")
            return [];

        const q = query.trim().toLowerCase();
        const rawTerms = q.split(/\s+/).filter(t => t.length > 0);
        const results = [];

        for (let i = 0; i < toggles.length; i++) {
            const item = toggles[i];
            const name = (item.name || "").toLowerCase();
            const kw = (item.keywords || "").toLowerCase();
            const kwList = kw.split(/\s+/);

            let score = 0;

            // 1. Exact full query matches
            if (name === q) {
                score += 320;
            } else if (name.startsWith(q)) {
                score += 220;
            } else if (name.includes(q)) {
                score += 150;
            }

            // Keyword exact word match
            if (kwList.includes(q)) {
                score += 180;
            } else if (kw.includes(q)) {
                score += 90;
            }

            // 2. Individual term scoring
            let termMatches = 0;
            for (let j = 0; j < rawTerms.length; j++) {
                const term = rawTerms[j];
                let matched = false;
                if (name.includes(term)) {
                    score += 50;
                    matched = true;
                }
                if (kwList.includes(term)) {
                    score += 40;
                    matched = true;
                } else if (kw.includes(term)) {
                    score += 20;
                    matched = true;
                }
                if (matched)
                    termMatches++;
            }

            // Bonus if all terms matched
            if (rawTerms.length > 1 && termMatches === rawTerms.length) {
                score += 60;
            }

            if (score > 0) {
                results.push({
                    type: "toggle",
                    id: item.id,
                    settingId: item.settingId,
                    name: item.name,
                    pageId: item.pageId,
                    sectionId: item.sectionId,
                    icon: item.icon(),
                    iconFunc: item.icon,
                    accentRole: item.accentRole,
                    getter: item.getter,
                    setter: item.setter,
                    toggle: item.toggle,
                    statusText: item.statusText,
                    searchQuery: query,
                    score: score
                });
            }
        }

        results.sort((a, b) => b.score - a.score);
        return results;
    }
}
