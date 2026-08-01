pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.modules.controlcenter.components
import qs.components
import qs.components.containers
import qs.components.controls

CollapsibleSection {
    id: root

    required property var rootPane

    title: qsTr("Background")
    description: qsTr("Wallpaper, live wallpaper, and cycling")
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
        StyledText {
            text: qsTr("Cycling")
            textPointSize: Tokens.font.size.larger
            font.weight: 500
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

    SectionContainer {
        StyledText {
            text: qsTr("Desktop clock")
            textPointSize: Tokens.font.size.larger
            font.weight: 500
        }

        SwitchRow {
            label: qsTr("Enabled")
            checked: rootPane.desktopClockEnabled
            onToggled: checked => {
                rootPane.desktopClockEnabled = checked;
                rootPane.saveConfig();
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
    }
}
