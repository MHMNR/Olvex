import QtQuick
import Quickshell
import Quickshell.Widgets
import Olvex.Config
import qs.components
import qs.components.effects
import qs.services
import qs.utils
import qs.modules.launcher.services

Item {
    id: root

    required property DesktopEntry modelData
    required property DrawerVisibilities visibilities

    signal contextMenuRequested(sourceItem: Item)

    implicitHeight: Tokens.sizes.launcher.itemHeight

    anchors.left: parent ? parent.left : undefined
    anchors.right: parent ? parent.right : undefined

    readonly property real itemViewportY: y - (ListView.view ? ListView.view.contentY : 0)
    readonly property real itemViewportBottom: itemViewportY + height
    readonly property bool isInView: !ListView.view || (itemViewportBottom > -4 && itemViewportY < ListView.view.height + 4)

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
        id: body
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.larger
        anchors.rightMargin: Tokens.padding.larger
        anchors.margins: Tokens.padding.smaller

        opacity: root.isInView ? 1.0 : 0.0
        scale: root.isInView ? 1.0 : 0.92

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutQuad
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutQuad
            }
        }

        Item {
            id: icon
            width: 36
            height: 36
            anchors.verticalCenter: parent.verticalCenter

            MaterialShape {
                anchors.fill: parent
                implicitSize: parent.width
                shape: MaterialShape.Square
                color: Colours.layer(Colours.palette.m3surfaceVariant, 0.4)
            }

            IconImage {
                id: appIcon
                asynchronous: true
                smooth: true
                mipmap: true
                source: root.modelData ? Icons.resolveApp(root.modelData) : ""
                anchors.fill: parent
                anchors.margins: 4
            }

            StyledText {
                anchors.centerIn: parent
                visible: !appIcon.source || appIcon.status === Image.Error || appIcon.status === Image.Null
                text: root.modelData && root.modelData.name ? root.modelData.name.charAt(0).toUpperCase() : "?"
                font.weight: Font.DemiBold
                textPointSize: Tokens.font.size.normal
                color: Colours.palette.m3primary
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

                text: root.modelData ? (root.modelData.name || "") : ""
                // use pixelSize elsewhere; remove pointSize to avoid "Both point size and pixel size set" warning
                color: Colours.light ? "#000000" : "#ffffff"
            }

            StyledText {
                id: comment

                text: root.modelData ? (root.modelData.comment || root.modelData.genericName || root.modelData.name || "") : ""
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
