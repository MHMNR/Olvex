import ".."
import "../components"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services

SectionContainer {
    id: root

    required property var rootItem

    Layout.fillWidth: true
    alignTop: true

    StyledText {
        text: qsTr("General Settings")
        font.pointSize: Tokens.font.size.normal
    }

    SwitchRow {
        label: qsTr("Enabled")
        checked: root.rootItem.enabled
        onToggled: checked => {
            root.rootItem.enabled = checked;
            root.rootItem.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("Show on hover")
        checked: root.rootItem.showOnHover
        onToggled: checked => {
            root.rootItem.showOnHover = checked;
            root.rootItem.saveConfig();
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.normal

        SwitchRow {
            Layout.fillWidth: true
            label: qsTr("Show Dashboard tab")
            checked: root.rootItem.showDashboard
            onToggled: checked => {
                root.rootItem.showDashboard = checked;
                root.rootItem.saveConfig();
            }
        }

        SwitchRow {
            Layout.fillWidth: true
            label: qsTr("Show Performance tab")
            checked: root.rootItem.showPerformance
            onToggled: checked => {
                root.rootItem.showPerformance = checked;
                root.rootItem.saveConfig();
            }
        }

        SwitchRow {
            Layout.fillWidth: true
            label: qsTr("Show Weather tab")
            checked: root.rootItem.showWeather
            onToggled: checked => {
                root.rootItem.showWeather = checked;
                root.rootItem.saveConfig();
            }
        }
    }

    SliderInput {
        Layout.fillWidth: true

        label: qsTr("Drag threshold")
        value: root.rootItem.dragThreshold
        from: 0
        to: 100
        suffix: "px"
        validator: IntValidator {
            bottom: 0
            top: 100
        }
        formatValueFunction: val => Math.round(val).toString()
        parseValueFunction: text => parseInt(text)

        onValueModified: newValue => {
            root.rootItem.dragThreshold = Math.round(newValue);
            root.rootItem.saveConfig();
        }
    }

    StyledText {
        text: qsTr("Card Sizes")
        font.pointSize: Tokens.font.size.normal
    }

    SliderInput {
        Layout.fillWidth: true
        label: qsTr("Card Width")
        value: root.rootItem.colUnit
        from: 150
        to: 400
        suffix: "px"
        onValueModified: newValue => {
            root.rootItem.colUnit = Math.round(newValue);
            root.rootItem.saveConfig();
        }
    }

    SliderInput {
        Layout.fillWidth: true
        label: qsTr("Top Card Height")
        value: root.rootItem.rowTopHeight
        from: 100
        to: 500
        suffix: "px"
        onValueModified: newValue => {
            root.rootItem.rowTopHeight = Math.round(newValue);
            root.rootItem.saveConfig();
        }
    }

    SliderInput {
        Layout.fillWidth: true
        label: qsTr("Bottom Card Height")
        value: root.rootItem.rowBotHeight
        from: 100
        to: 400
        suffix: "px"
        onValueModified: newValue => {
            root.rootItem.rowBotHeight = Math.round(newValue);
            root.rootItem.saveConfig();
        }
    }
}
