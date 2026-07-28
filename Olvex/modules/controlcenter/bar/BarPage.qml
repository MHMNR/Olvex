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

    function setNetSpeedEnabled(on: bool): void {
        const entries = [];
        const src = Config.bar.entries || [];
        let found = false;
        for (let i = 0; i < src.length; i++) {
            const e = src[i];
            if (e.id === "netSpeed") {
                found = true;
                entries.push({
                    id: "netSpeed",
                    enabled: on
                });
            } else {
                entries.push({
                    id: e.id,
                    enabled: e.enabled !== false
                });
            }
        }
        if (!found)
            entries.push({
                id: "netSpeed",
                enabled: on
            });
        GlobalConfig.bar.entries = entries;
        GlobalConfig.save();
    }

    function netSpeedOn(): bool {
        const src = Config.bar.entries || [];
        for (let i = 0; i < src.length; i++) {
            if (src[i].id === "netSpeed")
                return src[i].enabled !== false;
        }
        return false;
    }

    SettingsPage {
        anchors.fill: parent
        title: qsTr("Bar & Taskbar")
        subtitle: qsTr("Widgets, workspaces and status icons")
        icon: "space_dashboard"
        accent: Colours.palette.m3primary
        onBack: root.back()

        Section {
            title: qsTr("Behavior")
            description: qsTr("How and when the bar appears")
            icon: "settings"

            SettingRow {
                title: qsTr("Always visible")
                description: qsTr("Keep the bar pinned on screen at all times")
                StyledSwitch {
                    checked: Config.bar.persistent
                    onToggled: {
                        GlobalConfig.bar.persistent = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Reveal on hover")
                description: qsTr("Show the bar when the cursor reaches the edge")
                StyledSwitch {
                    checked: Config.bar.showOnHover
                    onToggled: {
                        GlobalConfig.bar.showOnHover = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Scroll to switch workspaces")
                description: qsTr("Change workspace by scrolling over the bar")
                StyledSwitch {
                    checked: Config.bar.scrollActions.workspaces
                    onToggled: {
                        GlobalConfig.bar.scrollActions.workspaces = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Scroll to change brightness")
                description: qsTr("Adjust display brightness by scrolling the bar")
                divider: false
                StyledSwitch {
                    checked: Config.bar.scrollActions.brightness
                    onToggled: {
                        GlobalConfig.bar.scrollActions.brightness = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            title: qsTr("Bottom panel")
            description: qsTr("Pinned apps strip along the bottom edge")
            icon: "dock_to_bottom"

            SettingRow {
                title: qsTr("Enabled")
                description: qsTr("Show the bottom panel with pinned apps")
                StyledSwitch {
                    checked: Config.bar.bottomPanel?.enabled ?? true
                    onToggled: {
                        GlobalConfig.bar.bottomPanel.enabled = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Visibility")
                description: qsTr("Always show, hide until hover, or hide when windows overlap")
                divider: false
                Segmented {
                    model: [{
                            label: qsTr("Always"),
                            icon: "visibility"
                        }, {
                            label: qsTr("Auto hide"),
                            icon: "visibility_off"
                        }, {
                            label: qsTr("Smart hide"),
                            icon: "auto_awesome"
                        }]
                    currentIndex: {
                        const m = Config.bar.bottomPanel?.visibilityMode || "always";
                        if (m === "autohide")
                            return 1;
                        if (m === "smarthide")
                            return 2;
                        return 0;
                    }
                    onSelected: i => {
                        GlobalConfig.bar.bottomPanel.visibilityMode = ["always", "autohide", "smarthide"][i];
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            title: qsTr("Workspaces")
            description: qsTr("The workspace indicator shown on the bar")
            icon: "grid_view"

            SettingRow {
                title: qsTr("Workspaces shown")
                description: qsTr("How many workspace dots to display")
                CustomSpinBox {
                    value: Config.bar.workspaces.shown ?? 5
                    min: 1
                    max: 10
                    step: 1
                    onValueModified: v => {
                        GlobalConfig.bar.workspaces.shown = v;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Active indicator")
                description: qsTr("Highlight the currently focused workspace")
                StyledSwitch {
                    checked: Config.bar.workspaces.activeIndicator
                    onToggled: {
                        GlobalConfig.bar.workspaces.activeIndicator = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Occupied background")
                description: qsTr("Backdrop behind workspaces that have windows")
                StyledSwitch {
                    checked: Config.bar.workspaces.occupiedBg
                    onToggled: {
                        GlobalConfig.bar.workspaces.occupiedBg = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Show window icons")
                description: qsTr("Display app icons for windows on each workspace")
                StyledSwitch {
                    checked: Config.bar.workspaces.showWindows
                    onToggled: {
                        GlobalConfig.bar.workspaces.showWindows = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Max window icons")
                description: qsTr("Limit the icons shown per workspace")
                CustomSpinBox {
                    value: Config.bar.workspaces.maxWindowIcons ?? 4
                    min: 0
                    max: 10
                    step: 1
                    onValueModified: v => {
                        GlobalConfig.bar.workspaces.maxWindowIcons = v;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Per-monitor workspaces")
                description: qsTr("Show only workspaces on the current display")
                divider: false
                StyledSwitch {
                    checked: GlobalConfig.bar.workspaces.perMonitorWorkspaces
                    onToggled: {
                        GlobalConfig.bar.workspaces.perMonitorWorkspaces = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            title: qsTr("Active window")
            description: qsTr("The focused-window widget")
            icon: "web_asset"

            SettingRow {
                title: qsTr("Compact")
                description: qsTr("Use a smaller, condensed layout")
                StyledSwitch {
                    checked: Config.bar.activeWindow.compact
                    onToggled: {
                        GlobalConfig.bar.activeWindow.compact = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Inverted colors")
                description: qsTr("Swap foreground and background colors")
                StyledSwitch {
                    checked: Config.bar.activeWindow.inverted
                    onToggled: {
                        GlobalConfig.bar.activeWindow.inverted = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Show popout on hover")
                description: qsTr("Open the active-window popout on hover")
                divider: false
                StyledSwitch {
                    checked: Config.bar.popouts.activeWindow
                    onToggled: {
                        GlobalConfig.bar.popouts.activeWindow = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            title: qsTr("System tray")
            description: qsTr("The tray-icon area")
            icon: "widgets"

            SettingRow {
                title: qsTr("Background")
                description: qsTr("Draw a container behind the tray icons")
                StyledSwitch {
                    checked: Config.bar.tray.background
                    onToggled: {
                        GlobalConfig.bar.tray.background = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Recolor icons")
                description: qsTr("Tint tray icons to match the theme")
                StyledSwitch {
                    checked: Config.bar.tray.recolour
                    onToggled: {
                        GlobalConfig.bar.tray.recolour = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Compact")
                description: qsTr("Reduce spacing between tray icons")
                divider: false
                StyledSwitch {
                    checked: Config.bar.tray.compact
                    onToggled: {
                        GlobalConfig.bar.tray.compact = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            title: qsTr("Status icons")
            description: qsTr("Which indicators appear in the bar")
            icon: "toggle_on"

            SettingRow {
                title: qsTr("Audio")
                description: qsTr("Speaker volume and mute state")
                icon: "volume_up"
                StyledSwitch {
                    checked: Config.bar.status.showAudio
                    onToggled: {
                        GlobalConfig.bar.status.showAudio = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Microphone")
                description: qsTr("Input mute state")
                icon: "mic"
                StyledSwitch {
                    checked: Config.bar.status.showMicrophone
                    onToggled: {
                        GlobalConfig.bar.status.showMicrophone = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Keyboard layout")
                description: qsTr("Current keyboard layout code")
                icon: "keyboard"
                StyledSwitch {
                    checked: Config.bar.status.showKbLayout
                    onToggled: {
                        GlobalConfig.bar.status.showKbLayout = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Network")
                description: qsTr("Wired/wireless connection status")
                icon: "lan"
                StyledSwitch {
                    checked: Config.bar.status.showNetwork
                    onToggled: {
                        GlobalConfig.bar.status.showNetwork = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Wi‑Fi")
                description: qsTr("Wi‑Fi signal icon")
                icon: "wifi"
                StyledSwitch {
                    checked: Config.bar.status.showWifi
                    onToggled: {
                        GlobalConfig.bar.status.showWifi = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Bluetooth")
                description: qsTr("Bluetooth power and connection state")
                icon: "bluetooth"
                StyledSwitch {
                    checked: Config.bar.status.showBluetooth
                    onToggled: {
                        GlobalConfig.bar.status.showBluetooth = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Battery")
                description: qsTr("Charge level and charging state")
                icon: "battery_full"
                StyledSwitch {
                    checked: Config.bar.status.showBattery
                    onToggled: {
                        GlobalConfig.bar.status.showBattery = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Lock status")
                description: qsTr("Caps and num lock indicators")
                icon: "lock"
                divider: false
                StyledSwitch {
                    checked: Config.bar.status.showLockStatus
                    onToggled: {
                        GlobalConfig.bar.status.showLockStatus = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            title: qsTr("Clock")
            description: qsTr("The bar clock widget")
            icon: "schedule"

            SettingRow {
                title: qsTr("Background")
                description: qsTr("Draw a container behind the clock")
                StyledSwitch {
                    checked: Config.bar.clock.background
                    onToggled: {
                        GlobalConfig.bar.clock.background = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Show date")
                description: qsTr("Include the date next to the time")
                StyledSwitch {
                    checked: Config.bar.clock.showDate
                    onToggled: {
                        GlobalConfig.bar.clock.showDate = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Show clock icon")
                description: qsTr("Display a small clock glyph")
                divider: false
                StyledSwitch {
                    checked: Config.bar.clock.showIcon
                    onToggled: {
                        GlobalConfig.bar.clock.showIcon = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            title: qsTr("Network speed")
            description: qsTr("Live upload / download throughput")
            icon: "speed"

            SettingRow {
                title: qsTr("Show network speed")
                description: qsTr("Display live transfer rates in the bar")
                StyledSwitch {
                    checked: root.netSpeedOn()
                    onToggled: root.setNetSpeedEnabled(checked)
                }
            }
            SettingRow {
                title: qsTr("Show icons")
                description: qsTr("Add up/down arrows to the readout")
                StyledSwitch {
                    checked: GlobalConfig.bar?.netSpeed?.showIcons ?? true
                    onToggled: {
                        if (GlobalConfig.bar?.netSpeed)
                            GlobalConfig.bar.netSpeed.showIcons = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Refresh interval")
                description: qsTr("How often the speed updates (ms)")
                divider: false
                CustomSpinBox {
                    value: GlobalConfig.bar?.netSpeed?.refreshInterval ?? 1000
                    min: 500
                    max: 10000
                    step: 500
                    onValueModified: v => {
                        if (GlobalConfig.bar?.netSpeed)
                            GlobalConfig.bar.netSpeed.refreshInterval = v;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }
}
