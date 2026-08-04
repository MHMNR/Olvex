pragma ComponentBehavior: Bound

import QtQuick
import Olvex.Config
import qs.components
import qs.services

// Title/desc left, control right.
// Cursor rules:
//  · Title / description / row padding → always Arrow
//  · Control slot (switch/slider/…) → that control's own cursor
//  · Full-row hand only when clickable:true (and only over the text side)
Item {
    id: root

    property string title: ""
    property string description: ""
    property string icon: ""
    property bool clickable: false
    property bool divider: true

    default property alias control: controlHolder.data

    signal clicked

    implicitWidth: parent ? parent.width : 400
    implicitHeight: Math.max(56, textCol.implicitHeight + Tokens.padding.normal * 2)
    width: parent ? parent.width : implicitWidth

    MaterialIcon {
        id: iconItem

        visible: !!root.icon
        anchors.left: parent.left
        anchors.leftMargin: Tokens.padding.small
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        color: Colours.palette.m3onSurfaceVariant
        iconPointSize: Tokens.font.size.large
    }

    Column {
        id: textCol

        anchors.left: root.icon ? iconItem.right : parent.left
        anchors.leftMargin: root.icon ? Tokens.spacing.normal : Tokens.padding.small
        anchors.right: controlHolder.left
        anchors.rightMargin: Tokens.spacing.normal
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        StyledText {
            width: parent.width
            text: root.title
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            font.weight: 700
            font.letterSpacing: 0.0
            lineHeight: 1.25
            lineHeightMode: Text.ProportionalHeight
            color: Colours.palette.m3onSurface
            textPointSize: Tokens.font.size.normal
        }

        StyledText {
            width: parent.width
            visible: !!root.description
            text: root.description
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            color: Colours.palette.m3onSurfaceVariant
            font.weight: Font.Normal
            font.letterSpacing: 0.2
            lineHeight: 1.4
            lineHeightMode: Text.ProportionalHeight
            textPointSize: Tokens.font.size.small
        }
    }

    Item {
        id: controlHolder

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: Tokens.padding.small
        implicitWidth: Math.max(0, childrenRect.width)
        implicitHeight: Math.max(0, childrenRect.height)
        width: implicitWidth
        height: implicitHeight
        z: 3
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Tokens.padding.small
        anchors.rightMargin: Tokens.padding.small
        height: 1
        visible: root.divider
        color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)
    }

    MouseArea {
        id: arrowShield

        anchors.fill: parent
        anchors.rightMargin: controlHolder.width + Tokens.spacing.small
        z: 1
        visible: !root.clickable
        enabled: !root.clickable
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.ArrowCursor
    }

    Loader {
        anchors.fill: parent
        anchors.rightMargin: controlHolder.width + Tokens.spacing.small
        active: root.clickable
        z: 2
        sourceComponent: StateLayer {
            showHoverBackground: true
            showRipple: true
            onClicked: root.clicked()
        }
    }
}
