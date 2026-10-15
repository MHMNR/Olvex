import QtQuick
import Olvex.Config
import qs.components
import qs.services
import qs.modules.launcher.services

Item {
    id: root

    required property Schemes.Scheme modelData
    required property var list
    required property int index
    readonly property bool isCurrent: list.currentIndex === index

    implicitHeight: Tokens.sizes.launcher.itemHeight

    anchors.left: parent ? parent.left : undefined
    anchors.right: parent ? parent.right : undefined

    StateLayer {
        radius: Tokens.rounding.normal
        showHoverBackground: false
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

        StyledRect {
            id: preview

            anchors.verticalCenter: parent.verticalCenter

            border.width: 1
            border.color: Qt.alpha((root.modelData && root.modelData.colours) ? `#${root.modelData.colours.outline}` : "#000000", 0.5)

            color: (root.modelData && root.modelData.colours) ? `#${root.modelData.colours.surface}` : "transparent"
            radius: Tokens.rounding.full
            implicitWidth: parent.height * 0.8
            implicitHeight: parent.height * 0.8

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
                    color: (root.modelData && root.modelData.colours) ? `#${root.modelData.colours.primary}` : "transparent"
                    radius: Tokens.rounding.full
                }
            }
        }

        Column {
            anchors.left: preview.right
            anchors.leftMargin: Tokens.spacing.normal
            anchors.verticalCenter: parent.verticalCenter

            width: parent.width - preview.width - anchors.leftMargin - (current.active ? current.width + Tokens.spacing.normal : 0)
            spacing: 0

            StyledText {
                text: root.modelData ? (root.modelData.flavour || "") : ""
                textPointSize: Tokens.font.size.normal
                color: Colours.palette.m3onSurface
                font.weight: isCurrent ? Font.DemiBold : Font.Normal
            }

            StyledText {
                text: root.modelData ? (root.modelData.name || "") : ""
                textPointSize: Tokens.font.size.small
                color: isCurrent ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant

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

            active: Boolean(root.modelData && (`${root.modelData.name} ${root.modelData.flavour}` === Schemes.currentScheme))

            sourceComponent: MaterialIcon {
                text: "check"
                color: isCurrent ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                iconPointSize: Tokens.font.size.large
            }
        }
    }
}
