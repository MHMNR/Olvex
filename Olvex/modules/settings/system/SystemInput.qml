import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Olvex
import Olvex.Config
import qs.services

Item {
    id: root

    property Session session
    property var appJoin
    property var appSplit
    property var idxOf

    // Mouse state
    property real mouseSensitivity: 0.0
    property string accelProfile: "adaptive"
    property bool mouseNaturalScroll: false
    property bool leftHanded: false

    // Touchpad state
    property bool touchpadTapToClick: true
    property bool touchpadNaturalScroll: true
    property bool touchpadDisableWhileTyping: true
    property real touchpadScrollFactor: 1.0

    // Keyboard state
    property string kbLayout: "us"
    property int repeatRate: 35
    property int repeatDelay: 250
    property bool numlockByDefault: false

    readonly property var layoutOptions: [
        { label: qsTr("English (US)"), val: "us" },
        { label: qsTr("English (UK)"), val: "gb" },
        { label: qsTr("Bengali (BD)"), val: "bd" },
        { label: qsTr("German (DE)"), val: "de" },
        { label: qsTr("French (FR)"), val: "fr" },
        { label: qsTr("Spanish (ES)"), val: "es" },
        { label: qsTr("Japanese (JP)"), val: "jp" },
        { label: qsTr("Indian (IN)"), val: "in" },
        { label: qsTr("Russian (RU)"), val: "ru" },
        { label: qsTr("Arabic (ARA)"), val: "ara" }
    ]

    function buildLuaConfig() {
        return "hl.config({ input = { " +
            "sensitivity = " + root.mouseSensitivity.toFixed(2) + ", " +
            "accel_profile = \"" + root.accelProfile + "\", " +
            "natural_scroll = " + (root.mouseNaturalScroll ? "true" : "false") + ", " +
            "left_handed = " + (root.leftHanded ? "true" : "false") + ", " +
            "kb_layout = \"" + root.kbLayout + "\", " +
            "repeat_rate = " + Math.round(root.repeatRate) + ", " +
            "repeat_delay = " + Math.round(root.repeatDelay) + ", " +
            "numlock_by_default = " + (root.numlockByDefault ? "true" : "false") + ", " +
            "touchpad = { " +
                "tap_to_click = " + (root.touchpadTapToClick ? "true" : "false") + ", " +
                "natural_scroll = " + (root.touchpadNaturalScroll ? "true" : "false") + ", " +
                "disable_while_typing = " + (root.touchpadDisableWhileTyping ? "true" : "false") + ", " +
                "scroll_factor = " + root.touchpadScrollFactor.toFixed(2) + " " +
            "} } })";
    }

    function applyHyprOption(key, value) {
        const luaCmd = buildLuaConfig();
        Quickshell.execDetached(["hyprctl", "eval", luaCmd]);
        persistTimer.restart();
    }

    function parseHyprJsonVal(txt, fallback) {
        try {
            const obj = JSON.parse(txt);
            if (obj.bool !== undefined) return obj.bool;
            if (obj.float !== undefined) return obj.float;
            if (obj.int !== undefined) return obj.int;
            if (obj.str !== undefined) return obj.str;
        } catch (e) {}
        return fallback;
    }

    Timer {
        id: persistTimer
        interval: 200
        repeat: false
        onTriggered: {
            const luaFile = "-- Managed by Olvex Input Settings\n" + root.buildLuaConfig() + "\n";
            persistProc.command = ["bash", "-c", "mkdir -p ~/.config/olvex && printf '%s' \"$1\" > ~/.config/olvex/hypr-input.lua", "sh", luaFile];
            persistProc.running = true;
        }
    }

    Process {
        id: persistProc
    }

    Process {
        id: loadProc
        running: true
        command: [
            "bash", "-c",
            "for opt in " +
            "input:sensitivity input:accel_profile input:natural_scroll input:left_handed " +
            "input:touchpad:tap-to-click input:touchpad:natural_scroll input:touchpad:disable_while_typing input:touchpad:scroll_factor " +
            "input:kb_layout input:repeat_rate input:repeat_delay input:numlock_by_default; do " +
            "printf '%s=' \"$opt\"; hyprctl -j getoption \"$opt\" 2>/dev/null | tr -d '\\n'; echo ''; " +
            "done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = (text || "").split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim();
                    const eq = line.indexOf("=");
                    if (eq <= 0) continue;
                    const k = line.slice(0, eq);
                    const raw = line.slice(eq + 1);
                    if (k === "input:sensitivity") root.mouseSensitivity = Number(root.parseHyprJsonVal(raw, 0.0));
                    else if (k === "input:accel_profile") {
                        const s = String(root.parseHyprJsonVal(raw, "adaptive")).trim();
                        root.accelProfile = (s === "flat") ? "flat" : "adaptive";
                    }
                    else if (k === "input:natural_scroll") root.mouseNaturalScroll = Boolean(root.parseHyprJsonVal(raw, 0));
                    else if (k === "input:left_handed") root.leftHanded = Boolean(root.parseHyprJsonVal(raw, 0));
                    else if (k === "input:touchpad:tap-to-click") root.touchpadTapToClick = Boolean(root.parseHyprJsonVal(raw, 1));
                    else if (k === "input:touchpad:natural_scroll") root.touchpadNaturalScroll = Boolean(root.parseHyprJsonVal(raw, 1));
                    else if (k === "input:touchpad:disable_while_typing") root.touchpadDisableWhileTyping = Boolean(root.parseHyprJsonVal(raw, 1));
                    else if (k === "input:touchpad:scroll_factor") root.touchpadScrollFactor = Number(root.parseHyprJsonVal(raw, 1.0));
                    else if (k === "input:kb_layout") root.kbLayout = String(root.parseHyprJsonVal(raw, "us")).trim() || "us";
                    else if (k === "input:repeat_rate") root.repeatRate = Number(root.parseHyprJsonVal(raw, 35));
                    else if (k === "input:repeat_delay") root.repeatDelay = Number(root.parseHyprJsonVal(raw, 250));
                    else if (k === "input:numlock_by_default") root.numlockByDefault = Boolean(root.parseHyprJsonVal(raw, 0));
                }
            }
        }
    }

    opacity: 0
    y: 10
    Component.onCompleted: cascadeIn.start()

    ParallelAnimation {
        id: cascadeIn
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens.anim.durations.normal || 300; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens.anim.durations.normal || 300; easing.type: Easing.OutCubic }
    }

    implicitHeight: (col ? col.implicitHeight : 0) + Tokens.padding.large * 2

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Tokens.padding.large
        anchors.rightMargin: Tokens.padding.large
        anchors.topMargin: Tokens.padding.large
        spacing: Tokens.spacing.large

        Section {
            Layout.fillWidth: true
            title: qsTr("Mouse & Pointer")
            description: qsTr("Cursor speed, acceleration, and button orientation")
            icon: "mouse"
            accentColor: Colours.palette.m3secondary

            SettingRow {
                title: qsTr("Pointer sensitivity")
                description: qsTr("Current speed: %1").arg(root.mouseSensitivity.toFixed(2))
                StyledSlider {
                    implicitWidth: 220
                    from: -1.0
                    to: 1.0
                    stepSize: 0.05
                    value: root.mouseSensitivity
                    onMoved: {
                        root.mouseSensitivity = Number(value.toFixed(2));
                        root.applyHyprOption("input:sensitivity", root.mouseSensitivity);
                    }
                }
            }

            SettingRow {
                title: qsTr("Acceleration profile")
                description: qsTr("Adaptive applies dynamic curve; Flat keeps 1:1 raw input")
                Segmented {
                    minSegmentWidth: 96
                    model: [
                        { label: qsTr("Adaptive") },
                        { label: qsTr("Flat") }
                    ]
                    currentIndex: root.accelProfile === "flat" ? 1 : 0
                    onSelected: i => {
                        root.accelProfile = i === 1 ? "flat" : "adaptive";
                        root.applyHyprOption("input:accel_profile", root.accelProfile);
                    }
                }
            }

            SettingRow {
                title: qsTr("Natural scrolling")
                description: qsTr("Invert mouse wheel scroll direction")
                StyledSwitch {
                    checked: root.mouseNaturalScroll
                    onToggled: {
                        root.mouseNaturalScroll = checked;
                        root.applyHyprOption("input:natural_scroll", checked ? "true" : "false");
                    }
                }
            }

            SettingRow {
                title: qsTr("Left-handed mode")
                description: qsTr("Swap primary and secondary mouse buttons")
                StyledSwitch {
                    checked: root.leftHanded
                    onToggled: {
                        root.leftHanded = checked;
                        root.applyHyprOption("input:left_handed", checked ? "true" : "false");
                    }
                }
            }
        }

        Section {
            Layout.fillWidth: true
            title: qsTr("Touchpad")
            description: qsTr("Gestures, tap behavior, and palm rejection")
            icon: "touch_app"
            accentColor: Colours.palette.m3secondary

            SettingRow {
                title: qsTr("Tap to click")
                description: qsTr("Single tap registers as left click")
                StyledSwitch {
                    checked: root.touchpadTapToClick
                    onToggled: {
                        root.touchpadTapToClick = checked;
                        root.applyHyprOption("input:touchpad:tap-to-click", checked ? "true" : "false");
                    }
                }
            }

            SettingRow {
                title: qsTr("Natural scrolling")
                description: qsTr("Content follows finger movement direction")
                StyledSwitch {
                    checked: root.touchpadNaturalScroll
                    onToggled: {
                        root.touchpadNaturalScroll = checked;
                        root.applyHyprOption("input:touchpad:natural_scroll", checked ? "true" : "false");
                    }
                }
            }

            SettingRow {
                title: qsTr("Disable while typing")
                description: qsTr("Ignore accidental palm touches while using keyboard")
                StyledSwitch {
                    checked: root.touchpadDisableWhileTyping
                    onToggled: {
                        root.touchpadDisableWhileTyping = checked;
                        root.applyHyprOption("input:touchpad:disable_while_typing", checked ? "true" : "false");
                    }
                }
            }

            SettingRow {
                title: qsTr("Scroll speed")
                description: qsTr("Multiplier: %1x").arg(root.touchpadScrollFactor.toFixed(1))
                StyledSlider {
                    implicitWidth: 220
                    from: 0.2
                    to: 3.0
                    stepSize: 0.1
                    value: root.touchpadScrollFactor
                    onMoved: {
                        root.touchpadScrollFactor = Number(value.toFixed(1));
                        root.applyHyprOption("input:touchpad:scroll_factor", root.touchpadScrollFactor);
                    }
                }
            }
        }

        Section {
            Layout.fillWidth: true
            title: qsTr("Keyboard")
            description: qsTr("Keymap layout, key repeat timing, and NumLock behavior")
            icon: "keyboard"
            accentColor: Colours.palette.m3secondary

            SettingRow {
                title: qsTr("Keyboard layout")
                description: qsTr("Active XKB layout: %1").arg(root.kbLayout)
                OptionPicker {
                    id: layoutPicker
                    model: root.layoutOptions
                    currentIndex: {
                        const idx = root.layoutOptions.findIndex(o => o.val === root.kbLayout);
                        return idx >= 0 ? idx : 0;
                    }
                    onSelected: i => {
                        const opt = root.layoutOptions[i];
                        if (opt) {
                            root.kbLayout = opt.val;
                            root.applyHyprOption("input:kb_layout", opt.val);
                        }
                    }
                }
            }

            SettingRow {
                title: qsTr("Repeat rate")
                description: qsTr("%1 characters per second").arg(root.repeatRate)
                StyledSlider {
                    implicitWidth: 220
                    from: 10
                    to: 80
                    stepSize: 5
                    value: root.repeatRate
                    onMoved: {
                        root.repeatRate = Math.round(value);
                        root.applyHyprOption("input:repeat_rate", root.repeatRate);
                    }
                }
            }

            SettingRow {
                title: qsTr("Repeat delay")
                description: qsTr("%1 ms before held key starts repeating").arg(root.repeatDelay)
                StyledSlider {
                    implicitWidth: 220
                    from: 100
                    to: 800
                    stepSize: 25
                    value: root.repeatDelay
                    onMoved: {
                        root.repeatDelay = Math.round(value);
                        root.applyHyprOption("input:repeat_delay", root.repeatDelay);
                    }
                }
            }

            SettingRow {
                title: qsTr("NumLock on startup")
                description: qsTr("Enable NumLock automatically when session starts")
                StyledSwitch {
                    checked: root.numlockByDefault
                    onToggled: {
                        root.numlockByDefault = checked;
                        root.applyHyprOption("input:numlock_by_default", checked ? "true" : "false");
                    }
                }
            }
        }
    }
}

