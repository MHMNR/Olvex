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

    SwitchRow {
        label: qsTr("Blur background")
        checked: rootPane.lockBlurBackground
        onToggled: {
            rootPane.lockBlurBackground = checked;
            rootPane.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("Dim wallpaper")
        checked: rootPane.lockDimWallpaper
        onToggled: {
            rootPane.lockDimWallpaper = checked;
            rootPane.saveConfig();
        }
    }

    SectionContainer {
        contentSpacing: Tokens.spacing.normal

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Elements opacity")
            value: rootPane.lockMinimalOpacity * 100
            from: 0
            to: 100
            suffix: "%"
            validator: IntValidator {
                bottom: 0
                top: 100
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                rootPane.lockMinimalOpacity = newValue / 100;
                rootPane.saveConfig();
            }
        }
    }
}
