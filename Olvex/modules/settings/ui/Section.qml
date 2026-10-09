

import ".."
import "."
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.services

// Carded settings group — Section header + child SettingRows.
Item {
    id: root

    property string title: ""
    property string description: ""
    property string icon: ""
    // Per-section accent color — propagates to header icon/title and
    // description text. Defaults to m3primary; override for themed pages.
    property color accentColor: Colours.palette.m3primary
    property Item headerControl: null

    default property alias content: col.data

    implicitWidth: parent ? parent.width : 600
    implicitHeight: header.implicitHeight + col.implicitHeight + Tokens.spacing.normal
    Layout.fillWidth: true

    Item {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Tokens.padding.smaller
        anchors.rightMargin: Tokens.padding.smaller
        implicitHeight: Math.max(titleCol.implicitHeight, iconContainer.visible ? iconContainer.height : 0, headerControlHolder.visible ? headerControlHolder.height : 0)

        StyledRect {
            id: iconContainer
            visible: !!root.icon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 38
            height: 38
            radius: Tokens.rounding.normal
            color: Qt.alpha(root.accentColor, 0.12)

            MaterialIcon {
                anchors.centerIn: parent
                text: root.icon
                fill: 1
                color: root.accentColor
                iconPointSize: Tokens.font.size.large
            }
        }

        Column {
            id: titleCol

            anchors.left: iconContainer.visible ? iconContainer.right : parent.left
            anchors.leftMargin: iconContainer.visible ? Tokens.spacing.normal : 0
            anchors.right: headerControlHolder.visible ? headerControlHolder.left : parent.right
            anchors.rightMargin: headerControlHolder.visible ? Tokens.spacing.normal : 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StyledText {
                width: parent.width
                text: root.title
                font.weight: Font.DemiBold
                font.letterSpacing: -0.2
                lineHeight: 1.2
                lineHeightMode: Text.ProportionalHeight
                color: Colours.palette.m3onSurface
                textPointSize: Tokens.font.size.large
            }

            StyledText {
                visible: !!root.description
                width: parent.width
                text: root.description
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                color: Colours.palette.m3onSurfaceVariant
                font.weight: Font.Normal
                font.letterSpacing: 0.1
                lineHeight: 1.35
                lineHeightMode: Text.ProportionalHeight
                textPointSize: Tokens.font.size.small
            }
        }

        Item {
            id: headerControlHolder
            visible: !!root.headerControl
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: root.headerControl ? root.headerControl.implicitWidth : 0
            implicitHeight: root.headerControl ? root.headerControl.implicitHeight : 0
            data: root.headerControl ? [root.headerControl] : []
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
