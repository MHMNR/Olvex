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
    id: root

    required property var rootPane

    title: qsTr("Transparency")
    showBackground: true

    SwitchRow {
        label: qsTr("Transparency enabled")
        checked: rootPane.transparencyEnabled
        onToggled: checked => {
            rootPane.transparencyEnabled = checked;
            rootPane.saveConfig();
        }
    }

    SectionContainer {
        contentSpacing: Tokens.spacing.normal

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Transparency base")
            value: rootPane.transparencyBase * 100
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
                rootPane.transparencyBase = newValue / 100;
                rootPane.saveConfig();
            }
        }
    }

    SectionContainer {
        contentSpacing: Tokens.spacing.normal

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Transparency layers")
            value: rootPane.transparencyLayers * 100
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
                rootPane.transparencyLayers = newValue / 100;
                rootPane.saveConfig();
            }
        }
    }
}
