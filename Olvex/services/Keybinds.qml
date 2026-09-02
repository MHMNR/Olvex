pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Olvex.Config
import qs.utils

Singleton {
    id: root

    property var binds: []
    property bool loading: false
    property string query: ""
    property string selectedCategory: "all" // "all", "olvex", "window", "workspace", "apps", "media", "other"

    readonly property var filteredBinds: {
        let list = root.binds || [];
        const cat = root.selectedCategory;
        const q = (root.query || "").trim().toLowerCase();

        if (cat && cat !== "all") {
            list = list.filter(item => item.category === cat);
        }

        if (q.length > 0) {
            list = list.filter(item => {
                const desc = (item.description || "").toLowerCase();
                const shortcut = (item.shortcutDisplay || "").toLowerCase();
                const key = (item.key || "").toLowerCase();
                const mod = (item.modString || "").toLowerCase();
                const disp = (item.dispatcher || "").toLowerCase();
                const arg = (item.arg || "").toLowerCase();
                return desc.includes(q) || shortcut.includes(q) || key.includes(q) || mod.includes(q) || disp.includes(q) || arg.includes(q);
            });
        }

        return list;
    }

    property var counts: ({ all: 0, olvex: 0, window: 0, workspace: 0, apps: 0, media: 0 })

    readonly property var categories: [
        { id: "all", label: qsTr("All"), icon: "apps", count: root.counts.all || 0 },
        { id: "olvex", label: qsTr("Olvex Shell"), icon: "desktop_windows", count: root.counts.olvex || 0 },
        { id: "window", label: qsTr("Window"), icon: "crop_square", count: root.counts.window || 0 },
        { id: "workspace", label: qsTr("Workspaces"), icon: "view_carousel", count: root.counts.workspace || 0 },
        { id: "apps", label: qsTr("Apps"), icon: "launch", count: root.counts.apps || 0 },
        { id: "media", label: qsTr("Media & Sys"), icon: "tune", count: root.counts.media || 0 }
    ]

    Component.onCompleted: {
        reload();
    }

    function reload() {
        if (fetchBindsProc.running)
            return;
        loading = true;
        fetchBindsProc.running = true;
    }

    Process {
        id: fetchBindsProc
        running: false
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    let clean = (text || "").trim();
                    if (!clean) return;
                    const start = clean.indexOf("[");
                    const end = clean.lastIndexOf("]");
                    if (start >= 0 && end > start) {
                        clean = clean.substring(start, end + 1);
                        const raw = JSON.parse(clean);
                        root.binds = root.parseRawBinds(raw);
                    }
                } catch (e) {
                    console.warn("Keybinds.qml: Failed to parse hyprctl binds JSON:", e);
                }
            }
        }
    }

    function parseRawBinds(rawList) {
        if (!Array.isArray(rawList)) return [];
        const results = [];
        const seen = new Set();
        const counts = { all: 0, olvex: 0, window: 0, workspace: 0, apps: 0, media: 0 };

        for (let i = 0; i < rawList.length; i++) {
            const item = rawList[i];
            const modmask = item.modmask || 0;
            const key = item.key || "";
            const dispatcher = item.dispatcher || "";
            const arg = item.arg || "";
            const submap = item.submap || "";
            
            // Skip submap binds
            if (submap !== "" && submap !== "default") continue;

            const modArray = root.getModifiers(modmask);
            const modString = modArray.join(" + ");
            const displayKey = root.formatKey(key);
            const shortcutDisplay = modArray.length > 0 ? `${modString} + ${displayKey}` : displayKey;
            const category = root.categorizeBind(dispatcher, arg, key);
            const desc = root.describeBind(dispatcher, arg, item.description);

            let flag = "bind";
            if (item.release) flag = "bindr";
            else if (item.locked) flag = "bindl";
            else if (item.repeat) flag = "binde";
            else if (item.mouse) flag = "bindm";

            const icon = root.iconForBind(dispatcher, arg, key, category);

            const keybind = {
                raw: item,
                modmask: modmask,
                mods: modArray,
                modString: modString,
                key: key,
                displayKey: displayKey,
                shortcutDisplay: shortcutDisplay,
                dispatcher: dispatcher,
                arg: arg,
                description: desc,
                category: category,
                icon: icon,
                flag: flag,
                locked: !!item.locked,
                mouse: !!item.mouse,
                release: !!item.release,
                repeat: !!item.repeat,
                id: `${modmask}:${key}:${dispatcher}:${arg}`
            };

            // Deduplicate identical binds
            if (!seen.has(keybind.id)) {
                seen.add(keybind.id);
                results.push(keybind);
                if (category in counts) counts[category]++;
                counts.all++;
            }
        }

        root.counts = counts;
        return results;
    }

    function getModifiers(modmask) {
        const mods = [];
        if (modmask & 64) mods.push("SUPER");
        if (modmask & 4) mods.push("CTRL");
        if (modmask & 8) mods.push("ALT");
        if (modmask & 1) mods.push("SHIFT");
        return mods;
    }

    function formatKey(key) {
        if (!key) return "";
        const map = {
            "SUPER_L": "Super",
            "SUPER_R": "Super",
            "Control_L": "Ctrl",
            "Control_R": "Ctrl",
            "Alt_L": "Alt",
            "Alt_R": "Alt",
            "Shift_L": "Shift",
            "Shift_R": "Shift",
            "Return": "Enter",
            "Escape": "Esc",
            "BackSpace": "Backspace",
            "Tab": "Tab",
            "space": "Space",
            "Delete": "Del",
            "Insert": "Ins",
            "Home": "Home",
            "End": "End",
            "Page_Up": "PgUp",
            "Page_Down": "PgDn",
            "grave": "`",
            "minus": "-",
            "equal": "=",
            "bracketleft": "[",
            "bracketright": "]",
            "backslash": "\\",
            "semicolon": ";",
            "apostrophe": "'",
            "comma": ",",
            "period": ".",
            "slash": "/",
            "Left": "←",
            "Right": "→",
            "Up": "↑",
            "Down": "↓",
            "XF86AudioRaiseVolume": "Vol +",
            "XF86AudioLowerVolume": "Vol -",
            "XF86AudioMute": "Mute",
            "XF86AudioMicMute": "Mic Mute",
            "XF86AudioPlay": "Play",
            "XF86AudioPause": "Pause",
            "XF86AudioNext": "Next",
            "XF86AudioPrev": "Prev",
            "XF86AudioStop": "Stop",
            "XF86MonBrightnessUp": "Brightness +",
            "XF86MonBrightnessDown": "Brightness -"
        };
        return map[key] || key;
    }

    function categorizeBind(dispatcher, arg, key) {
        const d = (dispatcher || "").toLowerCase();
        const a = (arg || "").toLowerCase();
        const k = (key || "").toLowerCase();

        if (d === "global" || a.includes("olvex") || a.includes("drawer") || a.includes("sidebar")) {
            return "olvex";
        }
        if (k.startsWith("xf86") || a.includes("brightness") || a.includes("volume") || a.includes("wpctl") || a.includes("playerctl") || a.includes("pamixer")) {
            return "media";
        }
        if (d.includes("workspace") || a.includes("workspace") || a.includes("wsaction")) {
            return "workspace";
        }
        if (d === "killactive" || d === "togglefloating" || d === "fullscreen" || d === "fullscreenstate" || d === "pseudo" || d === "togglesplit" || d === "centerwindow" || d === "pin" || d.includes("group") || d.includes("focus") || d.includes("movewindow") || d.includes("resize") || d === "cyclenext") {
            return "window";
        }
        if (d === "exec") {
            return "apps";
        }
        return "other";
    }

    function cleanCommand(cmdStr) {
        if (!cmdStr) return "";
        let cmd = cmdStr.trim();
        // Unwrap shell wrappers, env launchers and chained conditionals
        cmd = cmd.replace(/^(\/usr\/bin\/env\s+|\/bin\/sh\s+-c\s+|\/bin\/bash\s+-c\s+|sh\s+-c\s+|bash\s+-c\s+|fish\s+-c\s+)/i, "");
        cmd = cmd.replace(/^(app2unit\s+--\s+|systemd-run\s+--user\s+--\s+|uwsm\s+app\s+--\s+)/i, "");
        cmd = cmd.replace(/^(pkill\s+[^;\|&]+\s*\|\|\s*|pkill\s+[^;\|&]+\s*;\s*)/i, "");
        cmd = cmd.replace(/^(sleep\s+[^;\|&]+\s*&&\s*)/i, "");
        return cmd.trim();
    }

    function formatAppName(rawBinary) {
        if (!rawBinary) return "";
        let bin = rawBinary.split("/").pop().trim();
        
        // Strip flatpak / reverse domain prefixes (e.g. org.kde.dolphin -> dolphin, com.spotify.Client -> Client)
        if (bin.includes(".") && !bin.endsWith(".sh") && !bin.endsWith(".fish") && !bin.endsWith(".py")) {
            const parts = bin.split(".");
            bin = parts[parts.length - 1];
        }

        // Known common acronyms / proper casings
        const knownCases = {
            "kitty": "Kitty Terminal",
            "foot": "Foot Terminal",
            "alacritty": "Alacritty",
            "wezterm": "WezTerm",
            "firefox": "Firefox",
            "google-chrome": "Google Chrome",
            "chrome": "Google Chrome",
            "brave": "Brave Browser",
            "brave-browser": "Brave Browser",
            "zen-browser": "Zen Browser",
            "zen": "Zen Browser",
            "thunar": "Thunar File Manager",
            "nemo": "Nemo File Manager",
            "nautilus": "Nautilus File Manager",
            "dolphin": "Dolphin File Manager",
            "code": "Visual Studio Code",
            "vscodium": "VSCodium",
            "antigravity": "Antigravity IDE",
            "github-desktop": "GitHub Desktop",
            "qps": "Qps Task Manager",
            "btop": "Btop System Monitor",
            "htop": "Htop System Monitor",
            "pavucontrol": "Volume Mixer (Pavucontrol)",
            "spotify": "Spotify",
            "discord": "Discord",
            "vesktop": "Vesktop",
            "slack": "Slack",
            "telegram-desktop": "Telegram",
            "obs": "OBS Studio",
            "obs-studio": "OBS Studio",
            "gimp": "GIMP",
            "inkscape": "Inkscape",
            "vlc": "VLC Media Player",
            "mpv": "MPV Player",
            "steam": "Steam",
            "hyprpicker": "Color Picker",
            "wlogout": "Session Menu"
        };

        const lower = bin.toLowerCase();
        if (knownCases[lower]) return knownCases[lower];

        // Format slug to Title Case: "gnome-calculator" -> "Gnome Calculator", "my_custom_tool" -> "My Custom Tool"
        return bin
            .replace(/[-_]+/g, " ")
            .split(" ")
            .map(w => w.length > 0 ? (w.charAt(0).toUpperCase() + w.slice(1)) : "")
            .join(" ");
    }

    function formatDirection(dirStr) {
        const d = (dirStr || "").trim().toLowerCase();
        const map = {
            "l": "Left", "left": "Left",
            "r": "Right", "right": "Right",
            "u": "Up", "up": "Up", "above": "Above",
            "d": "Down", "down": "Down", "below": "Below",
            "prev": "Previous", "next": "Next"
        };
        return map[d] || (d ? d.toUpperCase() : "");
    }

    function describeBind(dispatcher, arg, customDesc) {
        if (customDesc && customDesc.length > 0) return customDesc;
        const d = (dispatcher || "").trim().toLowerCase();
        const rawArg = (arg || "").trim();
        const aLow = rawArg.toLowerCase();
        const cleanedCmd = root.cleanCommand(rawArg);
        const cmdLow = cleanedCmd.toLowerCase();

        // ── 1. Audio & Media Controls ──
        if (cmdLow.includes("wpctl") || cmdLow.includes("pamixer") || cmdLow.includes("pactl") || cmdLow.includes("amixer") || cmdLow.includes("playerctl") || aLow.includes("olvex:media") || aLow.includes("audio")) {
            const isMic = cmdLow.includes("source") || cmdLow.includes("default-source") || cmdLow.includes("mic") || aLow.includes("mic");
            const isMute = cmdLow.includes("set-mute") || cmdLow.includes("mute") || cmdLow.includes("-t");
            const isVolume = cmdLow.includes("set-volume") || cmdLow.includes("volume") || cmdLow.includes("-i") || cmdLow.includes("-d");
            
            if (isMute) {
                return isMic ? qsTr("Toggle Microphone Mute") : qsTr("Toggle Audio Output Mute");
            }
            if (isVolume) {
                const matchPct = rawArg.match(/(\d+%\+?|\d+%-\?|\+\d+%?|-\d+%?)/);
                const pct = matchPct ? ` (${matchPct[0]})` : "";
                const isUp = cmdLow.includes("+") || cmdLow.includes("-i") || cmdLow.includes("raise");
                return (isUp ? qsTr("Increase Volume%1") : qsTr("Decrease Volume%1")).arg(pct);
            }
            if (cmdLow.includes("play-pause") || aLow.includes("mediatoggle")) return qsTr("Play / Pause Media");
            if (cmdLow.includes("next") || aLow.includes("medianext")) return qsTr("Next Media Track");
            if (cmdLow.includes("prev") || aLow.includes("mediaprev")) return qsTr("Previous Media Track");
            if (cmdLow.includes("stop") || aLow.includes("mediastop")) return qsTr("Stop Media Playback");
        }

        // ── 2. Display & Screen Brightness ──
        if (cmdLow.includes("brightnessctl") || cmdLow.includes("light") || cmdLow.includes("ddcutil") || aLow.includes("brightness")) {
            const matchPct = rawArg.match(/(\d+%\+?|\d+%-\?|\+\d+%?|-\d+%?)/);
            const pct = matchPct ? ` (${matchPct[0]})` : "";
            const isUp = cmdLow.includes("+") || cmdLow.includes("-a") || cmdLow.includes("up") || aLow.includes("brightnessup");
            return (isUp ? qsTr("Increase Screen Brightness%1") : qsTr("Decrease Screen Brightness%1")).arg(pct);
        }

        // ── 3. Screenshots & Screen Recording ──
        if (cmdLow.includes("screenshot") || cmdLow.includes("grim") || cmdLow.includes("slurp") || cmdLow.includes("flameshot") || cmdLow.includes("swappy")) {
            if (cmdLow.includes("area") || cmdLow.includes("region") || cmdLow.includes("slurp") || cmdLow.includes("-r")) {
                return qsTr("Capture Screen Region");
            }
            if (cmdLow.includes("window") || cmdLow.includes("active")) {
                return qsTr("Capture Active Window");
            }
            return qsTr("Take Screenshot");
        }
        if (cmdLow.includes("record") || cmdLow.includes("wf-recorder") || cmdLow.includes("wl-screenrec")) {
            if (cmdLow.includes("-r") || cmdLow.includes("region") || cmdLow.includes("slurp")) return qsTr("Record Screen Region");
            if (cmdLow.includes("-s") || cmdLow.includes("audio")) return qsTr("Record Screen with Audio");
            return qsTr("Start / Stop Screen Recording");
        }

        // ── 4. Clipboard, Emoji & Utilities ──
        if (cmdLow.includes("clipboard") || cmdLow.includes("cliphist") || cmdLow.includes("wl-copy") || cmdLow.includes("wl-paste") || cmdLow.includes("copyq")) {
            if (cmdLow.includes("ydotool") || cmdLow.includes("type")) return qsTr("Paste Recent Clipboard Item");
            if (cmdLow.includes("-d") || cmdLow.includes("paste")) return qsTr("Open Clipboard (Direct Paste)");
            return qsTr("Open Clipboard History");
        }
        if (cmdLow.includes("emoji")) return qsTr("Open Emoji Picker");
        if (cmdLow.includes("hyprpicker") || cmdLow.includes("colorpicker")) return qsTr("Color Picker (Copy HEX)");

        // ── 5. System Power & Session ──
        if (cmdLow.includes("systemctl") || cmdLow.includes("loginctl") || cmdLow.includes("wlogout") || aLow.includes("olvex:session") || aLow.includes("olvex:lock")) {
            if (cmdLow.includes("suspend-then-hibernate")) return qsTr("Suspend & Hibernate System");
            if (cmdLow.includes("suspend")) return qsTr("Suspend System");
            if (cmdLow.includes("hibernate")) return qsTr("Hibernate System");
            if (cmdLow.includes("reboot")) return qsTr("Restart Computer");
            if (cmdLow.includes("poweroff") || cmdLow.includes("shutdown")) return qsTr("Shut Down Computer");
            if (cmdLow.includes("lock") || aLow.includes("olvex:lock") || cmdLow === "olvex shell -d") return qsTr("Lock Screen");
            if (aLow.includes("session") || cmdLow.includes("wlogout")) return qsTr("Power & Session Menu");
        }

        // ── 6. Olvex Shell Drawers & Toggles ──
        if (aLow.startsWith("olvex:") || cmdLow.startsWith("olvex")) {
            if (aLow === "olvex:sidebar") return qsTr("Toggle Shell Sidebar");
            if (aLow === "olvex:clearnotifs") return qsTr("Clear All Notifications");
            if (aLow === "olvex:showall") return qsTr("Toggle All Shell Drawers");
            if (aLow === "olvex:wallpapers") return qsTr("Open Wallpaper Selector");
            if (aLow === "olvex:refreshdevices") return qsTr("Refresh Connected Devices");
            if (cmdLow.includes("drawers toggle")) {
                const drawerName = cmdLow.split("drawers toggle").pop().trim();
                return qsTr("Toggle %1 Drawer").arg(root.formatAppName(drawerName));
            }
            if (cmdLow.includes("toggle")) {
                const target = cmdLow.split("toggle").pop().trim();
                return qsTr("Toggle %1").arg(root.formatAppName(target));
            }
            if (cmdLow.includes("shell restart")) return qsTr("Restart Olvex Shell");
            if (cmdLow.includes("shell kill")) return qsTr("Kill Olvex Shell");
        }

        // ── 7. Hyprland Workspaces (Native & Scripted) ──
        const isWsAction = cmdLow.includes("wsaction") || d.includes("workspace");
        if (isWsAction) {
            let wsTarget = rawArg;
            let isGroup = cmdLow.includes("-g");
            let isMove = d === "movetoworkspace" || d === "movetoworkspacesilent" || cmdLow.includes("movetoworkspace");
            let isSilent = d === "movetoworkspacesilent" || cmdLow.includes("silent");

            // Extract trailing workspace argument
            const wsTokens = rawArg.split(/\s+/);
            if (wsTokens.length > 0) {
                wsTarget = wsTokens[wsTokens.length - 1];
            }

            let wsLabel = wsTarget;
            if (wsTarget === "e+1" || wsTarget === "+1") wsLabel = qsTr("Next Workspace");
            else if (wsTarget === "e-1" || wsTarget === "-1") wsLabel = qsTr("Previous Workspace");
            else if (wsTarget === "e+10") wsLabel = qsTr("Forward 10 Workspaces");
            else if (wsTarget === "e-10") wsLabel = qsTr("Backward 10 Workspaces");
            else if (wsTarget === "m+1") wsLabel = qsTr("Next Monitor Workspace");
            else if (wsTarget === "m-1") wsLabel = qsTr("Previous Monitor Workspace");
            else if (wsTarget.startsWith("special")) wsLabel = qsTr("Scratchpad");
            else wsLabel = (isGroup ? qsTr("Group %1") : qsTr("Workspace %1")).arg(wsTarget);

            if (d === "togglespecialworkspace") {
                return qsTr("Toggle Scratchpad (%1)").arg(wsTarget || "Default");
            }
            if (isMove) {
                return (isSilent ? qsTr("Move Window to %1 (Silent)") : qsTr("Move Window to %1")).arg(wsLabel);
            }
            return qsTr("Switch to %1").arg(wsLabel);
        }

        // ── 8. Hyprland Window Management ──
        if (d === "killactive") return qsTr("Close Focused Window");
        if (d === "togglefloating") return qsTr("Toggle Window Floating");
        if (d === "fullscreen") return (rawArg === "1" || aLow === "max") ? qsTr("Maximize Window") : qsTr("Toggle Fullscreen Mode");
        if (d === "centerwindow") return qsTr("Center Window on Screen");
        if (d === "pin") return qsTr("Pin Window Across All Workspaces");
        if (d === "pseudo") return qsTr("Toggle Pseudo-Tiling Mode");
        if (d === "togglesplit") return qsTr("Toggle Split Orientation");
        if (d === "cyclenext") return rawArg === "prev" ? qsTr("Cycle Focus to Previous Window") : qsTr("Cycle Focus to Next Window");

        // Groups / Tabs
        if (d === "togglegroup") return qsTr("Toggle Window Group (Tabs)");
        if (d === "changegroupactive") return rawArg === "b" ? qsTr("Previous Tab in Group") : qsTr("Next Tab in Group");
        if (d === "lockactivegroup") return qsTr("Lock / Unlock Window Group");
        if (d === "moveoutofgroup") return qsTr("Detach Window from Group");

        // Directional Move / Focus
        if (d === "movefocus") {
            const dir = root.formatDirection(rawArg);
            return dir ? qsTr("Focus Window (%1)").arg(dir) : qsTr("Focus Window");
        }
        if (d === "movewindow" || d === "movewindoworgroup") {
            const dir = root.formatDirection(rawArg);
            return dir ? qsTr("Move Window (%1)").arg(dir) : qsTr("Move Window");
        }
        if (d === "swapwindow") {
            const dir = root.formatDirection(rawArg);
            return dir ? qsTr("Swap Window (%1)").arg(dir) : qsTr("Swap Window");
        }
        if (d === "resizeactive") {
            if (aLow.includes("exact")) {
                const matchDims = rawArg.match(/exact\s+(\S+)\s+(\S+)/i);
                return matchDims ? qsTr("Resize Window to %1 × %2").arg(matchDims[1]).arg(matchDims[2]) : qsTr("Resize Window (Exact)");
            }
            if (rawArg.includes("0 ") || rawArg.includes(" 0")) {
                const parts = rawArg.split(/\s+/);
                const dx = parts[0] || "0";
                const dy = parts[1] || "0";
                if (dy !== "0") {
                    const isGrow = !dy.includes("-");
                    return (isGrow ? qsTr("Expand Window Height (%1)") : qsTr("Shrink Window Height (%1)")).arg(dy.replace("-", ""));
                }
                if (dx !== "0") {
                    const isGrow = !dx.includes("-");
                    return (isGrow ? qsTr("Expand Window Width (%1)") : qsTr("Shrink Window Width (%1)")).arg(dx.replace("-", ""));
                }
            }
            return qsTr("Resize Active Window (%1)").arg(rawArg);
        }

        // ── 9. Generic Binary Execution (Dynamic App Detection) ──
        if (d === "exec") {
            const binary = cleanedCmd.split(/\s+/)[0];
            const appName = root.formatAppName(binary);
            return qsTr("Open %1").arg(appName);
        }

        if (d === "mouse") {
            return aLow.includes("resize") ? qsTr("Drag to Resize Window") : qsTr("Drag to Move Window");
        }

        return `${dispatcher} ${rawArg}`.trim();
    }

    function iconForBind(dispatcher, arg, key, category) {
        const d = (dispatcher || "").toLowerCase();
        const a = (arg || "").toLowerCase();
        const k = (key || "").toLowerCase();

        // Audio
        if ((a.includes("mute") && a.includes("source")) || k === "xf86audiomicmute") return "mic_off";
        if (a.includes("mute") || k === "xf86audiomute") return "volume_off";
        if ((a.includes("volume") && a.includes("+")) || k === "xf86audioraisevolume") return "volume_up";
        if ((a.includes("volume") && a.includes("-")) || k === "xf86audiolowervolume") return "volume_down";
        if (a.includes("play-pause") || a.includes("mediatoggle") || k === "xf86audioplay") return "play_circle";
        if (a.includes("next") || k === "xf86audionext") return "skip_next";
        if (a.includes("prev") || k === "xf86audioprev") return "skip_previous";
        if (a.includes("stop") || k === "xf86audiostop") return "stop_circle";
        if (a.includes("pavucontrol")) return "tune";

        // Brightness
        if (a.includes("brightness") || k.includes("brightness")) return "brightness_high";

        // Screenshots & Recording
        if (a.includes("record")) return "videocam";
        if (a.includes("screenshot") || a.includes("grim") || a.includes("slurp") || a.includes("flameshot")) return "photo_camera";

        // Shell & Utilities
        if (a.includes("launcher")) return "grid_view";
        if (a.includes("session")) return "power_settings_new";
        if (a.includes("sidebar")) return "vertical_split";
        if (a.includes("wallpaper")) return "wallpaper";
        if (a.includes("lock")) return "lock";
        if (a.includes("clipboard") || a.includes("cliphist")) return "content_paste";
        if (a.includes("emoji")) return "mood";
        if (a.includes("hyprpicker") || a.includes("colorpicker")) return "colorize";

        // Workspaces
        if (d.includes("workspace") || a.includes("workspace")) return "desktop_windows";

        // Windows
        if (d === "killactive") return "close";
        if (d === "togglefloating") return "open_in_new";
        if (d === "fullscreen") return "fullscreen";
        if (d === "centerwindow") return "filter_center_focus";
        if (d === "pin") return "push_pin";
        if (d.includes("group")) return "tab";
        if (d === "movefocus" || d === "movewindow" || d === "swapwindow") return "open_with";
        if (d.includes("resize")) return "aspect_ratio";
        if (d === "pseudo" || d === "togglesplit") return "splitscreen";

        // Apps
        if (a.includes("kitty") || a.includes("foot") || a.includes("alacritty") || a.includes("terminal") || a.includes("wezterm")) return "terminal";
        if (a.includes("firefox") || a.includes("chrome") || a.includes("brave") || a.includes("zen") || a.includes("browser")) return "language";
        if (a.includes("thunar") || a.includes("nemo") || a.includes("nautilus") || a.includes("dolphin") || a.includes("folder")) return "folder";
        if (a.includes("code") || a.includes("vscodium") || a.includes("antigravity") || a.includes("ide")) return "code";
        if (a.includes("qps") || a.includes("btop") || a.includes("htop") || a.includes("sysmon")) return "analytics";
        if (a.includes("systemctl") || a.includes("poweroff") || a.includes("reboot")) return "power_settings_new";

        switch(category) {
            case "olvex": return "desktop_windows";
            case "window": return "crop_square";
            case "workspace": return "view_carousel";
            case "apps": return "launch";
            case "media": return "tune";
            default: return "keyboard";
        }
    }

    function applyKeybindLive(mods, key, dispatcher, arg, bindFlag) {
        const flag = bindFlag || "bind";
        const modStr = Array.isArray(mods) ? mods.join("+") : (mods || "");
        const formattedMods = modStr.length > 0 ? `${modStr}, ` : ", ";
        Quickshell.execDetached(["hyprctl", "keyword", flag, `${formattedMods}${key}, ${dispatcher}, ${arg}`]);
    }

    function unbindKeybindLive(mods, key, bindFlag) {
        const flag = (bindFlag && bindFlag.startsWith("bind")) ? bindFlag.replace("bind", "unbind") : "unbind";
        const modStr = Array.isArray(mods) ? mods.join("+") : (mods || "");
        const formattedMods = modStr.length > 0 ? `${modStr}, ` : ", ";
        Quickshell.execDetached(["hyprctl", "keyword", flag, `${formattedMods}${key}`]);
    }

    function saveKeybind(oldBind, newMods, newKey, newDispatcher, newArg, newFlag) {
        // 1. Live unbind old
        if (oldBind) {
            unbindKeybindLive(oldBind.mods, oldBind.key, oldBind.flag);
        }

        // 2. Live bind new
        const flag = newFlag || (oldBind ? oldBind.flag : "bind");
        applyKeybindLive(newMods, newKey, newDispatcher, newArg, flag);

        // 3. Persist to ~/.config/hypr/hyprland/keybinds.conf
        const oldModStr = oldBind ? (oldBind.mods.join("+") || "") : "";
        const oldKeyStr = oldBind ? oldBind.key : "";
        const newModStr = Array.isArray(newMods) ? newMods.join("+") : (newMods || "");
        
        persistBindsScript.oldMods = oldModStr;
        persistBindsScript.oldKey = oldKeyStr;
        persistBindsScript.newMods = newModStr;
        persistBindsScript.newKey = newKey;
        persistBindsScript.newDispatcher = newDispatcher;
        persistBindsScript.newArg = newArg;
        persistBindsScript.newFlag = flag;
        persistBindsScript.action = oldBind ? "update" : "add";
        persistBindsScript.running = true;
    }

    function deleteKeybind(bind) {
        if (!bind) return;
        unbindKeybindLive(bind.mods, bind.key, bind.flag);

        persistBindsScript.oldMods = bind.mods.join("+") || "";
        persistBindsScript.oldKey = bind.key;
        persistBindsScript.action = "delete";
        persistBindsScript.running = true;
    }

    function startKeyRecording() {
        Quickshell.execDetached(["hyprctl", "--batch", "keyword submap olvex_record ; keyword submap reset ; dispatch submap olvex_record"]);
    }

    function stopKeyRecording() {
        Quickshell.execDetached(["hyprctl", "dispatch", "submap", "reset"]);
    }

    Process {
        id: persistBindsScript

        property string action: "update"
        property string oldMods: ""
        property string oldKey: ""
        property string newMods: ""
        property string newKey: ""
        property string newDispatcher: ""
        property string newArg: ""
        property string newFlag: "bind"

        command: [
            "python3", "-c", `
import os, sys

conf_path = os.path.expanduser("~/.config/hypr/hyprland/keybinds.conf")
if not os.path.exists(conf_path):
    conf_path = os.path.expanduser("~/.config/hypr/hyprland.conf")

action = "${persistBindsScript.action}"
old_mods = "${persistBindsScript.oldMods}".strip().lower()
old_key = "${persistBindsScript.oldKey}".strip().lower()
new_mods = "${persistBindsScript.newMods}".strip()
new_key = "${persistBindsScript.newKey}".strip()
new_disp = "${persistBindsScript.newDispatcher}".strip()
new_arg = "${persistBindsScript.newArg}".strip()
new_flag = "${persistBindsScript.newFlag}".strip()

if os.path.exists(conf_path):
    with open(conf_path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    
    new_line = f"{new_flag} = {new_mods}, {new_key}, {new_disp}, {new_arg}\\n" if new_mods else f"{new_flag} = , {new_key}, {new_disp}, {new_arg}\\n"
    
    found = False
    new_lines = []
    for line in lines:
        stripped = line.strip()
        if not stripped.startswith("#") and ("bind" in stripped):
            if "=" in line:
                flag_part, rest = line.split("=", 1)
                parts = [p.strip() for p in rest.split(",")]
                if len(parts) >= 2:
                    l_mods = parts[0].strip().lower()
                    l_key = parts[1].strip().lower()
                    if l_mods == old_mods and l_key == old_key:
                        found = True
                        if action == "delete":
                            continue
                        elif action == "update":
                            new_lines.append(new_line)
                            continue
        new_lines.append(line)
    
    if (action == "add" or (action == "update" and not found)) and new_line:
        new_lines.append("\\n# Custom Keybind via Olvex\\n" + new_line)
    
    with open(conf_path, "w", encoding="utf-8") as f:
        f.writelines(new_lines)
`
        ]

        onExited: {
            Qt.callLater(() => {
                root.reload();
            });
        }
    }
}
