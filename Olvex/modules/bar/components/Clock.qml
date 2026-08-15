
import QtQuick
import Olvex.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property color accentColour: Colours.palette.m3primary
    readonly property color mutedColour: Colours.light ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: layout.implicitHeight + Tokens.padding.normal * 2

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    Column {
        id: layout

        anchors.centerIn: parent
        spacing: 0

        // Date
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter

            visible: Config.bar.clock.showDate

            horizontalAlignment: StyledText.AlignHCenter
            text: Time.format("ddd\nd")
            textPointSize: Tokens.font.size.small
            font.family: Tokens.font.family.sans
            font.letterSpacing: 0.4
            color: root.mutedColour
        }

        // Simple divider
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Config.bar.clock.showDate
            width: parent.width
            height: Tokens.spacing.normal
            
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.6
                height: 2
                radius: 1
                color: Qt.alpha(root.mutedColour, 0.4)
            }
        }

        // Time
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter

            animate: true
            horizontalAlignment: StyledText.AlignHCenter
            text: Time.format(GlobalConfig.services.useTwelveHourClock ? "hh\nmm\nA" : "hh\nmm")
            textPointSize: Tokens.font.size.normal
            font.family: Tokens.font.family.mono
            font.weight: Font.DemiBold
            color: Colours.palette.m3onSurface
        }
    }
}

