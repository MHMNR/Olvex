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
        title: qsTr("Transparency")
        description: qsTr("Glass surfaces across the shell")
        icon: "opacity"

        SettingRow {
            title: qsTr("Enable transparency")
            description: qsTr("Make panels and popups translucent")
            StyledSwitch {
                checked: GlobalConfig.appearance.transparency.enabled
                onToggled: {
                    GlobalConfig.appearance.transparency.enabled = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Base opacity")
            description: qsTr("Opacity of panel backgrounds")
            StyledSlider {
                width: 280
                from: 0
                to: 1
                value: GlobalConfig.appearance.transparency.base
                onMoved: {
                    GlobalConfig.appearance.transparency.base = value;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Layer opacity")
            description: qsTr("Opacity of raised surfaces and cards")
            divider: false
            StyledSlider {
                width: 280
                from: 0
                to: 1
                value: GlobalConfig.appearance.transparency.layers
                onMoved: {
                    GlobalConfig.appearance.transparency.layers = value;
                    GlobalConfig.save();
                }
            }
        }
    }
}
