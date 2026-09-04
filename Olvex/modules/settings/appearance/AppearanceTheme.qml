pragma ComponentBehavior: Bound


import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.services

ColumnLayout {
    id: root
    
    property Session session
    spacing: Tokens.spacing.large
    opacity: 0.0
    transform: Translate { y: 20; id: yTrans }

    Component.onCompleted: {
        revealAnim.start();
    }

    ParallelAnimation {
        id: revealAnim
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: 400; easing.type: Easing.OutCubic }
        NumberAnimation { target: yTrans; property: "y"; to: 0; duration: 400; easing.type: Easing.OutCubic }
    }
    
    readonly property var schemeModel: [
        { name: "dynamic", flavour: "default", label: qsTr("Dynamic"), modes: ["light", "dark", "auto"] },
        { name: "catppuccin", flavour: "mocha", label: qsTr("Catppuccin Mocha"), modes: ["dark"] },
        { name: "catppuccin", flavour: "frappe", label: qsTr("Catppuccin Frappe"), modes: ["dark"] },
        { name: "gruvbox", flavour: "medium", label: qsTr("Gruvbox"), modes: ["light", "dark", "auto"] },
        { name: "rosepine", flavour: "main", label: qsTr("Rosé Pine"), modes: ["dark"] },
        { name: "nord", flavour: "medium", label: qsTr("Nord"), modes: ["dark"] },
        { name: "dracula", flavour: "medium", label: qsTr("Dracula"), modes: ["light", "dark", "auto"] },
        { name: "solarized", flavour: "medium", label: qsTr("Solarized"), modes: ["dark"] },
        { name: "monokai", flavour: "default", label: qsTr("Monokai"), modes: ["light", "dark", "auto"] },
        { name: "oxocarbon", flavour: "default", label: qsTr("Oxocarbon"), modes: ["light", "dark", "auto"] }
    ]
    
    readonly property var currentScheme: {
        const n = Colours.schemeName.toLowerCase();
        const f = Colours.schemeFlavour.toLowerCase();
        for (let i = 0; i < schemeModel.length; i++) {
            if (schemeModel[i].name === n && schemeModel[i].flavour === f) return schemeModel[i];
        }
        for (let i = 0; i < schemeModel.length; i++) {
            if (schemeModel[i].name === n) return schemeModel[i];
        }
        return schemeModel[0];
    }
    
    function idxOf(list, val) {
        for (let i = 0; i < list.length; i++) {
            if (list[i] === val) return i;
        }
        return 0;
    }
    
    function modeIndex() {
        const m = GlobalConfig.appearance.themeMode;
        if (m === "light") return 0;
        if (m === "dark") return 1;
        return 2;
    }

    Section {
        Layout.fillWidth: true
        title: qsTr("Theme")
        description: qsTr("Light, dark, or automatic switching")
        icon: "contrast"

        SettingRow {
            title: qsTr("Mode")
            description: qsTr("Follow a fixed appearance or switch automatically")
            divider: true

            Segmented {
                property var supportedModes: root.currentScheme ? root.currentScheme.modes : ["light", "dark", "auto"]
                model: [
                    { label: qsTr("Light"), icon: "light_mode", disabled: !supportedModes.includes("light") },
                    { label: qsTr("Dark"), icon: "dark_mode", disabled: !supportedModes.includes("dark") },
                    { label: qsTr("Auto"), icon: "brightness_auto", disabled: !supportedModes.includes("auto") }
                ]
                currentIndex: root.modeIndex()
                onSelected: i => {
                    const next = ["light", "dark", "auto"][i];
                    GlobalConfig.appearance.themeMode = next;
                    GlobalConfig.save();
                    Colours.setMode(next);
                }
            }
        }

        SettingRow {
            title: qsTr("Scheme")
            description: qsTr("Source of the color palette")
            divider: true
            OptionPicker {
                id: schemePicker
                model: root.schemeModel
                currentIndex: {
                    const n = Colours.schemeName.toLowerCase();
                    const f = Colours.schemeFlavour.toLowerCase();
                    for (let i = 0; i < model.length; i++) {
                        if (model[i].name === n && model[i].flavour === f) return i;
                    }
                    for (let i = 0; i < model.length; i++) {
                        if (model[i].name === n) return i;
                    }
                    return 0; // Default to Dynamic
                }
                onSelected: i => {
                    const m = model[i];
                    Colours.setSchemeName(m.name, m.flavour);
                    
                    if (m.modes && !m.modes.includes(GlobalConfig.appearance.themeMode)) {
                        const next = m.modes.includes("dark") ? "dark" : (m.modes[0] || "dark");
                        GlobalConfig.appearance.themeMode = next;
                        GlobalConfig.save();
                        Colours.setMode(next);
                    }
                }
            }
        }
        
        SettingRow {
            title: qsTr("Variant")
            visible: Colours.schemeName.toLowerCase() === "dynamic"
            description: qsTr("Algorithm that maps the seed into a full palette")
            divider: false
            OptionPicker {
                id: variantPicker
                model: ["tonalspot", "vibrant", "expressive", "fidelity", "fruitsalad", "content", "neutral", "monochrome"]
                currentIndex: {
                    const v = (GlobalConfig.appearance.schemeVariant || "tonalspot").toLowerCase();
                    return root.idxOf(variantPicker.model, v);
                }
                onSelected: i => {
                    GlobalConfig.appearance.schemeVariant = variantPicker.model[i];
                    GlobalConfig.save();
                }
            }
        }
    }

    Section {
        Layout.fillWidth: true
        title: qsTr("Night light")
        description: qsTr("Reduce blue light and eye strain")
        icon: "nights_stay"

        SettingRow {
            title: qsTr("Night light")
            description: qsTr("Warm display color temperature")
            divider: true
            StyledSwitch {
                checked: NightLight.enabled
                onToggled: NightLight.enabled = checked
            }
        }

        SettingRow {
            title: qsTr("Automatic schedule")
            description: qsTr("Transition smoothly with sunset and sunrise")
            divider: true
            StyledSwitch {
                checked: NightLight.autoSchedule
                onToggled: NightLight.autoSchedule = checked
            }
        }

        SettingRow {
            title: qsTr("Color temperature")
            description: qsTr("Display warmth: %1K").arg(NightLight.temperature)
            divider: false
            StyledSlider {
                implicitWidth: 220
                from: 2500
                to: 6500
                stepSize: 100
                value: NightLight.temperature
                onMoved: NightLight.temperature = Math.round(value)
            }
        }
    }
}
