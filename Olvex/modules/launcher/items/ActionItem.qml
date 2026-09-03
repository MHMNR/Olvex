import QtQuick
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    required property var modelData
    required property var list
    required property int index

    readonly property bool isCurrent: list.currentIndex === index

    implicitHeight: Tokens.sizes.launcher.itemHeight

    anchors.left: parent ? parent.left : undefined
    anchors.right: parent ? parent.right : undefined

    StateLayer {
        radius: Tokens.rounding.normal
        onClicked: {
            if (root.modelData && root.modelData.onClicked)
                root.modelData.onClicked(root.list);
        }
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.larger
        anchors.rightMargin: Tokens.padding.larger
        anchors.margins: Tokens.padding.smaller

        MaterialIcon {
            id: icon

            text: root.modelData ? (root.modelData.icon || "") : ""
            iconPointSize: Tokens.font.size.extraLarge
            color: isCurrent ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant

            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            anchors.left: icon.right
            anchors.leftMargin: Tokens.spacing.normal
            anchors.verticalCenter: icon.verticalCenter

            implicitWidth: parent.width - icon.width
            implicitHeight: name.implicitHeight + desc.implicitHeight

            StyledText {
                id: name

                text: root.modelData ? (root.modelData.name || "") : ""
                textPointSize: Tokens.font.size.normal
                color: isCurrent ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                font.weight: isCurrent ? Font.DemiBold : Font.Normal
            }

            StyledText {
                id: desc

                text: root.modelData ? (root.modelData.desc || "") : ""
                textPointSize: Tokens.font.size.small
                color: isCurrent ? Colours.palette.m3onPrimary : Colours.palette.m3outline

                elide: Text.ElideRight
                width: root.width - icon.width - Tokens.rounding.normal * 2

                anchors.top: name.bottom
            }
        }
    }
}
