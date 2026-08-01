pragma ComponentBehavior: Bound

import ".."
import "../chrome"
import QtQuick
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    property Session session
    signal back

    SettingsPage {
        anchors.fill: parent
        title: qsTr("Panels & Widgets")
        subtitle: qsTr("Launcher, dashboard, sidebar, OSD and session")
        icon: "widgets"
        accent: Colours.palette.m3tertiary
        onBack: root.back()

        Section {
            title: qsTr("Launcher")
            description: qsTr("The app launcher and search overlay")
            icon: "apps"

            SettingRow {
                title: qsTr("Enable launcher")
                description: qsTr("Allow opening the app launcher")
                StyledSwitch {
                    checked: Config.launcher.enabled
                    onToggled: {
                        GlobalConfig.launcher.enabled = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Show on hover")
                description: qsTr("Open when hovering its edge")
                StyledSwitch {
                    checked: Config.launcher.showOnHover
                    onToggled: {
                        GlobalConfig.launcher.showOnHover = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Vim keybinds")
                description: qsTr("Navigate results with h/j/k/l")
                StyledSwitch {
                    checked: GlobalConfig.launcher.vimKeybinds
                    onToggled: {
                        GlobalConfig.launcher.vimKeybinds = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Enable dangerous actions")
                description: qsTr("Allow shutdown / reboot from search")
                StyledSwitch {
                    checked: GlobalConfig.launcher.enableDangerousActions
                    onToggled: {
                        GlobalConfig.launcher.enableDangerousActions = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Max results")
                description: qsTr("Number of results shown at once")
                CustomSpinBox {
                    value: Config.launcher.maxShown ?? 8
                    min: 3
                    max: 20
                    step: 1
                    onValueModified: v => {
                        GlobalConfig.launcher.maxShown = v;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Action prefix")
                description: qsTr("Character that triggers action search")
                StyledTextField {
                    width: 90
                    text: GlobalConfig.launcher.actionPrefix || ">"
                    onEditingFinished: {
                        GlobalConfig.launcher.actionPrefix = text;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Special prefix")
                description: qsTr("Character that triggers special commands")
                divider: false
                StyledTextField {
                    width: 90
                    text: GlobalConfig.launcher.specialPrefix || "@"
                    onEditingFinished: {
                        GlobalConfig.launcher.specialPrefix = text;
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            title: qsTr("Dashboard")
            description: qsTr("Overview panel with media and system stats")
            icon: "dashboard"

            SettingRow {
                title: qsTr("Enable dashboard")
                description: qsTr("Allow opening the dashboard panel")
                StyledSwitch {
                    checked: Config.dashboard.enabled
                    onToggled: {
                        GlobalConfig.dashboard.enabled = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Show on hover")
                description: qsTr("Open when hovering its edge")
                StyledSwitch {
                    checked: Config.dashboard.showOnHover
                    onToggled: {
                        GlobalConfig.dashboard.showOnHover = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Show media player")
                description: qsTr("Include now-playing controls")
                StyledSwitch {
                    checked: Config.dashboard.showMedia
                    onToggled: {
                        GlobalConfig.dashboard.showMedia = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Show weather")
                description: qsTr("Include the weather widget")
                StyledSwitch {
                    checked: Config.dashboard.showWeather
                    onToggled: {
                        GlobalConfig.dashboard.showWeather = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Resource refresh")
                description: qsTr("How often resource monitors update (s)")
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
            title: qsTr("Performance widgets")
            description: qsTr("Resource monitors on the dashboard")
            icon: "monitoring"

            SettingRow {
                title: qsTr("Battery")
                icon: "battery_full"
                StyledSwitch {
                    checked: Config.dashboard.performance.showBattery
                    onToggled: {
                        GlobalConfig.dashboard.performance.showBattery = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("GPU")
                icon: "memory"
                StyledSwitch {
                    checked: Config.dashboard.performance.showGpu
                    onToggled: {
                        GlobalConfig.dashboard.performance.showGpu = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("CPU")
                icon: "developer_board"
                StyledSwitch {
                    checked: Config.dashboard.performance.showCpu
                    onToggled: {
                        GlobalConfig.dashboard.performance.showCpu = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Memory")
                icon: "memory_alt"
                StyledSwitch {
                    checked: Config.dashboard.performance.showMemory
                    onToggled: {
                        GlobalConfig.dashboard.performance.showMemory = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Storage")
                icon: "storage"
                StyledSwitch {
                    checked: Config.dashboard.performance.showStorage
                    onToggled: {
                        GlobalConfig.dashboard.performance.showStorage = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Network")
                icon: "lan"
                divider: false
                StyledSwitch {
                    checked: Config.dashboard.performance.showNetwork
                    onToggled: {
                        GlobalConfig.dashboard.performance.showNetwork = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            title: qsTr("Sidebar")
            description: qsTr("Slide-out notifications & controls panel")
            icon: "view_sidebar"

            SettingRow {
                title: qsTr("Enable sidebar")
                description: qsTr("Allow opening the sidebar")
                StyledSwitch {
                    checked: Config.sidebar.enabled
                    onToggled: {
                        GlobalConfig.sidebar.enabled = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Drag threshold")
                description: qsTr("Distance before a drag opens the sidebar")
                divider: false
                CustomSpinBox {
                    value: Config.sidebar.dragThreshold ?? 80
                    min: 5
                    max: 100
                    step: 5
                    onValueModified: v => {
                        GlobalConfig.sidebar.dragThreshold = v;
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            title: qsTr("On-screen display")
            description: qsTr("Volume and brightness popups")
            icon: "tv_options_input_settings"

            SettingRow {
                title: qsTr("Enable OSD")
                description: qsTr("Show popup when volume or brightness changes")
                StyledSwitch {
                    checked: Config.osd.enabled
                    onToggled: {
                        GlobalConfig.osd.enabled = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Brightness OSD")
                description: qsTr("Show popup for brightness changes")
                StyledSwitch {
                    checked: Config.osd.enableBrightness
                    onToggled: {
                        GlobalConfig.osd.enableBrightness = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Microphone OSD")
                description: qsTr("Show popup for mic mute changes")
                StyledSwitch {
                    checked: Config.osd.enableMicrophone
                    onToggled: {
                        GlobalConfig.osd.enableMicrophone = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Hide delay")
                description: qsTr("How long the OSD stays visible (ms)")
                divider: false
                CustomSpinBox {
                    value: Config.osd.hideDelay ?? 2000
                    min: 500
                    max: 5000
                    step: 250
                    onValueModified: v => {
                        GlobalConfig.osd.hideDelay = v;
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            title: qsTr("Session menu")
            description: qsTr("Logout / shutdown menu")
            icon: "power_settings_new"

            SettingRow {
                title: qsTr("Enable session menu")
                description: qsTr("Allow opening the power menu")
                StyledSwitch {
                    checked: Config.session.enabled
                    onToggled: {
                        GlobalConfig.session.enabled = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Vim keybinds")
                description: qsTr("Navigate the menu with h/j/k/l")
                divider: false
                StyledSwitch {
                    checked: Config.session.vimKeybinds
                    onToggled: {
                        GlobalConfig.session.vimKeybinds = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }
}
