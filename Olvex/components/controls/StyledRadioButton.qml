import QtQuick
import QtQuick.Templates
import Olvex.Config
import qs.components
import qs.services

RadioButton {
    id: root
    font.pixelSize: Math.max(10, Math.round(Tokens.font.size.smaller * 96 / 72))

    implicitWidth: implicitIndicatorWidth + implicitContentWidth + contentItem.anchors.leftMargin
    implicitHeight: Math.max(implicitIndicatorHeight, implicitContentHeight)

    indicator: Rectangle {
        id: outerCircle

        implicitWidth: 20
        implicitHeight: 20
        radius: Tokens.rounding.full
        color: root.checked ? "transparent" : Colours.palette.m3surfaceContainerHighest
        border.color: root.checked ? Colours.palette.m3primary : Colours.palette.m3outline
        border.width: 1.5
        anchors.verticalCenter: parent.verticalCenter

        StateLayer {
            anchors.margins: -Tokens.padding.smaller
            color: root.checked ? Colours.palette.m3onSurface : Colours.palette.m3primary
            z: -1
            onClicked: root.click()
        }

        StyledRect {
            anchors.centerIn: parent
            implicitWidth: root.checked ? 10 : 0
            implicitHeight: root.checked ? 10 : 0

            radius: Tokens.rounding.full
            color: Colours.palette.m3primary
            
            Behavior on implicitWidth { Anim { type: Anim.FastSpatial } }
            Behavior on implicitHeight { Anim { type: Anim.FastSpatial } }
        }

        Behavior on border.color {
            CAnim {}
        }
    }

    contentItem: StyledText {
        text: root.text
        textPointSize: Tokens.font.size.smaller
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: outerCircle.right
        anchors.leftMargin: Tokens.spacing.smaller
    }
}
