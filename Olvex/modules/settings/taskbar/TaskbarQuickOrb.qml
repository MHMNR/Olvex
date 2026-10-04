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

Item {
    id: root

    property Session session

    opacity: 0
    y: 10
    Component.onCompleted: cascadeIn.start()

    ParallelAnimation {
        id: cascadeIn
        NumberAnimation {
            target: root
            property: "opacity"
            to: 1.0
            duration: Tokens?.anim?.durations?.slow ?? 400
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "y"
            to: 0
            duration: Tokens?.anim?.durations?.slow ?? 400
            easing.type: Easing.OutCubic
        }
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

        // ── 1. General Quick Orb Settings ──
        Section {
            Layout.fillWidth: true
            title: qsTr("Quick Orb Dial")
            description: qsTr("Unified dynamic dial for sound, mic and brightness")
            icon: "adjust"

            SettingRow {
                title: qsTr("Enable Quick Orb")
                description: qsTr("Show dynamic control dial on the taskbar")
                divider: true
                StyledSwitch {
                    checked: Config.bar.quickOrb.enabled
                    onToggled: {
                        GlobalConfig.bar.quickOrb.enabled = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Show percentage readout")
                description: qsTr("Display live numeric value when volume or brightness changes")
                divider: true
                StyledSwitch {
                    checked: Config.bar.quickOrb.showPercentage
                    onToggled: {
                        GlobalConfig.bar.quickOrb.showPercentage = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Auto-hide delay (ms)")
                description: qsTr("How long the dial stays visible after value changes")
                divider: false
                CustomSpinBox {
                    value: Config.bar.quickOrb.autoHideDelay
                    min: 500
                    max: 6000
                    step: 200
                    onValueModified: v => {
                        GlobalConfig.bar.quickOrb.autoHideDelay = v;
                        GlobalConfig.save();
                    }
                }
            }
        }

        // ── 2. Auto-Reveal Triggers ──
        Section {
            Layout.fillWidth: true
            title: qsTr("Auto-Reveal Triggers")
            description: qsTr("Choose which events automatically reveal the Quick Orb")
            icon: "visibility"

            SettingRow {
                title: qsTr("Volume changes")
                description: qsTr("Reveal when system audio volume changes")
                divider: true
                StyledSwitch {
                    checked: Config.bar.quickOrb.autoRevealVolume
                    onToggled: {
                        GlobalConfig.bar.quickOrb.autoRevealVolume = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Brightness changes")
                description: qsTr("Reveal when display brightness changes")
                divider: true
                StyledSwitch {
                    checked: Config.bar.quickOrb.autoRevealBrightness
                    onToggled: {
                        GlobalConfig.bar.quickOrb.autoRevealBrightness = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Microphone changes")
                description: qsTr("Reveal when mic volume or mute state changes")
                divider: false
                StyledSwitch {
                    checked: Config.bar.quickOrb.autoRevealMic
                    onToggled: {
                        GlobalConfig.bar.quickOrb.autoRevealMic = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        // ── 3. Expanded Morph Card Controls ──
        Section {
            Layout.fillWidth: true
            title: qsTr("Expanded Controls")
            description: qsTr("Customize which tiles appear inside the expanded Quick Orb card")
            icon: "tune"

            SettingRow {
                title: qsTr("Media volume tile")
                description: qsTr("Master speaker volume slider and mute toggle")
                divider: true
                StyledSwitch {
                    checked: Config.bar.quickOrb.showMediaVolume
                    onToggled: {
                        GlobalConfig.bar.quickOrb.showMediaVolume = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Microphone input tile")
                description: qsTr("Microphone input volume slider and mute toggle")
                divider: true
                StyledSwitch {
                    checked: Config.bar.quickOrb.showMicrophone
                    onToggled: {
                        GlobalConfig.bar.quickOrb.showMicrophone = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Notification sounds tile")
                description: qsTr("System alerts and notification volume slider")
                divider: true
                StyledSwitch {
                    checked: Config.bar.quickOrb.showUiSounds
                    onToggled: {
                        GlobalConfig.bar.quickOrb.showUiSounds = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Display brightness tile")
                description: qsTr("Screen backlight level slider")
                divider: true
                StyledSwitch {
                    checked: Config.bar.quickOrb.showBrightness
                    onToggled: {
                        GlobalConfig.bar.quickOrb.showBrightness = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Audio device switchers")
                description: qsTr("Output sink and microphone source selector chips")
                divider: true
                StyledSwitch {
                    checked: Config.bar.quickOrb.showDeviceSwitchers
                    onToggled: {
                        GlobalConfig.bar.quickOrb.showDeviceSwitchers = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Night Light & color temperature")
                description: qsTr("Display warmth slider and blue light filter toggle")
                divider: false
                StyledSwitch {
                    checked: Config.bar.quickOrb.showNightLight
                    onToggled: {
                        GlobalConfig.bar.quickOrb.showNightLight = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }
}
