pragma ComponentBehavior: Bound

import QtQuick
import Olvex.Config
import qs.components
import qs.components.images
import qs.services

Item {
    id: root

    property bool compact: false
    property string glyphIcon: "folder"
    property string previewPath: ""
    property string badgeIcon: ""

    readonly property string displayGlyph: root.glyphIcon.length > 0 ? root.glyphIcon : "folder"
    readonly property real mainSize: root.width * (root.compact ? 0.7 : 0.76)
    readonly property real previewWidth: root.width * 0.62
    readonly property real badgeSize: root.width * 0.32
    readonly property bool hasPreview: root.previewPath.length > 0

    MaterialIcon {
        anchors.centerIn: parent
        text: root.displayGlyph
        fill: 1
        grade: 0
        color: Colours.palette.m3primary
        iconPointSize: root.mainSize
    }

    StyledClippingRect {
        anchors.centerIn: parent
        width: root.previewWidth
        height: root.previewWidth
        radius: Tokens.rounding.extraSmall
        clip: true
        visible: root.hasPreview
        z: 1
        color: Colours.palette.m3surfaceContainerHigh
        border.width: 1
        border.color: Colours.palette.m3surface

        CachingImage {
            anchors.fill: parent
            path: root.previewPath
        }
    }

    StyledClippingRect {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: parent.width * 0.02
        width: root.badgeSize
        height: width
        radius: Tokens.rounding.full
        visible: root.badgeIcon.length > 0
        z: 2
        color: Colours.palette.m3primaryContainer

        MaterialIcon {
            anchors.centerIn: parent
            text: root.badgeIcon
            fill: 1
            grade: 0
            color: Colours.palette.m3onPrimaryContainer
            iconPointSize: parent.width * 0.56
        }
    }
}