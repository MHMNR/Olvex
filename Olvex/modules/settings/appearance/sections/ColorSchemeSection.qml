pragma ComponentBehavior: Bound


import "../.."
import "../../chrome"
import "../../components"
import "../../../../components"
import "../../../../components/controls"
import "../../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Olvex.Config
import qs.services

CollapsibleSection {
    title: qsTr("Color scheme")
    description: qsTr("Available color schemes")
    showBackground: true

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small / 2

        Repeater {
            model: Schemes.list

            delegate: StyledRect {
                id: delegateRoot
                required property var modelData

                Layout.fillWidth: true

                readonly property string schemeKey: `${delegateRoot.modelData.name} ${delegateRoot.modelData.flavour}`
                readonly property bool isCurrent: schemeKey === Schemes.currentScheme

                color: Qt.alpha(Colours.tPalette.m3surfaceContainer, isCurrent ? Colours.tPalette.m3surfaceContainer.a : 0)
                radius: Tokens.rounding.normal
                border.width: isCurrent ? 1 : 0
                border.color: Colours.palette.m3primary
                implicitHeight: schemeRow.implicitHeight + Tokens.padding.normal * 2

                StateLayer {
                    onClicked: {
                        const name = delegateRoot.modelData.name;
                        const flavour = delegateRoot.modelData.flavour;
                        Schemes.setScheme(name, flavour);
                    }
                }

                Timer {
                    id: reloadTimer

                    interval: 300
                    onTriggered: {
                        Schemes.reload();
                    }
                }

                RowLayout {
                    id: schemeRow

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.normal

                    spacing: Tokens.spacing.normal

                    StyledRect {
                        id: preview

                        Layout.alignment: Qt.AlignVCenter

                        border.width: 1
                        border.color: isCurrent ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, 0.5)

                        color: `#${delegateRoot.modelData.colours?.surface}`
                        radius: Tokens.rounding.full
                        implicitWidth: iconPlaceholder.implicitWidth
                        implicitHeight: iconPlaceholder.implicitWidth

                        MaterialIcon {
                            id: iconPlaceholder

                            visible: false
                            text: "circle"
                            iconPointSize: Tokens.font.size.large
                        }

                        Item {
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right

                            implicitWidth: parent.implicitWidth / 2
                            clip: true

                            StyledRect {
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right

                                implicitWidth: preview.implicitWidth
                                color: `#${delegateRoot.modelData.colours?.primary}`
                                radius: Tokens.rounding.full
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: delegateRoot.modelData.flavour ?? ""
                            font.weight: isCurrent ? 500 : 400
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: delegateRoot.modelData.name ?? ""
                            textPointSize: Tokens.font.size.small
                            color: Colours.palette.m3outline

                            elide: Text.ElideRight
                        }
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
