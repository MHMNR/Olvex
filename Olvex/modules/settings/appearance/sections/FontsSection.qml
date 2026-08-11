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

    title: qsTr("Fonts")
    showBackground: true

    CollapsibleSection {
        id: sansFontSection

        title: qsTr("Sans-serif font family")
        expanded: true
        showBackground: true
        nested: true

        Loader {
            Layout.fillWidth: true
            Layout.preferredHeight: item ? Math.min(item.contentHeight, 300) : 0
            asynchronous: true
            active: sansFontSection.expanded

            sourceComponent: StyledListView {
                id: sansFontList

                property alias contentHeight: sansFontList.contentHeight

                clip: true
                spacing: Tokens.spacing.small / 2
                model: Qt.fontFamilies()

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: sansFontList
                }

                delegate: StyledRect {
                    id: sansDelegate
                    required property string modelData
                    required property int index
                    readonly property bool isCurrent: sansDelegate.modelData === rootPane.fontFamilySans

                    width: ListView.view.width
                    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, isCurrent ? Colours.tPalette.m3surfaceContainer.a : 0)
                    radius: Tokens.rounding.normal
                    border.width: isCurrent ? 1 : 0
                    border.color: Colours.palette.m3primary
                    implicitHeight: fontFamilySansRow.implicitHeight + Tokens.padding.normal * 2

                    StateLayer {
                        onClicked: {
                            rootPane.fontFamilySans = sansDelegate.modelData;
                            rootPane.saveConfig();
                        }
                    }

                    RowLayout {
                        id: fontFamilySansRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Tokens.padding.normal

                        spacing: Tokens.spacing.normal

                        StyledText {
                            text: sansDelegate.modelData
                            textPointSize: Tokens.font.size.normal
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Loader {
                            asynchronous: true
                            active: isCurrent

                            sourceComponent: MaterialIcon {
                                text: "check"
                                color: Colours.palette.m3onSurfaceVariant
                                iconPointSize: Tokens.font.size.large
                            }
                        }
                    }
                }
            }
        }
    }

    CollapsibleSection {
        id: monoFontSection

        title: qsTr("Monospace font family")
        expanded: false
        showBackground: true
        nested: true

        Loader {
            Layout.fillWidth: true
            Layout.preferredHeight: item ? Math.min(item.contentHeight, 300) : 0
            asynchronous: true
            active: monoFontSection.expanded

            sourceComponent: StyledListView {
                id: monoFontList

                property alias contentHeight: monoFontList.contentHeight

                clip: true
                spacing: Tokens.spacing.small / 2
                model: Qt.fontFamilies()

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: monoFontList
                }

                delegate: StyledRect {
                    id: monoDelegate
                    required property string modelData
                    required property int index
                    readonly property bool isCurrent: monoDelegate.modelData === rootPane.fontFamilyMono

                    width: ListView.view.width
                    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, isCurrent ? Colours.tPalette.m3surfaceContainer.a : 0)
                    radius: Tokens.rounding.normal
                    border.width: isCurrent ? 1 : 0
                    border.color: Colours.palette.m3primary
                    implicitHeight: fontFamilyMonoRow.implicitHeight + Tokens.padding.normal * 2

                    StateLayer {
                        onClicked: {
                            rootPane.fontFamilyMono = monoDelegate.modelData;
                            rootPane.saveConfig();
                        }
                    }

                    RowLayout {
                        id: fontFamilyMonoRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Tokens.padding.normal

                        spacing: Tokens.spacing.normal

                        StyledText {
                            text: monoDelegate.modelData
                            textPointSize: Tokens.font.size.normal
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Loader {
                            asynchronous: true
                            active: isCurrent

                            sourceComponent: MaterialIcon {
                                text: "check"
                                color: Colours.palette.m3onSurfaceVariant
                                iconPointSize: Tokens.font.size.large
                            }
                        }
                    }
                }
            }
        }
    }

    CollapsibleSection {
        id: materialFontSection

        title: qsTr("Material font family")
        expanded: false
        showBackground: true
        nested: true

        Loader {
            id: materialFontLoader

            Layout.fillWidth: true
            Layout.preferredHeight: item ? Math.min(item.contentHeight, 300) : 0
            asynchronous: true
            active: materialFontSection.expanded

            sourceComponent: StyledListView {
                id: materialFontList

                property alias contentHeight: materialFontList.contentHeight

                clip: true
                spacing: Tokens.spacing.small / 2
                model: Qt.fontFamilies().filter(f => f.startsWith("Material Symbols"))

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: materialFontList
                }

                delegate: StyledRect {
                    id: materialDelegate
                    required property string modelData
                    required property int index
                    readonly property bool isCurrent: materialDelegate.modelData === rootPane.fontFamilyMaterial

                    width: ListView.view.width
                    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, isCurrent ? Colours.tPalette.m3surfaceContainer.a : 0)
                    radius: Tokens.rounding.normal
                    border.width: isCurrent ? 1 : 0
                    border.color: Colours.palette.m3primary
                    implicitHeight: fontFamilyMaterialRow.implicitHeight + Tokens.padding.normal * 2

                    StateLayer {
                        onClicked: {
                            rootPane.fontFamilyMaterial = materialDelegate.modelData;
                            rootPane.saveConfig();
                        }
                    }

                    RowLayout {
                        id: fontFamilyMaterialRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Tokens.padding.normal

                        spacing: Tokens.spacing.normal

                        StyledText {
                            text: materialDelegate.modelData
                            textPointSize: Tokens.font.size.normal
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Loader {
                            asynchronous: true
                            active: isCurrent

                            sourceComponent: MaterialIcon {
                                text: "check"
                                color: Colours.palette.m3onSurfaceVariant
                                iconPointSize: Tokens.font.size.large
                            }
                        }
                    }
                }
            }
        }
    }

    SectionContainer {
        contentSpacing: Tokens.spacing.normal

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Font size scale")
            value: rootPane.fontSizeScale
            from: 0.7
            to: 1.5
            decimals: 2
            suffix: "×"
            validator: DoubleValidator {
                bottom: 0.7
                top: 1.5
            }

            onValueModified: newValue => {
                rootPane.fontSizeScale = newValue;
                rootPane.saveConfig();
            }
        }
    }
}
