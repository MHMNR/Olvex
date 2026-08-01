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

    function deviceIcon(node): string {
        if (!node)
            return "speaker";
        const n = (node.description || node.name || "").toLowerCase();
        if (n.includes("headphone") || n.includes("headset"))
            return "headphones";
        if (n.includes("hdmi") || n.includes("display"))
            return "tv";
        if (n.includes("bluez") || n.includes("bluetooth"))
            return "bluetooth_audio";
        if (n.includes("mic"))
            return "mic";
        return "speaker";
    }

    SettingsPage {
        anchors.fill: parent
        title: qsTr("Sound")
        subtitle: qsTr("Output, input and per-app volume")
        icon: "volume_up"
        accent: Colours.palette.m3primaryContainer
        onBack: root.back()

        Section {
            title: qsTr("Output")
            description: qsTr("Speakers and headphones")
            icon: "speaker"

            SettingRow {
                title: qsTr("Volume")
                description: qsTr("Master output level and mute")
                Row {
                    spacing: Tokens.spacing.normal

                    StyledSwitch {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: !Audio.muted
                        onToggled: {
                            if (Audio.sink?.audio)
                                Audio.sink.audio.muted = !checked;
                        }
                    }

                    StyledSlider {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 200
                        from: 0
                        to: Math.max(1, GlobalConfig.services.maxVolume || 1)
                        value: Audio.volume
                        onMoved: Audio.setVolume(value)
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 2

                Repeater {
                    model: Audio.sinks

                    delegate: DeviceRow {
                        required property var modelData

                        name: modelData.description || modelData.name || qsTr("Output")
                        icon: root.deviceIcon(modelData)
                        active: Audio.sink && Audio.sink.id === modelData.id
                        status: active ? qsTr("Active") : qsTr("Available")
                        onClicked: Audio.setAudioSink(modelData)
                    }
                }
            }
        }

        Section {
            title: qsTr("Input")
            description: qsTr("Microphones")
            icon: "mic"

            SettingRow {
                title: qsTr("Microphone")
                description: qsTr("Master input level and mute")
                Row {
                    spacing: Tokens.spacing.normal

                    StyledSwitch {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: !Audio.sourceMuted
                        onToggled: {
                            if (Audio.source?.audio)
                                Audio.source.audio.muted = !checked;
                        }
                    }

                    StyledSlider {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 200
                        from: 0
                        to: Math.max(1, GlobalConfig.services.maxVolume || 1)
                        value: Audio.sourceVolume
                        onMoved: Audio.setSourceVolume(value)
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 2

                Repeater {
                    model: Audio.sources

                    delegate: DeviceRow {
                        required property var modelData

                        name: modelData.description || modelData.name || qsTr("Input")
                        icon: "mic"
                        active: Audio.source && Audio.source.id === modelData.id
                        status: active ? qsTr("Active") : qsTr("Available")
                        onClicked: Audio.setAudioSource(modelData)
                    }
                }
            }
        }

        Section {
            title: qsTr("Applications")
            description: qsTr("Independent volume for each running app")
            icon: "apps"

            Column {
                width: parent.width

                Repeater {
                    model: Audio.streams

                    delegate: SettingRow {
                        required property var modelData
                        required property int index

                        title: Audio.getStreamName(modelData)
                        description: qsTr("Application output level")
                        icon: "apps"
                        divider: index < Audio.streams.length - 1
                        StyledSlider {
                            width: 200
                            from: 0
                            to: Math.max(1, GlobalConfig.services.maxVolume || 1)
                            value: Audio.getStreamVolume(modelData)
                            onMoved: Audio.setStreamVolume(modelData, value)
                        }
                    }
                }

                SettingRow {
                    visible: Audio.streams.length === 0
                    title: qsTr("No active apps")
                    description: qsTr("App streams appear here while playing audio")
                    divider: false
                }
            }
        }

        Section {
            title: qsTr("Behavior")
            description: qsTr("Volume steps and limits")
            icon: "tune"

            SettingRow {
                title: qsTr("Volume step")
                description: qsTr("Amount changed per scroll or key press")
                CustomSpinBox {
                    value: Math.round((GlobalConfig.services.audioIncrement || 0.1) * 100)
                    min: 1
                    max: 25
                    step: 1
                    onValueModified: v => {
                        GlobalConfig.services.audioIncrement = v / 100;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Maximum volume")
                description: qsTr("Allow boosting above 100%")
                CustomSpinBox {
                    value: Math.round((GlobalConfig.services.maxVolume || 1) * 100)
                    min: 100
                    max: 150
                    step: 5
                    onValueModified: v => {
                        GlobalConfig.services.maxVolume = v / 100;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Brightness step")
                description: qsTr("Amount changed per scroll or key press")
                CustomSpinBox {
                    value: Math.round((GlobalConfig.services.brightnessIncrement || 0.1) * 100)
                    min: 1
                    max: 25
                    step: 1
                    onValueModified: v => {
                        GlobalConfig.services.brightnessIncrement = v / 100;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Scroll bar to change volume")
                description: qsTr("Adjust volume by scrolling over the bar")
                divider: false
                StyledSwitch {
                    checked: Config.bar.scrollActions.volume
                    onToggled: {
                        GlobalConfig.bar.scrollActions.volume = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }
}
