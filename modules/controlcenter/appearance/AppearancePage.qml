pragma ComponentBehavior: Bound

import ".."
import "../chrome"
import "../../launcher/services"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    property Session session
    signal back

    function idxOf(list, val) {
        for (let i = 0; i < list.length; i++) {
            if (list[i] === val)
                return i;
        }
        return 0;
    }

    function modeIndex() {
        const m = GlobalConfig.appearance.themeMode;
        if (m === "light")
            return 0;
        if (m === "dark")
            return 1;
        return 2;
    }

    SettingsPage {
        anchors.fill: parent
        title: qsTr("Appearance")
        subtitle: qsTr("Theme, colors, fonts and motion")
        icon: "palette"
        accent: Colours.palette.m3tertiary
        onBack: root.back()

        Section {
            title: qsTr("Theme")
            description: qsTr("Light, dark, or automatic switching")
            icon: "contrast"

            SettingRow {
                title: qsTr("Mode")
                description: qsTr("Follow a fixed appearance or switch automatically")
                divider: false

                Segmented {
                    model: [{
                            label: qsTr("Light"),
                            icon: "light_mode"
                        }, {
                            label: qsTr("Dark"),
                            icon: "dark_mode"
                        }, {
                            label: qsTr("Auto"),
                            icon: "brightness_auto"
                        }]
                    currentIndex: root.modeIndex()
                    onSelected: i => {
                        const next = ["light", "dark", "auto"][i];
                        GlobalConfig.appearance.themeMode = next;
                        GlobalConfig.save();
                        Colours.setMode(next);
                    }
                }
            }
        }

        Section {
            title: qsTr("Color")
            description: qsTr("Scheme variant and generation engine")
            icon: "format_paint"

            SettingRow {
                title: qsTr("Scheme variant")
                description: qsTr("Algorithm that maps the seed into a full palette")
                OptionPicker {
                    id: variantPicker
                    model: ["tonalspot", "vibrant", "expressive", "fidelity", "content", "neutral", "monochrome"]
                    currentIndex: {
                        const v = (Schemes.currentVariant || "tonalspot").toLowerCase();
                        return root.idxOf(variantPicker.model, v);
                    }
                    onSelected: i => Schemes.setVariant(variantPicker.model[i])
                }
            }

            SettingRow {
                title: qsTr("Color engine")
                description: qsTr("Expressive (Material 3) or the legacy generator")
                Segmented {
                    model: [{
                            label: qsTr("Expressive")
                        }, {
                            label: qsTr("Legacy")
                        }]
                    currentIndex: (GlobalConfig.services.colorEngine || "expressive") === "expressive" ? 0 : 1
                    onSelected: i => {
                        GlobalConfig.services.colorEngine = i === 0 ? "expressive" : "legacy";
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Smart scheme")
                description: qsTr("Derive the palette from wallpaper content")
                divider: false
                StyledSwitch {
                    checked: GlobalConfig.services.smartScheme
                    onToggled: {
                        GlobalConfig.services.smartScheme = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            title: qsTr("Transparency")
            description: qsTr("Glass surfaces across the shell")
            icon: "opacity"

            SettingRow {
                title: qsTr("Enable transparency")
                description: qsTr("Make panels and popups translucent")
                StyledSwitch {
                    checked: GlobalConfig.appearance.transparency.enabled
                    onToggled: {
                        GlobalConfig.appearance.transparency.enabled = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Base opacity")
                description: qsTr("Opacity of panel backgrounds")
                StyledSlider {
                    width: 220
                    from: 0.3
                    to: 1
                    value: GlobalConfig.appearance.transparency.base
                    onMoved: {
                        GlobalConfig.appearance.transparency.base = value;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Layer opacity")
                description: qsTr("Opacity of raised surfaces and cards")
                divider: false
                StyledSlider {
                    width: 220
                    from: 0.1
                    to: 1
                    value: GlobalConfig.appearance.transparency.layers
                    onMoved: {
                        GlobalConfig.appearance.transparency.layers = value;
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            title: qsTr("Fonts")
            description: qsTr("Typeface families and global text size")
            icon: "text_fields"

            SettingRow {
                title: qsTr("Sans-serif")
                description: qsTr("Primary interface font — full system list, scrollable")
                OptionPicker {
                    id: sansPicker
                    menuMaxHeight: 360
                    // All installed families; menu scrolls (Menu.maxHeight)
                    model: Qt.fontFamilies()
                    currentIndex: {
                        const cur = GlobalConfig.appearance.font.family.sans || "Rubik";
                        const i = root.idxOf(sansPicker.model, cur);
                        return i;
                    }
                    onSelected: i => {
                        GlobalConfig.appearance.font.family.sans = sansPicker.model[i];
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Monospace")
                description: qsTr("Font for numbers, code and clocks")
                OptionPicker {
                    id: monoPicker
                    menuMaxHeight: 360
                    // Prefer mono-like families; fall back to full list if filter empty
                    model: {
                        const all = Qt.fontFamilies();
                        const mono = all.filter(f => /mono|code|consolas|jetbrains|fira|iosevka|hack|source code|cascadia|caskaydia|nerd|sf mono|ubuntu mono|dejavu sans mono|droid sans mono|liberation mono|comic mono|maple|victor|inconsolata|anonymous|courier|menlo|monaco/i.test(f));
                        return mono.length > 0 ? mono : all;
                    }
                    currentIndex: {
                        const cur = GlobalConfig.appearance.font.family.mono || "CaskaydiaCove NF";
                        return root.idxOf(monoPicker.model, cur);
                    }
                    onSelected: i => {
                        GlobalConfig.appearance.font.family.mono = monoPicker.model[i];
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Font size")
                description: qsTr("Global multiplier for all text")
                divider: false
                StyledSlider {
                    width: 220
                    from: 0.8
                    to: 1.3
                    value: GlobalConfig.appearance.font.size.scale
                    onMoved: {
                        GlobalConfig.appearance.font.size.scale = value;
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            title: qsTr("Shape & spacing")
            description: qsTr("Corner rounding, density, and drawer Hugging / Floating mode")
            icon: "aspect_ratio"

            SettingRow {
                title: qsTr("Rounding scale")
                description: qsTr("Multiplier for all corner radii")
                StyledSlider {
                    width: 220
                    from: 0.5
                    to: 1.5
                    value: GlobalConfig.appearance.rounding.scale
                    onMoved: {
                        GlobalConfig.appearance.rounding.scale = value;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Spacing scale")
                description: qsTr("Multiplier for gaps between elements")
                StyledSlider {
                    width: 220
                    from: 0.5
                    to: 1.5
                    value: GlobalConfig.appearance.spacing.scale
                    onMoved: {
                        GlobalConfig.appearance.spacing.scale = value;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Padding scale")
                description: qsTr("Multiplier for padding inside elements")
                StyledSlider {
                    width: 220
                    from: 0.5
                    to: 1.5
                    value: GlobalConfig.appearance.padding.scale
                    onMoved: {
                        GlobalConfig.appearance.padding.scale = value;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Drawer mode")
                description: qsTr("Hugging sticks panels to screen edges; Floating leaves a gap")
                Segmented {
                    minSegmentWidth: 100
                    implicitHeight: 42
                    model: [{
                            label: qsTr("Hugging"),
                            icon: "align_horizontal_left"
                        }, {
                            label: qsTr("Floating"),
                            icon: "picture_in_picture_center"
                        }]
                    // floating=true → Floating (index 1); false → Hugging (index 0)
                    currentIndex: GlobalConfig.border.floating ? 1 : 0
                    onSelected: i => {
                        GlobalConfig.border.floating = (i === 1);
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Border thickness")
                description: qsTr("Gap / border size around drawers and panels")
                CustomSpinBox {
                    value: GlobalConfig.border.thickness
                    min: 0
                    max: 40
                    step: 2
                    onValueModified: v => {
                        GlobalConfig.border.thickness = v;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Border rounding")
                description: qsTr("Corner radius of the screen border")
                divider: false
                CustomSpinBox {
                    value: GlobalConfig.border.rounding
                    min: 0
                    max: 40
                    step: 2
                    onValueModified: v => {
                        GlobalConfig.border.rounding = v;
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            title: qsTr("Motion")
            description: qsTr("Animation timing across the shell")
            icon: "animation"

            SettingRow {
                title: qsTr("Animation speed")
                description: qsTr("Multiplier for all durations — lower is faster")
                divider: false
                StyledSlider {
                    width: 220
                    from: 0.5
                    to: 1.5
                    value: GlobalConfig.appearance.anim.durations.scale
                    onMoved: {
                        GlobalConfig.appearance.anim.durations.scale = value;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }
}
