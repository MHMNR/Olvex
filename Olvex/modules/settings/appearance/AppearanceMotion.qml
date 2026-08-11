pragma ComponentBehavior: Bound


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

ColumnLayout {
    id: root
    
    property Session session
    spacing: Tokens.spacing.large

    Section {
        Layout.fillWidth: true
        title: qsTr("Motion")
        description: qsTr("Animation timing across the shell")
        icon: "animation"

        SettingRow {
            title: qsTr("Animation speed")
            description: qsTr("Multiplier for all durations — lower is faster")
            StyledSlider {
                width: 220
                from: 0.1
                to: 3.0
                value: GlobalConfig.appearance.anim.durations.scale
                onMoved: {
                    if (GlobalConfig.appearance.anim.durations.scale > 0.0) {
                        GlobalConfig.appearance.anim.durations.scale = value;
                        GlobalConfig.save();
                    }
                }
            }
        }
        
        SettingRow {
            title: qsTr("No Animation")
            description: qsTr("Disable all animations globally")
            divider: false
            StyledSwitch {
                checked: GlobalConfig.appearance.anim.durations.scale <= 0.0
                onToggled: {
                    if (checked) {
                        GlobalConfig.appearance.anim.durations.scale = 0.0;
                    } else {
                        GlobalConfig.appearance.anim.durations.scale = 1.0;
                    }
                    GlobalConfig.save();
                }
            }
        }
    }
}
