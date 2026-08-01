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
        title: qsTr("Notifications")
        subtitle: qsTr("Alerts, toasts and per-event prompts")
        icon: "notifications"
        accent: Colours.palette.m3primary
        onBack: root.back()

        Section {
            title: qsTr("Notifications")
            description: qsTr("Behavior of popup notifications")
            icon: "notifications_active"

            SettingRow {
                title: qsTr("Auto-expire")
                description: qsTr("Dismiss notifications automatically after a timeout")
                StyledSwitch {
                    checked: GlobalConfig.notifs.expire
                    onToggled: {
                        GlobalConfig.notifs.expire = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Default timeout")
                description: qsTr("How long a notification stays before expiring")
                CustomSpinBox {
                    value: Math.round((GlobalConfig.notifs.defaultExpireTimeout || 5000) / 1000)
                    min: 1
                    max: 30
                    step: 1
                    onValueModified: v => {
                        GlobalConfig.notifs.defaultExpireTimeout = v * 1000;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Show in fullscreen")
                description: qsTr("Allow popups over fullscreen apps")
                StyledSwitch {
                    checked: (GlobalConfig.notifs.fullscreen || "on") === "on"
                    onToggled: {
                        GlobalConfig.notifs.fullscreen = checked ? "on" : "off";
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Open expanded")
                description: qsTr("Show the full notification body immediately")
                StyledSwitch {
                    checked: Config.notifs.openExpanded
                    onToggled: {
                        GlobalConfig.notifs.openExpanded = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Group preview count")
                description: qsTr("Notifications shown before a group collapses")
                divider: false
                CustomSpinBox {
                    value: Config.notifs.groupPreviewNum ?? 3
                    min: 1
                    max: 8
                    step: 1
                    onValueModified: v => {
                        GlobalConfig.notifs.groupPreviewNum = v;
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            title: qsTr("Toasts")
            description: qsTr("Small transient status messages")
            icon: "chat_bubble"

            SettingRow {
                title: qsTr("Visible toasts")
                description: qsTr("Maximum number of toasts shown at once")
                CustomSpinBox {
                    value: Config.qspanel.maxToasts ?? 4
                    min: 1
                    max: 8
                    step: 1
                    onValueModified: v => {
                        GlobalConfig.qspanel.maxToasts = v;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Show in fullscreen")
                description: qsTr("When to allow toasts over fullscreen apps")
                divider: false
                Segmented {
                    model: [{
                            label: qsTr("Off")
                        }, {
                            label: qsTr("Important")
                        }, {
                            label: qsTr("On")
                        }]
                    currentIndex: {
                        const v = Config.qspanel.toasts.fullscreen || "off";
                        return v === "off" ? 0 : v === "important" ? 1 : 2;
                    }
                    onSelected: i => {
                        GlobalConfig.qspanel.toasts.fullscreen = ["off", "important", "on"][i];
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            title: qsTr("Toast events")
            description: qsTr("Which changes announce themselves with a toast")
            icon: "campaign"

            SettingRow {
                title: qsTr("Charging state")
                description: qsTr("Charger plugged in or removed")
                icon: "bolt"
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.chargingChanged
                    onToggled: {
                        GlobalConfig.qspanel.toasts.chargingChanged = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Game mode")
                description: qsTr("Game mode toggled on or off")
                icon: "sports_esports"
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.gameModeChanged
                    onToggled: {
                        GlobalConfig.qspanel.toasts.gameModeChanged = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Do not disturb")
                description: qsTr("DND toggled on or off")
                icon: "do_not_disturb_on"
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.dndChanged
                    onToggled: {
                        GlobalConfig.qspanel.toasts.dndChanged = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Audio output changed")
                description: qsTr("Default output device switched")
                icon: "speaker"
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.audioOutputChanged
                    onToggled: {
                        GlobalConfig.qspanel.toasts.audioOutputChanged = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Audio input changed")
                description: qsTr("Default microphone switched")
                icon: "mic"
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.audioInputChanged
                    onToggled: {
                        GlobalConfig.qspanel.toasts.audioInputChanged = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Caps lock")
                description: qsTr("Caps lock turned on or off")
                icon: "keyboard_capslock"
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.capsLockChanged
                    onToggled: {
                        GlobalConfig.qspanel.toasts.capsLockChanged = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Num lock")
                description: qsTr("Num lock turned on or off")
                icon: "pin"
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.numLockChanged
                    onToggled: {
                        GlobalConfig.qspanel.toasts.numLockChanged = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Keyboard layout")
                description: qsTr("Active keyboard layout changed")
                icon: "keyboard"
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.kbLayoutChanged
                    onToggled: {
                        GlobalConfig.qspanel.toasts.kbLayoutChanged = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("VPN state")
                description: qsTr("VPN connected or disconnected")
                icon: "vpn_lock"
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.vpnChanged
                    onToggled: {
                        GlobalConfig.qspanel.toasts.vpnChanged = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Now playing")
                description: qsTr("A new track starts playing")
                icon: "music_note"
                divider: false
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.nowPlaying
                    onToggled: {
                        GlobalConfig.qspanel.toasts.nowPlaying = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }
}
