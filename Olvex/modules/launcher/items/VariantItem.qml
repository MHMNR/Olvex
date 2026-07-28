import QtQuick
import Olvex.Config
import qs.components
import qs.services
import qs.modules.launcher.services

Item {
    id: root

    required property M3Variants.Variant modelData
    required property var list

    implicitHeight: Tokens.sizes.launcher.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: Tokens.rounding.normal
        onClicked: root.modelData?.onClicked(root.list)
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.larger
        anchors.rightMargin: Tokens.padding.larger
        anchors.margins: Tokens.padding.smaller

        MaterialIcon {
            id: icon

            text: root.modelData?.icon ?? ""
            // removed font.pointSize to avoid point/pixel conflict warnings

            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.left: icon.right
            anchors.leftMargin: Tokens.spacing.larger
            anchors.verticalCenter: icon.verticalCenter

            width: parent.width - icon.width - anchors.leftMargin - (current.active ? current.width + Tokens.spacing.normal : 0)
            spacing: 0

            StyledText {
                text: root.modelData?.name ?? ""
                // removed font.pointSize to avoid point/pixel conflict warnings
            }

            StyledText {
                text: root.modelData?.description ?? ""
                // removed font.pointSize to avoid point/pixel conflict warnings
                color: Colours.palette.m3outline

                elide: Text.ElideRight
                anchors.left: parent.left
                anchors.right: parent.right
            }
        }

        Loader {
            id: current

            asynchronous: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            active: root.modelData?.variant === Schemes.currentVariant

            sourceComponent: MaterialIcon {
                text: "check"
                color: Colours.palette.m3onSurfaceVariant
                // removed font.pointSize to avoid point/pixel conflict warnings
            }
        }
    }
}
