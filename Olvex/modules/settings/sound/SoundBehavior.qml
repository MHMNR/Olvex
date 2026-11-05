
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
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens.anim.durations.slow; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens.anim.durations.slow; easing.type: Easing.OutCubic }
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

        Section {
            Layout.fillWidth: true
            title: qsTr("Volume Steps & Limits")
            description: qsTr("Scroll step intervals and audio boost limits")
            icon: "tune"
            accentColor: Colours.palette.m3secondary

            SettingRow {
                title: qsTr("Volume step")
                description: qsTr("Amount changed per scroll wheel step or volume key press")

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
                description: qsTr("Allow volume boosting beyond 100% (up to 150%)")

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
                description: qsTr("Amount changed per scroll wheel step or brightness key press")

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
        }

        Section {
            Layout.fillWidth: true
            title: qsTr("Gestures & Quick Actions")
            description: qsTr("Taskbar and panel quick scroll gestures")
            icon: "swipe"
            accentColor: Colours.palette.m3secondary

            SettingRow {
                title: qsTr("Scroll bar to change volume")
                description: qsTr("Scroll anywhere over the top/bottom bar to adjust sound level")

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