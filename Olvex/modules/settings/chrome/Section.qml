pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

// Carded settings group (demo Section look, real tokens/primitives).
Item {
    id: root

    property string title: ""
    property string description: ""
    property string icon: ""

    default property alias content: col.data

    implicitWidth: parent ? parent.width : 600
    implicitHeight: header.implicitHeight + col.implicitHeight + Tokens.spacing.normal
    Layout.fillWidth: true

    Row {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Tokens.padding.smaller
        spacing: Tokens.spacing.small

        MaterialIcon {
            anchors.verticalCenter: titleCol.verticalCenter
            visible: !!root.icon
            text: root.icon
            fill: 1
            color: Colours.palette.m3primary
            iconPointSize: Tokens.font.size.larger
        }

        Column {
            id: titleCol

            spacing: 3

            StyledText {
                text: root.title
                font.weight: 700
                font.letterSpacing: -0.25
                lineHeight: 1.2
                lineHeightMode: Text.ProportionalHeight
                color: Colours.palette.m3primary
                textPointSize: Tokens.font.size.larger
            }

            StyledText {
                visible: !!root.description
                width: Math.min(implicitWidth, Math.max(120, root.width - Tokens.padding.smaller * 2 - (root.icon ? 36 : 0)))
                text: root.description
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                color: Colours.palette.m3onSurfaceVariant
                font.weight: Font.Normal
                font.letterSpacing: 0.15
                lineHeight: 1.35
                lineHeightMode: Text.ProportionalHeight
                textPointSize: Tokens.font.size.small
            }
        }
    }

    Column {
        id: col

        anchors.top: header.bottom
        anchors.topMargin: Tokens.spacing.normal
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Tokens.padding.small
        spacing: 0
    }
}
