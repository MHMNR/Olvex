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
    implicitHeight: header.implicitHeight + card.implicitHeight + Tokens.spacing.normal
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

            // title-medium — regular weight only
            StyledText {
                text: root.title
                font.weight: Font.Normal
                font.letterSpacing: 0.05
                lineHeight: 1.2
                lineHeightMode: Text.ProportionalHeight
                color: Colours.palette.m3onSurface
                textPointSize: Tokens.font.size.larger
            }

            // body-small supporting section blurb
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

    StyledRect {
        id: card

        anchors.top: header.bottom
        anchors.topMargin: Tokens.spacing.normal
        anchors.left: parent.left
        anchors.right: parent.right
        radius: Tokens.rounding.normal
        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
        implicitHeight: col.implicitHeight + Tokens.padding.large * 2
        // Don't clip — OptionPicker menus extend below the row
        clip: false

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.3)
        }

        Column {
            id: col

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Tokens.padding.large
            spacing: 0
        }
    }
}
