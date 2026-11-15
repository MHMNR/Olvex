
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import M3Shapes
import Olvex.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    required property Props props
    required property DrawerVisibilities visibilities
    readonly property int notifCount: Notifs.list.reduce((acc, n) => (n && !n.closed) ? acc + 1 : acc, 0)

    anchors.fill: parent
    implicitHeight: title.implicitHeight + clipRect.anchors.topMargin + (notifCount > 0 ? notifList.implicitHeight : emptyState.implicitHeight)
    anchors.margins: Tokens.padding.normal

    Component.onCompleted: Notifs.list.forEach(n => { if (n) n.popup = false; })

    Item {
        id: title

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Tokens.padding.small
        anchors.rightMargin: Tokens.padding.small
        anchors.topMargin: Tokens.padding.small / 2

        implicitHeight: Math.max(titleText.implicitHeight, 32)

        StyledText {
            id: titleText

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: clearBtn.left
            anchors.rightMargin: Tokens.spacing.small

            text: root.notifCount > 0
                ? (root.notifCount === 1 ? qsTr("1 notification") : qsTr("%1 notifications").arg(root.notifCount))
                : qsTr("Notifications")
            color: Colours.palette.m3onSurface
            textPointSize: Tokens.font.size.small
            font.weight: Font.Medium
            font.letterSpacing: 0.15
            elide: Text.ElideRight
        }

        StyledRect {
            id: clearBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: width / 2

            scale: root.notifCount > 0 ? 1 : 0.5
            opacity: root.notifCount > 0 ? 1 : 0
            visible: opacity > 0.01
            enabled: root.notifCount > 0

            color: Qt.alpha(Colours.palette.m3onSurface, clearHover.containsMouse ? 0.12 : 0.06)
            border.width: 0
            border.color: "transparent"

            Behavior on color {
                CAnim {}
            }

            Behavior on scale {
                Anim {
                    type: Anim.FastSpatial
                }
            }

            Behavior on opacity {
                Anim {
                    duration: Tokens.anim.durations.expressiveFastSpatial
                }
            }

            StateLayer {
                id: clearHover
                anchors.fill: parent
                radius: parent.width / 2
                color: Colours.palette.m3onSurface
                disabled: root.notifCount === 0
                onClicked: {
                    Notifs.clearAll();
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: "delete_sweep"
                color: Colours.palette.m3onSurface
                iconPointSize: Tokens.font.size.normal
            }
        }
    }

    Item {
        id: clipRect

        anchors.top: title.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: Tokens.spacing.small

        implicitHeight: notifCount > 0 ? notifList.implicitHeight : emptyState.implicitHeight
        clip: true

        Behavior on implicitHeight {
            Anim {
                type: Anim.StandardExtraLarge
            }
        }

        Loader {
            id: emptyState
            asynchronous: true
            anchors.centerIn: parent
            active: opacity > 0
            opacity: root.notifCount > 0 ? 0 : 1

            sourceComponent: ColumnLayout {
                spacing: Tokens.spacing.small

                MaterialShape {
                    Layout.alignment: Qt.AlignHCenter
                    implicitSize: 64
                    shape: MaterialShape.Cookie12Sided
                    color: Qt.alpha(Colours.palette.m3primary, 0.16)

                    Image {
                        anchors.centerIn: parent
                        source: Paths.absolutePath("root:/assets/bone.png")
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: 28
                        sourceSize.height: 28
                        width: 28
                        height: 28

                        layer.enabled: true
                        layer.effect: Colouriser {
                            colorizationColor: Colours.palette.m3primary
                        }
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("All caught up")
                    color: Colours.palette.m3onSurface
                    textPointSize: Tokens.font.size.normal
                    font.weight: Font.DemiBold
                }
            }

            Behavior on opacity {
                Anim {
                    type: Anim.StandardExtraLarge
                }
            }
        }

        StyledFlickable {
            id: view

            anchors.fill: parent
            fadeColor: Colours.tPalette.m3surfaceContainerLow

            flickableDirection: Flickable.VerticalFlick
            contentWidth: width
            contentHeight: notifList.implicitHeight

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: view
            }

            NotifDockList {
                id: notifList

                props: root.props
                visibilities: root.visibilities
                container: view
            }
        }
    }
}

