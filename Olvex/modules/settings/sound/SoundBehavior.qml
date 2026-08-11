
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

        Column {
            Layout.fillWidth: true
            spacing: 0

            SettingRow {
                title: qsTr("Volume step")
                description: qsTr("Amount changed per scroll or key press")
                divider: true
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
                divider: true
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
                divider: true
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
