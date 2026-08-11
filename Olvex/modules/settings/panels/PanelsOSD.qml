
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
        spacing: 0

        SettingRow {
            title: qsTr("Enable flyouts")
            description: qsTr("Show popups when volume or brightness changes")
            divider: true
            StyledSwitch {
                checked: Config.flyouts.enabled ?? true
                onToggled: {
                    GlobalConfig.flyouts.enabled = checked;
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Brightness flyout")
            description: qsTr("Show popup for brightness changes")
            divider: true
            StyledSwitch {
                checked: Config.flyouts.enableBrightness ?? true
                onToggled: {
                    GlobalConfig.flyouts.enableBrightness = checked;
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Microphone flyout")
            description: qsTr("Show popup for mic mute changes")
            divider: true
            StyledSwitch {
                checked: Config.flyouts.enableMicrophone ?? true
                onToggled: {
                    GlobalConfig.flyouts.enableMicrophone = checked;
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Hide delay (ms)")
            description: qsTr("How long the flyout popup stays visible")
            divider: false
            CustomSpinBox {
                value: Config.flyouts.hideDelay ?? 2000
                min: 500
                max: 5000
                step: 250
                onValueModified: v => {
                    GlobalConfig.flyouts.hideDelay = v;
                    GlobalConfig.save();
                }
            }
        }
    }
}
