pragma ComponentBehavior: Bound

import ".."
import QtQuick
import Olvex.Config
import qs.components
import qs.components.containers
import qs.components.controls
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
}
