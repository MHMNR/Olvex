pragma ComponentBehavior: Bound

import QtQuick
import "../../../controlcenter"
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

    readonly property int minCellWidth: 200 + Tokens.spacing.normal
    readonly property int columnsCount: Math.max(1, Math.floor(width / minCellWidth))

    cellWidth: width / columnsCount
    cellHeight: 140 + Tokens.spacing.normal
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
                font.pointSize: Tokens.font.size.extraLarge * 2
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

        Component.onCompleted: {
            if (modelData?.isVideo && !modelData.thumbnailPath)
                Wallpapers.queueThumbnail(modelData.path, isCurrent);
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

            CachingImage {
                anchors.fill: parent
                path: modelData.isVideo ? (modelData.thumbnailPath || "") : modelData.path
                fillMode: Image.PreserveAspectCrop
                cache: true
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: modelData.isVideo
                text: "play_circle"
                color: Colours.palette.m3primary
                font.pointSize: Tokens.font.size.extraLarge * 2.5
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
            font.pointSize: Tokens.font.size.smaller
            font.weight: 500
            color: isCurrent ? Colours.palette.m3primary : Colours.palette.m3onSurface
            elide: Text.ElideMiddle
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
