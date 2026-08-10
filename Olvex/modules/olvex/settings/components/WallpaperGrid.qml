
import QtQuick
import "../../../settings"
import Olvex.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.images
import qs.services

GridView {
    id: root

    required property Session session
    property string mode: "static"
    // Fixed layout: 5 columns × 3 visible rows
    property int columnsCount: 5
    property int visibleRows: 3

    cellWidth: Math.max(1, width / columnsCount)
    // Keep tiles roughly 16:10 so 5-wide still reads as photos
    cellHeight: Math.max(88, Math.round(cellWidth * 0.62) + Tokens.spacing.small)
    implicitHeight: cellHeight * visibleRows

    model: mode === "live" ? Wallpapers.liveEntryObjects : Wallpapers.staticEntryObjects
    clip: true

    StyledScrollBar.vertical: StyledScrollBar {
        flickable: root
    }

    Loader {
        anchors.centerIn: parent
        active: root.count === 0
        z: 10

        sourceComponent: Column {
            spacing: Tokens.spacing.small

            MaterialIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.mode === "live" ? "video_library" : "wallpaper"
                color: Colours.palette.m3outline
                iconPointSize: Tokens.font.size.extraLarge * 2
            }

            StyledText {
                horizontalAlignment: Text.AlignHCenter
                text: root.mode === "live" ? qsTr("No live wallpapers found") : qsTr("No static wallpapers found")
                font.weight: 500
            }
        }
    }

    delegate: Item {
        required property var modelData
        required property int index
        readonly property bool isCurrent: modelData && modelData.path === Wallpapers.actualCurrent
        readonly property real itemMargin: Tokens.spacing.normal / 2
        readonly property real itemRadius: Tokens.rounding.normal

        width: root.cellWidth
        height: root.cellHeight

        // Live: ensure ffmpeg thumb is queued; rebind when map updates
        readonly property string imagePath: {
            const _ = Wallpapers.thumbnailUpdateCount;
            if (modelData?.isVideo || Wallpapers.isVideoPath(modelData?.path ?? ""))
                return Wallpapers.displayPathFor(modelData.path);
            return modelData?.path ?? "";
        }

        Component.onCompleted: {
            if (modelData?.isVideo || Wallpapers.isVideoPath(modelData?.path ?? ""))
                Wallpapers.queueThumbnail(modelData.path, isCurrent);
        }

        // If thumb arrives later, path binding updates via thumbnailUpdateCount
        Connections {
            target: Wallpapers
            function onThumbnailUpdateCountChanged(): void {
                if ((modelData?.isVideo || Wallpapers.isVideoPath(modelData?.path ?? "")) && !imagePath)
                    Wallpapers.queueThumbnail(modelData.path, isCurrent);
            }
        }

        StateLayer {
            anchors.fill: parent
            anchors.margins: itemMargin
            radius: itemRadius
            onClicked: Wallpapers.setWallpaper(modelData.path)
        }

        StyledClippingRect {
            anchors.fill: parent
            anchors.margins: itemMargin
            color: Colours.tPalette.m3surfaceContainer
            radius: itemRadius
            antialiasing: true

            // Prefer plain Image for live thumbs (jpg on disk) — more reliable than
            // CachingImage when path flips from "" → thumb after ffmpeg.
            Image {
                anchors.fill: parent
                source: {
                    const p = imagePath;
                    if (!p)
                        return "";
                    return p.startsWith("file:") ? p : ("file://" + p);
                }
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                antialiasing: true
                mipmap: true
                sourceSize: Qt.size(Math.max(1, Math.round(width * 2)), Math.max(1, Math.round(height * 2)))
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutQuad
                    }
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: !imagePath
                text: (modelData?.isVideo || Wallpapers.isVideoPath(modelData?.path ?? "")) ? "movie" : "image"
                color: Colours.palette.m3outline
                iconPointSize: Tokens.font.size.extraLarge
            }

            MaterialIcon {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Tokens.padding.small
                visible: modelData?.isVideo || Wallpapers.isVideoPath(modelData?.path ?? "")
                text: "play_circle"
                color: Qt.alpha(Colours.palette.m3onSurface, 0.9)
                iconPointSize: Tokens.font.size.large
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: itemMargin
            color: "transparent"
            radius: itemRadius + border.width
            border.width: isCurrent ? 2 : 0
            border.color: Colours.palette.m3primary
        }

        StyledText {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Tokens.padding.normal + Tokens.spacing.normal / 2
            anchors.rightMargin: Tokens.padding.normal + Tokens.spacing.normal / 2
            anchors.bottomMargin: Tokens.padding.normal
            text: modelData.name
            textPointSize: Tokens.font.size.smaller
            font.weight: 500
            color: isCurrent ? Colours.palette.m3primary : Colours.palette.m3onSurface
            elide: Text.ElideMiddle
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
