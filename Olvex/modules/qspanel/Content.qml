import "cards"
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Olvex.Config
import qs.components
import qs.modules.bar.popouts as BarPopouts
import qs.modules.notificationcenter as Sidebar
import qs.services

Item {
    id: root

    required property var props
    required property DrawerVisibilities visibilities
    required property BarPopouts.Wrapper popouts
    required property matrix4x4 deformMatrix

    readonly property Sidebar.Props sidebarProps: Sidebar.Props {}

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    readonly property bool needsKeyboard: expansionOverlay.needsKeyboard

    Item {
        id: contentContainer
        anchors.fill: parent

        ColumnLayout {
            id: layout

            anchors.fill: parent
            spacing: Tokens.spacing.normal

            // Notification tile grows to fill free space above Record / Toggles
            StyledRect {
                id: notifWrapper

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 160
                visible: true
                clip: true

                color: Colours.tileSurface
                radius: (typeof Config !== "undefined" && Config && Config.border) ? Config.border.drawerRounding : Tokens.rounding.normal

                border.width: 1
                border.color: Colours.tileStroke

                StyledRect {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: parent.radius - 1
                    color: "transparent"
                    border.color: Colours.tileInnerLine
                    border.width: 1
                }

                Sidebar.NotifDock {
                    id: notifDock

                    props: root.sidebarProps
                    visibilities: root.visibilities

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                }
            }

            Record {
                Layout.fillWidth: true
                Layout.fillHeight: false
                props: root.props
                visibilities: root.visibilities
                z: 1
            }

            Toggles {
                Layout.fillWidth: true
                Layout.fillHeight: false
                props: root.props
                visibilities: root.visibilities
                popouts: root.popouts
                contentRoot: root
            }
        }
    }

    // M3 Container Transform Scrim: dims entire QS panel background (cards + gaps) behind expanded sheet
    Rectangle {
        id: expansionScrim
        anchors.fill: parent
        anchors.margins: -Tokens.padding.large
        radius: (typeof Config !== "undefined" && Config && Config.border) ? Config.border.drawerRounding : Tokens.rounding.normal
        color: Colours.palette.m3scrim
        opacity: root.props.expansionActive !== "" ? (Colours.light ? 0.42 : 0.62) : 0.0
        visible: opacity > 0.001
        z: 50

        Behavior on opacity {
            NumberAnimation {
                duration: root.props.expansionActive !== "" ? 500 : 400
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.05, 0, 0.133333, 0.06, 0.166666, 0.4, 0.208333, 0.82, 0.25, 1, 1, 1]
            }
        }
    }

    ExpansionOverlay {
        id: expansionOverlay
        anchors.fill: parent
        props: root.props
        visibilities: root.visibilities
        z: 60
    }

    RecordingDeleteModal {
        props: root.props
        deformMatrix: root.deformMatrix
    }
}
