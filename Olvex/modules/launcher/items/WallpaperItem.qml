import QtQuick
import Olvex.Config
import Olvex.Models
import qs.components
import qs.components.effects
import qs.components.images
import qs.services

Item {
    id: root

    required property var modelData
    required property DrawerVisibilities visibilities

    readonly property bool hasEntry: root.modelData !== null && root.modelData !== undefined

    scale: 0.5
    opacity: 0
    z: PathView.z ?? 0 // qmllint disable missing-property

    function select() {
        if (!root.hasEntry || !root.modelData.path)
            return;
        Wallpapers.setWallpaper(root.modelData.path);
    }

    visible: root.hasEntry

    Component.onCompleted: {
        scale = Qt.binding(() => PathView.isCurrentItem ? 1 : PathView.onPath ? 0.8 : 0);
        opacity = Qt.binding(() => PathView.onPath ? 1 : 0);
    }

    implicitWidth: image.width + Tokens.padding.larger * 2
    implicitHeight: image.height + label.height + Tokens.spacing.small / 2 + Tokens.padding.large + Tokens.padding.normal

    StateLayer {
        radius: Tokens.rounding.normal
        onClicked: root.select()
    }

    Elevation {
        anchors.fill: image
        radius: image.radius
        opacity: root.PathView.isCurrentItem ? 1 : 0
        level: 4

        Behavior on opacity {
            Anim {}
        }
    }

    StyledClippingRect {
        id: image

        anchors.horizontalCenter: parent.horizontalCenter
        y: Tokens.padding.large
        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.normal

        implicitWidth: Tokens.sizes.launcher.wallpaperWidth
        implicitHeight: implicitWidth / 16 * 9

        MaterialIcon {
            anchors.centerIn: parent
            text: "image"
            color: Colours.tPalette.m3outline
            font.pointSize: Tokens.font.size.extraLarge * 2
            font.weight: 600
        }

        Image {
            id: img
            source: {
                const _ = Wallpapers.thumbnailUpdateCount; // Force dependency
                if (!root.hasEntry)
                    return "";
                const p = root.modelData.path;
                if (!p) return "";
                if (root.modelData.isVideo || Wallpapers.isVideoPath(p)) {
                    const thumb = Wallpapers.videoThumbnailMap[p];
                    return thumb ? (thumb.startsWith("file://") ? thumb : "file://" + thumb) : "";
                }
                return p.startsWith("file://") ? p : "file://" + p;
            }
            sourceSize.width: 640
            sourceSize.height: 360
            fillMode: Image.PreserveAspectCrop
            smooth: !root.PathView.view.moving
            asynchronous: true

            anchors.fill: parent
        }
    }

    StyledText {
        id: label

        anchors.top: image.bottom
        anchors.topMargin: Tokens.spacing.small / 2
        anchors.horizontalCenter: parent.horizontalCenter

        width: image.width - Tokens.padding.normal * 2
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        renderType: Text.QtRendering
        text: root.hasEntry ? (root.modelData.name ?? "") : ""
        font.pointSize: Tokens.font.size.normal
    }

    Behavior on scale {
        Anim {}
    }

    Behavior on opacity {
        Anim {}
    }
}
