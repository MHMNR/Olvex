import ".."
import "../chrome"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    property var session
    spacing: Tokens.spacing.large

    Section {
        Layout.fillWidth: true
        title: qsTr("Dashboard Options")
        description: qsTr("Layout and behavior settings for the dashboard panel")
        icon: "dashboard"
        accentColor: Colours.palette.m3secondary

        SettingRow {
            title: qsTr("Enable dashboard")
            description: qsTr("Allow opening the dashboard panel")
            divider: true
            StyledSwitch {
                checked: Config.dashboard.enabled ?? true
                onToggled: {
                    GlobalConfig.dashboard.enabled = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Show on hover")
            description: qsTr("Open when hovering over edge trigger")
            divider: true
            StyledSwitch {
                checked: Config.dashboard.showOnHover ?? false
                onToggled: {
                    GlobalConfig.dashboard.showOnHover = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Show media player")
            description: qsTr("Include media player widget on dashboard")
            divider: true
            StyledSwitch {
                checked: Config.dashboard.showMedia ?? true
                onToggled: {
                    GlobalConfig.dashboard.showMedia = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Show weather")
            description: qsTr("Include weather widget on dashboard")
            divider: true
            StyledSwitch {
                checked: Config.dashboard.showWeather ?? true
                onToggled: {
                    GlobalConfig.dashboard.showWeather = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Weather location")
            description: qsTr("City name or 'lat,lon'. Leave empty for auto-detection")
            divider: true
            StyledTextField {
                implicitWidth: 160
                placeholderText: qsTr("Auto-detect")
                text: GlobalConfig.services.weatherLocation || ""
                onEditingFinished: {
                    GlobalConfig.services.weatherLocation = text;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Temperature unit")
            description: qsTr("Display temperature in Celsius (°C) or Fahrenheit (°F)")
            divider: true
            Segmented {
                minSegmentWidth: 54
                model: [
                    { label: "°C" },
                    { label: "°F" }
                ]
                currentIndex: GlobalConfig.services.useFahrenheit ? 1 : 0
                onSelected: i => {
                    GlobalConfig.services.useFahrenheit = (i === 1);
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Resource refresh (seconds)")
            description: qsTr("Update interval for system resource monitors")
            divider: false
            CustomSpinBox {
                value: Math.round((GlobalConfig.dashboard.resourceUpdateInterval || 1000) / 1000)
                min: 1
                max: 30
                step: 1
                onValueModified: v => {
                    GlobalConfig.dashboard.resourceUpdateInterval = v * 1000;
                    GlobalConfig.save();
                }
            }
        }
    }

    Section {
        Layout.fillWidth: true
        title: qsTr("Performance Widgets")
        description: qsTr("Select system monitors displayed on the dashboard")
        icon: "monitoring"
        accentColor: Colours.palette.m3secondary

        SettingRow {
            title: qsTr("Battery")
            description: qsTr("Show battery charge and health monitor")
            divider: true
            StyledSwitch {
                checked: Config.dashboard.performance.showBattery ?? true
                onToggled: {
                    GlobalConfig.dashboard.performance.showBattery = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("GPU")
            description: qsTr("Show graphics processing unit usage")
            divider: true
            StyledSwitch {
                checked: Config.dashboard.performance.showGpu ?? true
                onToggled: {
                    GlobalConfig.dashboard.performance.showGpu = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("CPU")
            description: qsTr("Show central processing unit load")
            divider: true
            StyledSwitch {
                checked: Config.dashboard.performance.showCpu ?? true
                onToggled: {
                    GlobalConfig.dashboard.performance.showCpu = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Memory")
            description: qsTr("Show RAM memory allocation")
            divider: true
            StyledSwitch {
                checked: Config.dashboard.performance.showMemory ?? true
                onToggled: {
                    GlobalConfig.dashboard.performance.showMemory = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Storage")
            description: qsTr("Show disk partition usage")
            divider: true
            StyledSwitch {
                checked: Config.dashboard.performance.showStorage ?? true
                onToggled: {
                    GlobalConfig.dashboard.performance.showStorage = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Network")
            description: qsTr("Show real-time network throughput")
            divider: false
            StyledSwitch {
                checked: Config.dashboard.performance.showNetwork ?? true
                onToggled: {
                    GlobalConfig.dashboard.performance.showNetwork = checked;
                    GlobalConfig.save();
                }
            }
        }
    }
}
