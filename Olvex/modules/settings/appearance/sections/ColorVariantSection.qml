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
    title: qsTr("Color variant")
    description: qsTr("Material theme variant")
    showBackground: true

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small / 2

        Repeater {
            model: M3Variants.list

            delegate: StyledRect {
                id: delegateRoot
                required property var modelData

                Layout.fillWidth: true

                color: Qt.alpha(Colours.tPalette.m3surfaceContainer, delegateRoot.modelData.variant === Schemes.currentVariant ? Colours.tPalette.m3surfaceContainer.a : 0)
                radius: Tokens.rounding.normal
                border.width: delegateRoot.modelData.variant === Schemes.currentVariant ? 1 : 0
                border.color: Colours.palette.m3primary
                implicitHeight: variantRow.implicitHeight + Tokens.padding.normal * 2

                StateLayer {
                    onClicked: {
                        const variant = delegateRoot.modelData.variant;
                        Schemes.setVariant(variant);
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
                    id: variantRow

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Tokens.padding.normal

                    spacing: Tokens.spacing.normal

                    MaterialIcon {
                        text: delegateRoot.modelData.icon
                        iconPointSize: Tokens.font.size.large
                        fill: delegateRoot.modelData.variant === Schemes.currentVariant ? 1 : 0
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: delegateRoot.modelData.name
                        font.weight: delegateRoot.modelData.variant === Schemes.currentVariant ? 400 : 400
                    }

                    MaterialIcon {
                        visible: delegateRoot.modelData.variant === Schemes.currentVariant
                        text: "check"
                        color: Colours.palette.m3primary
                        iconPointSize: Tokens.font.size.large
                    }
                }
            }
        }
    }
}
