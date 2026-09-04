pragma ComponentBehavior: Bound


import "../.."
import "../../ui"
import "../../components"
import "../../../../components"
import "../../../../components/controls"
import "../../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.services

CollapsibleSection {
    title: qsTr("Theme mode")
    description: qsTr("Light, dark, or auto mode")
    showBackground: true

    SplitButtonRow {
        id: modeSelector

        label: qsTr("Mode")
        active: modeItems[modeIndex(GlobalConfig.appearance.themeMode)]
        expandedZ: 150
        menuOnTop: true
        readonly property var modeItems: [lightItem, darkItem, autoItem]

        menuItems: [
            MenuItem { id: lightItem; property string val: "light"; text: qsTr("Light"); icon: "light_mode" },
            MenuItem { id: darkItem; property string val: "dark"; text: qsTr("Dark"); icon: "dark_mode" },
            MenuItem { id: autoItem; property string val: "auto"; text: qsTr("Auto"); icon: "brightness_auto" }
        ]

        function modeIndex(mode: string): int {
            switch (mode) {
            case "light":
                return 0;
            case "dark":
                return 1;
            default:
                return 2;
            }
        }

        onSelected: item => {
            const nextMode = item?.val ?? "auto";
            GlobalConfig.appearance.themeMode = nextMode;
            GlobalConfig.save();
            Colours.setMode(nextMode);
        }
    }

    SwitchRow {
        label: qsTr("Night light")
        checked: NightLight.enabled
        onToggled: NightLight.enabled = checked
    }

    SwitchRow {
        label: qsTr("Auto schedule")
        checked: NightLight.autoSchedule
        onToggled: NightLight.autoSchedule = checked
    }

    SectionContainer {
        contentSpacing: Tokens.spacing.normal

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Color temperature")
            value: NightLight.temperature
            from: 2500
            to: 6500
            suffix: "K"
            validator: IntValidator {
                bottom: 2500
                top: 6500
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                NightLight.temperature = Math.round(newValue);
            }
        }
    }
}
