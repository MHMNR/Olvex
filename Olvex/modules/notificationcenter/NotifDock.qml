
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
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
    readonly property int notifCount: Notifs.list.reduce((acc, n) => n.closed ? acc : acc + 1, 0)

    anchors.fill: parent
    implicitHeight: title.implicitHeight + clipRect.anchors.topMargin + (notifCount > 0 ? notifList.implicitHeight : emptyState.implicitHeight)
    anchors.margins: Tokens.padding.normal

    Component.onCompleted: Notifs.list.forEach(n => n.popup = false)

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
            anchors.right: clearBtnLoader.left
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

        Loader {
            id: clearBtnLoader
            asynchronous: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: active ? 32 : 0
            height: 32

            scale: root.notifCount > 0 ? 1 : 0.5
            opacity: root.notifCount > 0 ? 1 : 0
            active: opacity > 0

            sourceComponent: StyledRect {
                anchors.fill: parent
                radius: width / 2
                color: Qt.alpha(Colours.palette.m3onSurface, clearHover.containsMouse ? 0.12 : 0.06)
                border.width: 0
                border.color: "transparent"

                Behavior on color {
                    CAnim {}
                }

                StateLayer {
                    id: clearHover
                    radius: parent.width / 2
                    color: Colours.palette.m3onSurface
                    onClicked: clearTimer.start()
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "delete_sweep"
                    color: Colours.palette.m3onSurface
                    iconPointSize: Tokens.font.size.normal
                }
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

                StyledRect {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 48
                    implicitHeight: 48
                    radius: Tokens.rounding.normal
                    color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, Colours.light ? 0.8 : 0.45)

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "notifications_off"
                        color: Colours.palette.m3onSurfaceVariant
                        iconPointSize: Tokens.font.size.large
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("All clear")
                    color: Colours.palette.m3onSurface
                    textPointSize: Tokens.font.size.normal
                    font.weight: Font.DemiBold
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("New alerts land here")
                    color: Colours.palette.m3onSurfaceVariant
                    textPointSize: Tokens.font.size.small
                    opacity: 1.0
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

    Timer {
        id: clearTimer

        repeat: true
        triggeredOnStart: true
        interval: Math.max(15, Math.min(80, 69.8 - 12.3 * Math.log(Notifs.notClosed.length)))
        onTriggered: {
            const first = Notifs.notClosed[0];
            if (!first) {
                stop();
                return;
            }

            const appName = first.appName;
            let cleared = 0;
            for (const n of Notifs.notClosed.filter(n => n.appName === appName)) {
                n.close();
                cleared++;
                if (cleared > 30) {
                    interval = 5;
                    return;
                }
            }
        }
    }
}
