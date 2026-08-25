
import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config

Item {
    id: root
    
    property Session session
    
    opacity: 0
    y: 10
    Component.onCompleted: cascadeIn.start()
    
    ParallelAnimation {
        id: cascadeIn
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens?.anim?.durations?.slow ?? 400; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens?.anim?.durations?.slow ?? 400; easing.type: Easing.OutCubic }
    }

    implicitHeight: (col ? col.implicitHeight : 0) + Tokens.padding.large * 2
    
    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Tokens.padding.large
        anchors.rightMargin: Tokens.padding.large
        anchors.topMargin: Tokens.padding.large
        spacing: Tokens.spacing.large

        // ── General Toast Settings ──
        Section {
            title: qsTr("General")
            description: qsTr("Toast display and limit preferences")
            icon: "tune"

            SettingRow {
                title: qsTr("Visible toasts")
                description: qsTr("Maximum number of toasts shown at once")
                divider: true
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

        // ── Devices & Hardware ──
        Section {
            title: qsTr("Devices & Hardware")
            description: qsTr("Alerts when hardware devices connect or change state")
            icon: "devices"

            SettingRow {
                title: qsTr("USB devices")
                description: qsTr("USB flash drives and storage devices connected or removed")
                icon: "usb"
                divider: true
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.usbDevices ?? true
                    onToggled: {
                        GlobalConfig.qspanel.toasts.usbDevices = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Bluetooth devices")
                description: qsTr("Bluetooth headphones, mice, and accessories connected or disconnected")
                icon: "bluetooth"
                divider: true
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.bluetoothDevices ?? true
                    onToggled: {
                        GlobalConfig.qspanel.toasts.bluetoothDevices = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Headphones & audio jack")
                description: qsTr("Wired headphones plugged in or disconnected")
                icon: "headphones"
                divider: true
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.headphones ?? true
                    onToggled: {
                        GlobalConfig.qspanel.toasts.headphones = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Charging state")
                description: qsTr("Charger plugged in or removed")
                icon: "bolt"
                divider: false
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.chargingChanged ?? true
                    onToggled: {
                        GlobalConfig.qspanel.toasts.chargingChanged = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        // ── Audio & Media ──
        Section {
            title: qsTr("Audio & Media")
            description: qsTr("Sound routing and media playback alerts")
            icon: "volume_up"

            SettingRow {
                title: qsTr("Audio output changed")
                description: qsTr("Default output speaker or device switched")
                icon: "speaker"
                divider: true
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.audioOutputChanged ?? true
                    onToggled: {
                        GlobalConfig.qspanel.toasts.audioOutputChanged = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Audio input changed")
                description: qsTr("Default microphone or recording source switched")
                icon: "mic"
                divider: true
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.audioInputChanged ?? true
                    onToggled: {
                        GlobalConfig.qspanel.toasts.audioInputChanged = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Now playing")
                description: qsTr("Show alert when a new media track starts playing")
                icon: "music_note"
                divider: false
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.nowPlaying ?? false
                    onToggled: {
                        GlobalConfig.qspanel.toasts.nowPlaying = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        // ── System & Keyboard ──
        Section {
            title: qsTr("System & Controls")
            description: qsTr("Keyboard toggles, desktop modes, and network status")
            icon: "settings"

            SettingRow {
                title: qsTr("Caps lock")
                description: qsTr("Caps lock toggled on or off")
                icon: "keyboard_capslock"
                divider: true
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.capsLockChanged ?? true
                    onToggled: {
                        GlobalConfig.qspanel.toasts.capsLockChanged = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Num lock")
                description: qsTr("Num lock toggled on or off")
                icon: "pin"
                divider: true
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.numLockChanged ?? true
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
                divider: true
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.kbLayoutChanged ?? true
                    onToggled: {
                        GlobalConfig.qspanel.toasts.kbLayoutChanged = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Game mode")
                description: qsTr("Game mode toggled on or off")
                icon: "sports_esports"
                divider: true
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.gameModeChanged ?? true
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
                divider: true
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.dndChanged ?? true
                    onToggled: {
                        GlobalConfig.qspanel.toasts.dndChanged = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("VPN state")
                description: qsTr("VPN connected or disconnected")
                icon: "vpn_lock"
                divider: true
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.vpnChanged ?? true
                    onToggled: {
                        GlobalConfig.qspanel.toasts.vpnChanged = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Configuration loaded")
                description: qsTr("Shell configuration reloaded successfully")
                icon: "rule_settings"
                divider: false
                StyledSwitch {
                    checked: GlobalConfig.qspanel.toasts.configLoaded ?? true
                    onToggled: {
                        GlobalConfig.qspanel.toasts.configLoaded = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }
}
