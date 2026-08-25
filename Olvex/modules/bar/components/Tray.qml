import QtQuick
import QtQuick.Layouts
import Quickshell
import Olvex.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property alias layout: layout
    readonly property alias items: items
    readonly property alias expandBtn: expandBtn
    readonly property alias expandIcon: expandBtn

    readonly property int padding: Config.bar.tray.background ? Tokens.padding.normal : Tokens.padding.small
    readonly property int spacing: Config.bar.tray.background ? Tokens.spacing.small : 4

    property var bar: null

    property bool expanded: !Config.bar.tray.compact

    readonly property real collapsedSize: Tokens.sizes.bar.innerWidth
    readonly property real contentHeight: {
        if (!TrayService.hasItems) return 0;
        if (!Config.bar.tray.compact) {
            return layout.implicitHeight + padding * 2;
        }
        return expanded ? (layout.implicitHeight + 32 + spacing + padding * 2) : collapsedSize;
    }

    clip: true
    visible: TrayService.hasItems

    implicitWidth: collapsedSize
    implicitHeight: contentHeight
    width: implicitWidth
    height: implicitHeight

    Layout.preferredWidth: width
    Layout.preferredHeight: height

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, (Config.bar.tray.background && TrayService.hasItems) ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: width / 2
    border.width: 1
    border.color: hoverArea.containsMouse ? Qt.alpha(Colours.palette.m3primary, 0.35) : Qt.alpha(Colours.palette.m3outlineVariant, 0.12)
    scale: hoverArea.containsMouse ? 1.03 : 1.0

    Behavior on scale {
        Anim {
            type: Anim.FastSpatial
        }
    }

    Behavior on border.color {
        CAnim {}
    }

    Behavior on implicitHeight {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on height {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    Column {
        id: layout

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.padding
        spacing: Tokens.spacing.small

        opacity: (!Config.bar.tray.compact || root.expanded) && TrayService.hasItems ? 1 : 0
        visible: opacity > 0.01

        add: Transition {
            Anim {
                properties: "scale"
                from: 0
                to: 1
                easing: Tokens.anim.standardDecel
            }
        }

        move: Transition {
            Anim {
                properties: "scale"
                to: 1
                easing: Tokens.anim.standardDecel
            }
            Anim {
                properties: "x,y"
            }
        }

        Repeater {
            id: items
            model: TrayService.items

            TrayItem {
                required property int index
                itemIndex: index
                bar: root.bar
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }
    }

    Item {
        id: expandBtn
        visible: Config.bar.tray.compact && TrayService.hasItems

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: root.expanded ? parent.bottom : undefined
        anchors.bottomMargin: root.expanded ? root.padding : 0
        anchors.centerIn: !root.expanded ? parent : undefined

        width: root.expanded ? 32 : root.collapsedSize
        height: root.expanded ? 32 : root.collapsedSize

        property real btnScale: 1.0
        scale: btnScale

        SequentialAnimation {
            id: expandSpring
            NumberAnimation { target: expandBtn; property: "btnScale"; to: 0.88; duration: 80; easing.type: Easing.OutQuad }
            NumberAnimation { target: expandBtn; property: "btnScale"; to: 1.0; duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
        }

        StateLayer {
            anchors.fill: parent
            radius: width / 2
            color: Colours.palette.m3onSurfaceVariant
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                expandSpring.start();
                root.expanded = !root.expanded;
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: "expand_less"
            iconPointSize: Tokens.font.size.large
            color: Colours.palette.m3onSurfaceVariant
            rotation: root.expanded ? 180 : 0

            Behavior on rotation {
                Anim {
                    type: Anim.FastSpatial
                }
            }
        }
    }
}
