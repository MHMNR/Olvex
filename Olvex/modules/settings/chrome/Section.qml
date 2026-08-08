pragma ComponentBehavior: Bound


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
            color: root.accentColor
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
                color: root.accentColor
                textPointSize: Tokens.font.size.larger
            }

            StyledText {
                visible: !!root.description
                width: Math.min(implicitWidth, Math.max(120, root.width - Tokens.padding.smaller * 2 - (root.icon ? 36 : 0)))
                text: root.description
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                color: Qt.alpha(root.accentColor, 0.65)
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
