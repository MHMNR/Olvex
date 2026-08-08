pragma ComponentBehavior: Bound


import "../.."
import "../../chrome"
import "../../components"
import "../../../../components"
import "../../../../components/controls"
import "../../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.services

CollapsibleSection {
    id: root

    required property var rootPane

    title: qsTr("Background")
    description: qsTr("Wallpaper, live wallpaper, cycling, and desktop clock")
    showBackground: true

    SwitchRow {
        label: qsTr("Background enabled")
        checked: rootPane.backgroundEnabled
        onToggled: checked => {
            rootPane.backgroundEnabled = checked;
            rootPane.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("Wallpaper enabled")
        checked: rootPane.wallpaperEnabled
        onToggled: checked => {
            rootPane.wallpaperEnabled = checked;
            rootPane.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("Per-monitor wallpaper")
        checked: rootPane.perMonitorWallpaper
        onToggled: checked => {
            rootPane.perMonitorWallpaper = checked;
            rootPane.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("Live wallpaper")
        checked: rootPane.liveWallpaperEnabled
        onToggled: checked => {
            rootPane.liveWallpaperEnabled = checked;
            rootPane.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("Mute live wallpaper")
        checked: rootPane.liveWallpaperMuted
        onToggled: checked => {
            rootPane.liveWallpaperMuted = checked;
            rootPane.saveConfig();
        }
    }

    SectionContainer {
        id: wallpaperTransitionSection

        contentSpacing: Tokens.spacing.small

        StyledText {
            text: qsTr("Wallpaper Transition")
            textPointSize: Tokens.font.size.larger
            font.weight: 400
        }

        SplitButtonRow {
            id: transitionTypeRow

            label: qsTr("Transition type")
            expandedZ: 400
            readonly property var transitionItems: [fadeItem, wipeItem, discItem, stripesItem, irisItem, pixelateItem, portalItem, randomItem, noneItem]

            menuItems: [
                MenuItem { id: fadeItem; property string val: "fade"; text: qsTr("Fade"); icon: "gradient" },
                MenuItem { id: wipeItem; property string val: "wipe"; text: qsTr("Wipe"); icon: "swipe" },
                MenuItem { id: discItem; property string val: "disc"; text: qsTr("Disc"); icon: "radio_button_checked" },
                MenuItem { id: stripesItem; property string val: "stripes"; text: qsTr("Stripes"); icon: "reorder" },
                MenuItem { id: irisItem; property string val: "iris bloom"; text: qsTr("Iris Bloom"); icon: "flare" },
                MenuItem { id: pixelateItem; property string val: "pixelate"; text: qsTr("Pixelate"); icon: "blur_on" },
                MenuItem { id: portalItem; property string val: "portal"; text: qsTr("Portal"); icon: "lens_blur" },
                MenuItem { id: randomItem; property string val: "random"; text: qsTr("Random"); icon: "shuffle" },
                MenuItem { id: noneItem; property string val: "none"; text: qsTr("None"); icon: "hide_image" }
            ]

            function indexFor(val: string): int {
                for (let i = 0; i < transitionItems.length; i++) {
                    if (transitionItems[i].val === val)
                        return i;
                }
                return 0;
            }

            Component.onCompleted: {
                active = transitionItems[indexFor(GlobalConfig.background?.wallpaperTransition?.type ?? rootPane.wallpaperTransitionType)];
            }

            onSelected: item => {
                const selectedType = item?.val ?? "fade";
                rootPane.wallpaperTransitionType = selectedType;
                if (GlobalConfig.background?.wallpaperTransition)
                    GlobalConfig.background.wallpaperTransition.type = selectedType;
                rootPane.saveConfig();
            }
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Duration")
            value: rootPane.wallpaperTransitionDuration
            from: 200
            to: 3000
            suffix: "ms"
            validator: IntValidator { bottom: 200; top: 3000 }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)
            onValueModified: newValue => {
                const duration = Math.round(newValue);
                rootPane.wallpaperTransitionDuration = duration;
                if (GlobalConfig.background?.wallpaperTransition)
                    GlobalConfig.background.wallpaperTransition.duration = duration;
                rootPane.saveConfig();
            }
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Edge smoothness")
            value: rootPane.wallpaperTransitionEdgeSmoothness
            from: 0
            to: 1
            decimals: 2
            validator: DoubleValidator { bottom: 0; top: 1 }
            onValueModified: newValue => {
                rootPane.wallpaperTransitionEdgeSmoothness = newValue;
                if (GlobalConfig.background?.wallpaperTransition)
                    GlobalConfig.background.wallpaperTransition.edgeSmoothness = newValue;
                rootPane.saveConfig();
            }
        }
    }

    SectionContainer {
        StyledText {
            text: qsTr("Cycling")
            textPointSize: Tokens.font.size.larger
            font.weight: 400
        }

        SwitchRow {
            label: qsTr("Enabled")
            checked: rootPane.wallpaperCyclingEnabled
            onToggled: checked => {
                rootPane.wallpaperCyclingEnabled = checked;
                rootPane.saveConfig();
            }
        }

        SwitchRow {
            label: qsTr("Shuffle")
            checked: rootPane.wallpaperCyclingShuffle
            onToggled: checked => {
                rootPane.wallpaperCyclingShuffle = checked;
                rootPane.saveConfig();
            }
        }

        SwitchRow {
            label: qsTr("Pause on fullscreen")
            checked: rootPane.wallpaperCyclingPauseOnFullscreen
            onToggled: checked => {
                rootPane.wallpaperCyclingPauseOnFullscreen = checked;
                rootPane.saveConfig();
            }
        }

        SwitchRow {
            label: qsTr("Pause on lock")
            checked: rootPane.wallpaperCyclingPauseOnLock
            onToggled: checked => {
                rootPane.wallpaperCyclingPauseOnLock = checked;
                rootPane.saveConfig();
            }
        }

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Interval")
            value: rootPane.wallpaperCyclingIntervalSeconds
            from: 5
            to: 3600
            suffix: "s"
            validator: IntValidator { bottom: 5; top: 3600 }
            formatValueFunction: value => Math.round(value).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                rootPane.wallpaperCyclingIntervalSeconds = Math.round(newValue);
                rootPane.saveConfig();
            }
        }
    }

    StyledText {
        Layout.topMargin: Tokens.spacing.normal
        text: qsTr("Desktop Clock")
        textPointSize: Tokens.font.size.larger
        font.weight: 400
    }

    SwitchRow {
        label: qsTr("Desktop Clock enabled")
        checked: rootPane.desktopClockEnabled
        onToggled: checked => {
            rootPane.desktopClockEnabled = checked;
            rootPane.saveConfig();
        }
    }

    SectionContainer {
        id: posContainer

        readonly property var pos: (rootPane.desktopClockPosition || "top-left").split('-')
        readonly property string currentV: pos[0]
        readonly property string currentH: pos[1]

        function updateClockPos(v, h) {
            rootPane.desktopClockPosition = v + "-" + h;
            rootPane.saveConfig();
        }

        contentSpacing: Tokens.spacing.small
        z: 1

        StyledText {
            text: qsTr("Positioning")
            textPointSize: Tokens.font.size.larger
            font.weight: 400
        }

        SplitButtonRow {
            label: qsTr("Vertical Position")
            enabled: rootPane.desktopClockEnabled

            menuItems: [
                MenuItem {
                    property string val: "top"

                    text: qsTr("Top")
                    icon: "vertical_align_top"
                },
                MenuItem {
                    property string val: "middle"

                    text: qsTr("Middle")
                    icon: "vertical_align_center"
                },
                MenuItem {
                    property string val: "bottom"

                    text: qsTr("Bottom")
                    icon: "vertical_align_bottom"
                }
            ]

            Component.onCompleted: {
                for (let i = 0; i < menuItems.length; i++) {
                    if (menuItems[i].val === posContainer.currentV)
                        active = menuItems[i];
                }
            }

            // The signal from SplitButtonRow
            onSelected: item => posContainer.updateClockPos(item.val, posContainer.currentH)
        }

        SplitButtonRow {
            label: qsTr("Horizontal Position")
            enabled: rootPane.desktopClockEnabled
            expandedZ: 99

            menuItems: [
                MenuItem {
                    property string val: "left"

                    text: qsTr("Left")
                    icon: "align_horizontal_left"
                },
                MenuItem {
                    property string val: "center"

                    text: qsTr("Center")
                    icon: "align_horizontal_center"
                },
                MenuItem {
                    property string val: "right"

                    text: qsTr("Right")
                    icon: "align_horizontal_right"
                }
            ]

            Component.onCompleted: {
                for (let i = 0; i < menuItems.length; i++) {
                    if (menuItems[i].val === posContainer.currentH)
                        active = menuItems[i];
                }
            }

            onSelected: item => posContainer.updateClockPos(posContainer.currentV, item.val)
        }
    }

    SwitchRow {
        label: qsTr("Invert colors")
        checked: rootPane.desktopClockInvertColors
        onToggled: checked => {
            rootPane.desktopClockInvertColors = checked;
            rootPane.saveConfig();
        }
    }

    SectionContainer {
        contentSpacing: Tokens.spacing.small

        StyledText {
            text: qsTr("Shadow")
            textPointSize: Tokens.font.size.larger
            font.weight: 400
        }

        SwitchRow {
            label: qsTr("Enabled")
            checked: rootPane.desktopClockShadowEnabled
            onToggled: checked => {
                rootPane.desktopClockShadowEnabled = checked;
                rootPane.saveConfig();
            }
        }

        SectionContainer {
            contentSpacing: Tokens.spacing.normal

            SliderInput {
                Layout.fillWidth: true

                label: qsTr("Opacity")
                value: rootPane.desktopClockShadowOpacity * 100
                from: 0
                to: 100
                suffix: "%"
                validator: IntValidator {
                    bottom: 0
                    top: 100
                }
                formatValueFunction: val => Math.round(val).toString()
                parseValueFunction: text => parseInt(text)

                onValueModified: newValue => {
                    rootPane.desktopClockShadowOpacity = newValue / 100;
                    rootPane.saveConfig();
                }
            }
        }

        SectionContainer {
            contentSpacing: Tokens.spacing.normal

            SliderInput {
                Layout.fillWidth: true

                label: qsTr("Blur")
                value: rootPane.desktopClockShadowBlur * 100
                from: 0
                to: 100
                suffix: "%"
                validator: IntValidator {
                    bottom: 0
                    top: 100
                }
                formatValueFunction: val => Math.round(val).toString()
                parseValueFunction: text => parseInt(text)

                onValueModified: newValue => {
                    rootPane.desktopClockShadowBlur = newValue / 100;
                    rootPane.saveConfig();
                }
            }
        }
    }

    SectionContainer {
        contentSpacing: Tokens.spacing.small

        StyledText {
            text: qsTr("Background")
            textPointSize: Tokens.font.size.larger
            font.weight: 400
        }

        SwitchRow {
            label: qsTr("Enabled")
            checked: rootPane.desktopClockBackgroundEnabled
            onToggled: checked => {
                rootPane.desktopClockBackgroundEnabled = checked;
                rootPane.saveConfig();
            }
        }

        SwitchRow {
            label: qsTr("Blur enabled")
            checked: rootPane.desktopClockBackgroundBlur
            onToggled: checked => {
                rootPane.desktopClockBackgroundBlur = checked;
                rootPane.saveConfig();
            }
        }

        SectionContainer {
            contentSpacing: Tokens.spacing.normal

            SliderInput {
                Layout.fillWidth: true

                label: qsTr("Opacity")
                value: rootPane.desktopClockBackgroundOpacity * 100
                from: 0
                to: 100
                suffix: "%"
                validator: IntValidator {
                    bottom: 0
                    top: 100
                }
                formatValueFunction: val => Math.round(val).toString()
                parseValueFunction: text => parseInt(text)

                onValueModified: newValue => {
                    rootPane.desktopClockBackgroundOpacity = newValue / 100;
                    rootPane.saveConfig();
                }
            }
        }
    }


}
