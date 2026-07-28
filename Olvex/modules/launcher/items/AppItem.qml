import QtQuick
import Quickshell
import Quickshell.Widgets
import Olvex.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.launcher.services

Item {
    id: root

    required property DesktopEntry modelData
    required property DrawerVisibilities visibilities

    signal contextMenuRequested(sourceItem: Item)

    implicitHeight: Tokens.sizes.launcher.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        id: stateLayer
        radius: Tokens.rounding.normal
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.contextMenuRequested(stateLayer);
            } else {
                Apps.launch(root.modelData);
                root.visibilities.launcher = false;
            }
        }
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.larger
        anchors.rightMargin: Tokens.padding.larger
        anchors.margins: Tokens.padding.smaller

        Rectangle {
            id: icon
            width: 36
            height: 36
            radius: 8
            color: Colours.layer(Colours.palette.m3surfaceVariant, 0.5)
            border.color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter

            IconImage {
                asynchronous: true
                source: Icons.resolveIcon(root.modelData?.icon || "", "image-missing")
                anchors.fill: parent
                anchors.margins: 5
            }
        }

        Item {
            anchors.left: icon.right
            anchors.leftMargin: Tokens.spacing.normal
            anchors.verticalCenter: icon.verticalCenter

            implicitWidth: parent.width - icon.width - favouriteIcon.width
            implicitHeight: name.implicitHeight + comment.implicitHeight

            StyledText {
                id: name

                text: root.modelData?.name ?? ""
                // use pixelSize elsewhere; remove pointSize to avoid "Both point size and pixel size set" warning
                color: Colours.light ? "#000000" : "#ffffff"
            }

            StyledText {
                id: comment

                text: (root.modelData?.comment || root.modelData?.genericName || root.modelData?.name) ?? ""
                textPointSize: Tokens.font.size.small
                color: Colours.palette.m3outline

                elide: Text.ElideRight
                width: root.width - icon.width - favouriteIcon.width - Tokens.rounding.normal * 2

                anchors.top: name.bottom
            }
        }

        Loader {
            id: favouriteIcon

            asynchronous: true
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            active: root.modelData && Strings.testRegexList(GlobalConfig.launcher.favouriteApps, root.modelData.id)

            sourceComponent: MaterialIcon {
                text: "favorite"
                fill: 1
                color: Colours.palette.m3primary
            }
        }
    }

    // Context menu is handled by the shared menu in AppList
}
