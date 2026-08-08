pragma ComponentBehavior: Bound


import "../.."
import "../../chrome"
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

    title: qsTr("Border")
    showBackground: true

    SectionContainer {
        contentSpacing: Tokens.spacing.normal

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Border rounding")
            value: rootPane.borderRounding
            from: 0.1
            to: 100
            decimals: 1
            suffix: "px"
            validator: DoubleValidator {
                bottom: 0.1
                top: 100
            }

            onValueModified: newValue => {
                rootPane.borderRounding = newValue;
                rootPane.saveConfig();
            }
        }
    }

    SectionContainer {
        contentSpacing: Tokens.spacing.normal

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Border thickness")
            value: rootPane.borderThickness
            from: 0
            to: 100
            decimals: 1
            suffix: "px"
            validator: DoubleValidator {
                bottom: 0.1
                top: 100
            }

            onValueModified: newValue => {
                rootPane.borderThickness = newValue;
                rootPane.saveConfig();
            }
        }
    }

    SectionContainer {
        contentSpacing: Tokens.spacing.normal

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Drawer mode")
                color: Colours.palette.m3onSurface
                font.weight: Font.Medium
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Hugging sticks panels to edges; Floating leaves a border gap")
                color: Colours.palette.m3onSurfaceVariant
                textPointSize: Tokens.font.size.small
                wrapMode: Text.WordWrap
            }

            // Segmented control — TextButton checked-state was unreliable here
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: Tokens.rounding.full
                    border.width: 0
                    color: !rootPane.borderFloating
                        ? Colours.palette.m3secondary
                        : Colours.palette.m3secondaryContainer

                    Behavior on color {
                        CAnim {}
                    }

                    StateLayer {
                        radius: parent.radius
                        color: !rootPane.borderFloating
                            ? Colours.palette.m3onSecondary
                            : Colours.palette.m3onSecondaryContainer
                        onClicked: {
                            rootPane.borderFloating = false;
                            rootPane.saveConfig();
                            if (GlobalConfig.border)
                                GlobalConfig.border.floating = false;
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: qsTr("Hugging")
                        font.weight: Font.Medium
                        color: !rootPane.borderFloating
                            ? Colours.palette.m3onSecondary
                            : Colours.palette.m3onSecondaryContainer
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: Tokens.rounding.full
                    border.width: 0
                    color: rootPane.borderFloating
                        ? Colours.palette.m3secondary
                        : Colours.palette.m3secondaryContainer

                    Behavior on color {
                        CAnim {}
                    }

                    StateLayer {
                        radius: parent.radius
                        color: rootPane.borderFloating
                            ? Colours.palette.m3onSecondary
                            : Colours.palette.m3onSecondaryContainer
                        onClicked: {
                            rootPane.borderFloating = true;
                            rootPane.saveConfig();
                            if (GlobalConfig.border)
                                GlobalConfig.border.floating = true;
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: qsTr("Floating")
                        font.weight: Font.Medium
                        color: rootPane.borderFloating
                            ? Colours.palette.m3onSecondary
                            : Colours.palette.m3onSecondaryContainer
                    }
                }
            }
        }
    }
}
