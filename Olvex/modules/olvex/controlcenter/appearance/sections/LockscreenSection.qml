pragma ComponentBehavior: Bound

import QtQuick
import Olvex.Config
import qs.components.containers
import qs.components.controls

CollapsibleSection {
    id: root

    required property var rootPane

    title: qsTr("Lockscreen")
    description: qsTr("Card or minimal lock layout")
    showBackground: true

    SplitButtonRow {
        id: lockStyleSelector

        label: qsTr("Style")
        active: styleItems[indexFor(GlobalConfig.lock.style)]
        readonly property var styleItems: [cardItem, minimalItem]

        menuItems: [
            MenuItem { id: cardItem; property string val: "card"; text: qsTr("Card"); icon: "dashboard" },
            MenuItem { id: minimalItem; property string val: "minimal"; text: qsTr("Minimal"); icon: "view_day" }
        ]

        function indexFor(style: string): int {
            return style === "minimal" ? 1 : 0;
        }

        onSelected: item => {
            rootPane.lockStyle = item?.val ?? "card";
            rootPane.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("Lock on startup")
        checked: GlobalConfig.lock.showOnStartup
        onToggled: {
            GlobalConfig.lock.showOnStartup = checked;
            rootPane.saveConfig();
        }
    }
}

