

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
    property bool isLightEditing: Colours.light
    spacing: Tokens.spacing.large
    opacity: 0.0
    transform: Translate { y: 20; id: yTrans }

    Component.onCompleted: {
        revealAnim.start();
        root.isLightEditing = Colours.light;
    }

    Connections {
        target: Colours
        function onLightChanged() {
            root.isLightEditing = Colours.light;
        }
    }

    ParallelAnimation {
        id: revealAnim
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: 400; easing.type: Easing.OutCubic }
        NumberAnimation { target: yTrans; property: "y"; to: 0; duration: 400; easing.type: Easing.OutCubic }
    }

    Section {
        Layout.fillWidth: true
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
            title: qsTr("Enable blur")
            description: qsTr("Blur background behind translucent surfaces")
            StyledSwitch {
                checked: GlobalConfig.appearance.transparency.blur
                onToggled: {
                    GlobalConfig.appearance.transparency.blur = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Blur radius")
            description: qsTr("Radius and spread of background blur (1–30px)")
            visible: GlobalConfig.appearance.transparency.blur
            StyledSlider {
                width: 280
                from: 1
                to: 30
                stepSize: 1
                value: Colours.transparencyBlurRadius
                onMoved: {
                    GlobalConfig.appearance.transparency.blurRadius = Math.round(value);
                    GlobalConfig.save();
                    Colours.setBlurRadius(value);
                }
            }
        }

        SettingRow {
            title: qsTr("Blur intensity")
            description: qsTr("Number of blur passes (1–5)")
            visible: GlobalConfig.appearance.transparency.blur
            StyledSlider {
                width: 280
                from: 1
                to: 5
                stepSize: 1
                value: Colours.transparencyBlurPasses
                onMoved: {
                    GlobalConfig.appearance.transparency.blurPasses = Math.round(value);
                    GlobalConfig.save();
                    Colours.setBlurPasses(value);
                }
            }
        }

        SettingRow {
            title: qsTr("Mode target")
            description: qsTr("Adjust opacity settings for Dark or Light mode")
            divider: true
            Segmented {
                model: [
                    { label: qsTr("Dark") },
                    { label: qsTr("Light") }
                ]
                currentIndex: root.isLightEditing ? 1 : 0
                onSelected: i => {
                    root.isLightEditing = (i === 1);
                }
            }
        }

        SettingRow {
            title: qsTr("Base opacity")
            description: root.isLightEditing
                ? qsTr("Panel background opacity in Light mode")
                : qsTr("Panel background opacity in Dark mode")
            divider: true
            StyledSlider {
                width: 280
                from: 0
                to: 1
                value: root.isLightEditing
                    ? (GlobalConfig.appearance.transparency.baseLight !== undefined ? GlobalConfig.appearance.transparency.baseLight : GlobalConfig.appearance.transparency.base)
                    : (GlobalConfig.appearance.transparency.baseDark !== undefined ? GlobalConfig.appearance.transparency.baseDark : GlobalConfig.appearance.transparency.base)
                onMoved: {
                    if (root.isLightEditing) {
                        GlobalConfig.appearance.transparency.baseLight = value;
                    } else {
                        GlobalConfig.appearance.transparency.baseDark = value;
                    }
                    if (root.isLightEditing === Colours.light) {
                        GlobalConfig.appearance.transparency.base = value;
                    }
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Layer opacity")
            description: root.isLightEditing
                ? qsTr("Raised card & surface opacity in Light mode")
                : qsTr("Raised card & surface opacity in Dark mode")
            divider: false
            StyledSlider {
                width: 280
                from: 0
                to: 1
                value: root.isLightEditing
                    ? (GlobalConfig.appearance.transparency.layersLight !== undefined ? GlobalConfig.appearance.transparency.layersLight : GlobalConfig.appearance.transparency.layers)
                    : (GlobalConfig.appearance.transparency.layersDark !== undefined ? GlobalConfig.appearance.transparency.layersDark : GlobalConfig.appearance.transparency.layers)
                onMoved: {
                    if (root.isLightEditing) {
                        GlobalConfig.appearance.transparency.layersLight = value;
                    } else {
                        GlobalConfig.appearance.transparency.layersDark = value;
                    }
                    if (root.isLightEditing === Colours.light) {
                        GlobalConfig.appearance.transparency.layers = value;
                    }
                    GlobalConfig.save();
                }
            }
        }
    }
}
