
import ".."
import "../chrome"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.services
import qs.utils

Item {
    id: root
    
    property Session session
    
    opacity: 0
    y: 10
    Component.onCompleted: cascadeIn.start()
    
    ParallelAnimation {
        id: cascadeIn
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens.anim.durations.slow; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens.anim.durations.slow; easing.type: Easing.OutCubic }
    }

    implicitHeight: heroItem.implicitHeight + Tokens.padding.large * 2
    
    Item {
        id: heroItem
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Tokens.padding.large
        anchors.rightMargin: Tokens.padding.large
        anchors.topMargin: Tokens.padding.large
        implicitHeight: 170

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.large
            color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

            // Flat tertiary tint (no gradient)
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Qt.alpha(Colours.palette.m3tertiary, 0.12)
            }

            Row {
                anchors.centerIn: parent
                spacing: Tokens.spacing.large

                Item {
                    id: logoContainer
                    width: 88
                    height: 88
                    anchors.verticalCenter: parent.verticalCenter

                    StyledRect {
                        anchors.fill: parent
                        radius: Tokens.rounding.large
                        color: Qt.alpha(Colours.palette.m3primary, logoHover.hovered ? 0.22 : 0.12)
                        border.color: Qt.alpha(Colours.palette.m3primary, logoHover.hovered ? 0.5 : 0.2)
                        border.width: 1

                        Behavior on color { CAnim {} }
                        Behavior on border.color { CAnim {} }
                    }

                    Image {
                        id: logoImg
                        anchors.centerIn: parent
                        width: 54
                        height: 54
                        source: Quickshell.shellPath("assets/images/olvex-mark.svg")
                        sourceSize: Qt.size(108, 108)
                        smooth: true
                        antialiasing: true

                        transform: [
                            Scale {
                                id: logoScale
                                origin.x: 27
                                origin.y: 27
                                xScale: 1.0
                                yScale: 1.0
                            },
                            Rotation {
                                id: logoRotate
                                origin.x: 27
                                origin.y: 27
                                angle: 0
                            }
                        ]
                    }

                    // Breathing floating loop
                    SequentialAnimation {
                        running: true
                        loops: Animation.Infinite

                        ParallelAnimation {
                            NumberAnimation { target: logoImg; property: "anchors.verticalCenterOffset"; to: -3; duration: 2200; easing.type: Easing.InOutSine }
                            NumberAnimation { target: logoScale; property: "xScale"; to: 1.06; duration: 2200; easing.type: Easing.InOutSine }
                            NumberAnimation { target: logoScale; property: "yScale"; to: 1.06; duration: 2200; easing.type: Easing.InOutSine }
                        }
                        ParallelAnimation {
                            NumberAnimation { target: logoImg; property: "anchors.verticalCenterOffset"; to: 3; duration: 2200; easing.type: Easing.InOutSine }
                            NumberAnimation { target: logoScale; property: "xScale"; to: 0.94; duration: 2200; easing.type: Easing.InOutSine }
                            NumberAnimation { target: logoScale; property: "yScale"; to: 0.94; duration: 2200; easing.type: Easing.InOutSine }
                        }
                    }

                    HoverHandler {
                        id: logoHover
                        onHoveredChanged: {
                            if (hovered) hoverSpin.restart();
                        }
                    }

                    NumberAnimation {
                        id: hoverSpin
                        target: logoRotate
                        property: "angle"
                        from: 0
                        to: 360
                        duration: 800
                        easing.type: Easing.OutBack
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            clickBounce.restart();
                        }
                    }

                    SequentialAnimation {
                        id: clickBounce
                        NumberAnimation { target: logoScale; property: "xScale"; to: 0.75; duration: 80; easing.type: Easing.OutCubic }
                        NumberAnimation { target: logoScale; property: "yScale"; to: 0.75; duration: 80; easing.type: Easing.OutCubic }
                        NumberAnimation { target: logoScale; property: "xScale"; to: 1.2; duration: 200; easing.type: Easing.OutBack }
                        NumberAnimation { target: logoScale; property: "yScale"; to: 1.2; duration: 200; easing.type: Easing.OutBack }
                        NumberAnimation { target: logoScale; property: "xScale"; to: 1.0; duration: 150; easing.type: Easing.OutCubic }
                        NumberAnimation { target: logoScale; property: "yScale"; to: 1.0; duration: 150; easing.type: Easing.OutCubic }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: "Olvex"
                        font.weight: Font.Normal
                        font.letterSpacing: -0.3
                        color: Colours.palette.m3onSurface
                        textPointSize: Tokens.font.size.extraLarge
                    }
                    StyledText {
                        text: qsTr("A Quickshell desktop for Hyprland")
                        color: Colours.palette.m3onSurfaceVariant
                        font.weight: Font.Normal
                        font.letterSpacing: 0.1
                        lineHeight: 1.35
                        lineHeightMode: Text.ProportionalHeight
                        textPointSize: Tokens.font.size.normal
                    }
                    StyledText {
                        text: qsTr("User: %1 · Shell: %2").arg(SysInfo.user || "—").arg(SysInfo.shell || "—")
                        color: Colours.palette.m3onSurfaceVariant
                        font.weight: Font.Normal
                        font.letterSpacing: 0.15
                        textPointSize: Tokens.font.size.small
                    }
                }
            }
        }
    }
}
