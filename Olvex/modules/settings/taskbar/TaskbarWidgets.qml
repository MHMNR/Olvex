import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config

ColumnLayout {
    id: root

    property Session session
    spacing: Tokens.spacing.large

    Section {
        Layout.fillWidth: true
        title: qsTr("Clock")
        description: qsTr("Time format and display options")
        icon: "schedule"

        SettingRow {
            title: qsTr("Show date")
            description: qsTr("Display current date next to time")
            divider: true
            StyledSwitch {
                checked: Config.bar.clock.showDate ?? false
                onToggled: {
                    GlobalConfig.bar.clock.showDate = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Show clock icon")
            description: qsTr("Display clock icon in pill")
            divider: true
            StyledSwitch {
                checked: Config.bar.clock.showIcon ?? true
                onToggled: {
                    GlobalConfig.bar.clock.showIcon = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Use 12-hour clock")
            description: qsTr("AM/PM format instead of 24-hour")
            divider: true
            StyledSwitch {
                checked: GlobalConfig.services.useTwelveHourClock ?? false
                onToggled: {
                    GlobalConfig.services.useTwelveHourClock = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Pill background")
            description: qsTr("Show container background behind clock")
            divider: false
            StyledSwitch {
                checked: Config.bar.clock.background ?? false
                onToggled: {
                    GlobalConfig.bar.clock.background = checked;
                    GlobalConfig.save();
                }
            }
        }
    }

    Section {
        Layout.fillWidth: true
        title: qsTr("Network Speed")
        description: qsTr("Current download/upload speeds")
        icon: "speed"

        SettingRow {
            title: qsTr("Enabled")
            description: qsTr("Show real-time network activity monitor")
            divider: true
            StyledSwitch {
                checked: GlobalConfig.bar?.netSpeed?.enabled ?? true
                onToggled: {
                    if (GlobalConfig.bar.netSpeed) {
                        GlobalConfig.bar.netSpeed.enabled = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Layout mode")
            description: qsTr("Separate upload/download rows or combined single line")
            divider: true
            Segmented {
                model: [qsTr("Separate"), qsTr("Combined")]
                currentIndex: (GlobalConfig.bar?.netSpeed?.mode || "separate") === "combined" ? 1 : 0
                onSelected: i => {
                    if (GlobalConfig.bar?.netSpeed) {
                        GlobalConfig.bar.netSpeed.mode = i === 1 ? "combined" : "separate";
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Show icons")
            description: qsTr("Display direction arrows next to speed numbers")
            divider: true
            StyledSwitch {
                checked: GlobalConfig.bar?.netSpeed?.showIcons ?? true
                onToggled: {
                    if (GlobalConfig.bar.netSpeed) {
                        GlobalConfig.bar.netSpeed.showIcons = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Pill background")
            description: qsTr("Show container background behind speed")
            divider: true
            StyledSwitch {
                checked: GlobalConfig.bar?.netSpeed?.background ?? false
                onToggled: {
                    if (GlobalConfig.bar.netSpeed) {
                        GlobalConfig.bar.netSpeed.background = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Refresh interval (ms)")
            description: qsTr("Update frequency in milliseconds")
            divider: false
            CustomSpinBox {
                value: GlobalConfig.bar?.netSpeed?.refreshInterval ?? 1000
                min: 100
                max: 5000
                step: 100
                onValueModified: v => {
                    if (GlobalConfig.bar.netSpeed) {
                        GlobalConfig.bar.netSpeed.refreshInterval = v;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }

    Section {
        Layout.fillWidth: true
        title: qsTr("System Tray")
        description: qsTr("Background third-party app icons")
        icon: "menu"

        SettingRow {
            title: qsTr("Pill background")
            description: qsTr("Show container background behind tray")
            divider: true
            StyledSwitch {
                checked: Config.bar.tray.background ?? false
                onToggled: {
                    GlobalConfig.bar.tray.background = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Compact mode")
            description: qsTr("Reduce spacing between tray icons")
            divider: true
            StyledSwitch {
                checked: Config.bar.tray.compact ?? false
                onToggled: {
                    GlobalConfig.bar.tray.compact = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Recolor icons to theme")
            description: qsTr("Apply M3 color tinting to tray icons")
            divider: false
            StyledSwitch {
                checked: Config.bar.tray.recolour ?? false
                onToggled: {
                    GlobalConfig.bar.tray.recolour = checked;
                    GlobalConfig.save();
                }
            }
        }
    }
}
