
import ".."
import "../chrome"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.controls

Item {
    id: root
    
    property var session
    
    opacity: 0
    y: 10
    Component.onCompleted: cascadeIn.start()
    
    ParallelAnimation {
        id: cascadeIn
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens.anim.durations.long; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens.anim.durations.long; easing.type: Easing.OutCubic }
    }

    implicitHeight: col.implicitHeight + Tokens.padding.large * 2
    
    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Tokens.padding.large
        anchors.rightMargin: Tokens.padding.large
        anchors.topMargin: Tokens.padding.large
        spacing: 0

        SettingRow {
            title: qsTr("Charging state")
            description: qsTr("Charger plugged in or removed")
            icon: "bolt"
            divider: true
            StyledSwitch {
                checked: GlobalConfig.qspanel.toasts.chargingChanged ?? true
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
            title: qsTr("Audio output changed")
            description: qsTr("Default output device switched")
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
            description: qsTr("Default microphone switched")
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
            title: qsTr("Caps lock")
            description: qsTr("Caps lock turned on or off")
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
            description: qsTr("Num lock turned on or off")
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
            title: qsTr("Now playing")
            description: qsTr("A new track starts playing")
            icon: "music_note"
            divider: false
            StyledSwitch {
                checked: GlobalConfig.qspanel.toasts.nowPlaying ?? true
                onToggled: {
                    GlobalConfig.qspanel.toasts.nowPlaying = checked;
                    GlobalConfig.save();
                }
            }
        }
    }
}
