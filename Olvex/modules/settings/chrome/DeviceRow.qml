pragma ComponentBehavior: Bound

import QtQuick
import Olvex.Config
import qs.components
import qs.services

// Device list row for Wi‑Fi / BT / audio.
Item {
    id: root

    property string name: ""
    property string status: ""
    property string icon: "devices"
    property string trailing: ""
    property string trailingIcon: ""
    property bool active: false

    signal clicked

    implicitWidth: parent ? parent.width : 400
    implicitHeight: 60
    width: parent ? parent.width : implicitWidth

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.normal
        color: root.active ? Qt.alpha(Colours.palette.m3primary, 0.12) : "transparent"
    }

    MaterialIcon {
        id: leadIcon

        anchors.left: parent.left
        anchors.leftMargin: Tokens.padding.small
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        fill: root.active ? 1 : 0
        color: root.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        iconPointSize: Tokens.font.size.large
    }

    Column {
        anchors.left: leadIcon.right
        anchors.leftMargin: Tokens.spacing.normal
        anchors.right: trailCol.left
        anchors.rightMargin: Tokens.spacing.normal
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        StyledText {
            width: parent.width
            text: root.name
            elide: Text.ElideRight
            font.weight: Font.Normal
            font.letterSpacing: 0.05
            color: root.active ? Colours.palette.m3primary : Colours.palette.m3onSurface
            textPointSize: Tokens.font.size.normal
        }

        StyledText {
            width: parent.width
            visible: !!root.status
            text: root.status
            elide: Text.ElideRight
            color: Colours.palette.m3onSurfaceVariant
            font.weight: Font.Normal
            font.letterSpacing: 0.15
            textPointSize: Tokens.font.size.small
        }
    }

    Row {
        id: trailCol

        anchors.right: parent.right
        anchors.rightMargin: Tokens.padding.small
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.small

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !!root.trailing
            text: root.trailing
            color: Colours.palette.m3onSurfaceVariant
            font.weight: Font.Normal
            font.letterSpacing: 0.1
            textPointSize: Tokens.font.size.small
        }

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: !!root.trailingIcon
            text: root.trailingIcon
            color: Colours.palette.m3onSurfaceVariant
            iconPointSize: Tokens.font.size.normal
        }
    }

    StateLayer {
        anchors.fill: parent
        radius: Tokens.rounding.normal
        color: Colours.palette.m3primary
        onClicked: root.clicked()
    }
}
