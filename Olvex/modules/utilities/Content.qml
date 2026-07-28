import "cards"
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Olvex.Config
import qs.components
import qs.modules.bar.popouts as BarPopouts
import qs.modules.sidebar as Sidebar
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

            StyledRect {
                id: notifWrapper

                Layout.fillWidth: true
                Layout.preferredHeight: notifDock.notifCount > 0 ? Math.min(300, notifDock.implicitHeight + Tokens.padding.large * 2) : 160
                visible: true
                clip: true

                color: Colours.tileSurface
                radius: Tokens.rounding.normal

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

                Behavior on Layout.preferredHeight {
                    Anim {}
                }
            }

            Record {
                props: root.props
                visibilities: root.visibilities
                z: 1
            }

            Toggles {
                props: root.props
                visibilities: root.visibilities
                popouts: root.popouts
                contentRoot: root
            }
        }

        layer.enabled: root.props.expansionActive !== ""
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.props.expansionActive !== "" ? root.props.expansionBgBlur : 0
            blurMax: 64

            Behavior on blur { Anim {} }
        }

        Behavior on opacity { Anim {} }
        opacity: root.props.expansionActive !== "" ? root.props.expansionBgOpacity : 1
    }

    ExpansionOverlay {
        id: expansionOverlay
        anchors.fill: parent
        props: root.props
        visibilities: root.visibilities
    }

    RecordingDeleteModal {
        props: root.props
        deformMatrix: root.deformMatrix
    }
}
