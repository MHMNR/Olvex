pragma ComponentBehavior: Bound


import ".."
import "../chrome"
import "."
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import Olvex.Config
import Olvex.Models
import qs.services

GridView {
    id: root

    required property Session session

    Component.onCompleted: Wallpapers.ensureCatalog()

    readonly property int minCellWidth: 200 + Tokens.spacing.normal
    readonly property int columnsCount: Math.max(1, Math.floor(width / minCellWidth))

    cellWidth: width / columnsCount
    cellHeight: 140 + Tokens.spacing.normal

    model: Wallpapers.list

    clip: true

    StyledScrollBar.vertical: StyledScrollBar {
        flickable: root
    }

    delegate: Item {
        required property var modelData
        required property int index
        readonly property bool isCurrent: modelData && modelData.path === Wallpapers.actualCurrent
        readonly property real itemMargin: Tokens.spacing.normal / 2
        readonly property real itemRadius: Tokens.rounding.normal

        width: root.cellWidth
        height: root.cellHeight

        StateLayer {
            onClicked: {
                Wallpapers.setWallpaper(modelData.path);
            }

            anchors.fill: parent
            anchors.leftMargin: itemMargin
            anchors.rightMargin: itemMargin
            anchors.topMargin: itemMargin
            anchors.bottomMargin: itemMargin
            radius: itemRadius
        }

        StyledClippingRect {
            id: image

            anchors.fill: parent
            anchors.leftMargin: itemMargin
            anchors.rightMargin: itemMargin
            anchors.topMargin: itemMargin
            anchors.bottomMargin: itemMargin
            color: Colours.tPalette.m3surfaceContainer
            radius: itemRadius
            antialiasing: true
            layer.enabled: true
            layer.smooth: true

            // Resolve live → jpg thumb (video paths cannot paint as Image)
            readonly property string resolvedPath: {
                const _ = Wallpapers.thumbnailUpdateCount;
                return Wallpapers.displayPathFor(modelData?.path ?? "") || (modelData?.path ?? "");
            }

            Component.onCompleted: {
                if (Wallpapers.isVideoPath(modelData?.path ?? ""))
                    Wallpapers.queueThumbnail(modelData.path, isCurrent);
            }

            Image {
                id: cachingImage

                anchors.fill: parent
                source: {
                    const p = image.resolvedPath;
                    if (!p || Wallpapers.isVideoPath(p))
                        return "";
                    return p.startsWith("file:") ? p : ("file://" + p);
                }
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: opacity > 0
                antialiasing: true
                smooth: true
                mipmap: true
                sourceSize: Qt.size(Math.max(1, Math.round(width * 2)), Math.max(1, Math.round(height * 2)))
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 280
                        easing.type: Easing.OutQuad
                    }
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: Wallpapers.isVideoPath(modelData?.path ?? "") && cachingImage.status !== Image.Ready
                text: "movie"
                color: Colours.palette.m3outline
                iconPointSize: Tokens.font.size.extraLarge
            }

            // Flat scrim for filename (no gradient)
            Rectangle {
                id: filenameOverlay

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                implicitHeight: filenameText.implicitHeight + Tokens.padding.normal * 1.5
                radius: 0
                color: Qt.alpha(Colours.palette.m3surface, 0.88)

                opacity: 0

                Component.onCompleted: {
                    opacity = 1;
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 1000
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: itemMargin
            anchors.rightMargin: itemMargin
            anchors.topMargin: itemMargin
            anchors.bottomMargin: itemMargin
            color: "transparent"
            radius: itemRadius + border.width
            border.width: isCurrent ? 2 : 0
            border.color: Colours.palette.m3primary
            antialiasing: true
            smooth: true

            Behavior on border.width {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }

            MaterialIcon {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.small

                visible: isCurrent
                text: "check_circle"
                color: Colours.palette.m3primary
                iconPointSize: Tokens.font.size.large
            }
        }

        StyledText {
            id: filenameText

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Tokens.padding.normal + Tokens.spacing.normal / 2
            anchors.rightMargin: Tokens.padding.normal + Tokens.spacing.normal / 2
            anchors.bottomMargin: Tokens.padding.normal

            text: modelData.name
            textPointSize: Tokens.font.size.smaller
            font.weight: 400
            color: isCurrent ? Colours.palette.m3primary : Colours.palette.m3onSurface
            elide: Text.ElideMiddle
            maximumLineCount: 1
            horizontalAlignment: Text.AlignHCenter

            opacity: 0

            Component.onCompleted: {
                opacity = 1;
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 1000
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
