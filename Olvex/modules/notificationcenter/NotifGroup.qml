
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Olvex.Config
import qs.components
import qs.components.effects
import qs.components.images
import qs.services
import qs.utils

StyledRect {
    id: root

    required property string modelData
    required property Props props
    required property Flickable container
    required property DrawerVisibilities visibilities

    readonly property list<var> notifs: Notifs.list.filter(n => n.appName === modelData)
    readonly property list<var> activeNotifs: notifs.filter(n => !n.closed)
    readonly property int notifCount: activeNotifs.length
    readonly property string image: activeNotifs.find(n => n.image.length > 0)?.image ?? ""
    readonly property string appIcon: activeNotifs.find(n => n.appIcon.length > 0)?.appIcon ?? ""
    readonly property int urgency: {
        if (activeNotifs.find(n => n.urgency === NotificationUrgency.Critical))
            return NotificationUrgency.Critical;
        if (activeNotifs.find(n => n.urgency === NotificationUrgency.Normal))
            return NotificationUrgency.Normal;
        return NotificationUrgency.Low;
    }

    readonly property color urgencyAccent: urgency === NotificationUrgency.Critical
        ? Colours.palette.m3error
        : urgency === NotificationUrgency.Low
            ? Colours.palette.m3onSurface
            : Colours.palette.m3onSecondaryContainer
    readonly property color urgencyOnAccent: urgency === NotificationUrgency.Critical
        ? Colours.palette.m3onError
        : urgency === NotificationUrgency.Low
            ? Colours.palette.m3surface
            : Colours.palette.m3secondaryContainer

    readonly property int nonAnimHeight: {
        const headerHeight = header.implicitHeight + (root.expanded ? Math.round(Tokens.spacing.small / 2) : 0);
        const columnHeight = headerHeight + notifList.layoutHeight;
        return Math.round(Math.max(avatarSize, columnHeight) + Tokens.padding.normal * 2);
    }
    readonly property bool expanded: props.expandedNotifs.includes(modelData)
    readonly property int avatarSize: 36

    function toggleExpand(expand: bool): void {
        if (expand) {
            if (!expanded)
                props.expandedNotifs.push(modelData);
        } else if (expanded) {
            props.expandedNotifs.splice(props.expandedNotifs.indexOf(modelData), 1);
        }
    }

    Component.onDestruction: {
        if (notifCount === 0 && expanded)
            props.expandedNotifs.splice(props.expandedNotifs.indexOf(modelData), 1);
    }

    anchors.left: parent?.left
    anchors.right: parent?.right
    implicitHeight: nonAnimHeight

    clip: true
    radius: Tokens.rounding.normal
    color: Colours.tileFill
    border.width: 0
    border.color: "transparent"

    Behavior on implicitHeight {
        Anim {
            type: Anim.Standard
        }
    }

    RowLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.padding.normal
        spacing: Tokens.spacing.small

        // ── App avatar ──
        Item {
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            Layout.preferredWidth: root.avatarSize
            Layout.preferredHeight: root.avatarSize
            implicitWidth: root.avatarSize
            implicitHeight: root.avatarSize

            // Analytical GPU SDF circle mask — borderless, matching NotificationPill
            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.smooth: true
                layer.effect: CircleMask {}

                Rectangle {
                    anchors.fill: parent
                    color: Colours.palette.m3surfaceContainerHighest
                }

                CachingIconImage {
                    anchors.fill: parent
                    source: root.image ? Qt.resolvedUrl(root.image) : Icons.getNotificationIcon(root.activeNotifs[0])
                }
            }

            Loader {
                asynchronous: true
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                active: root.appIcon && root.image

                sourceComponent: StyledRect {
                    implicitWidth: 16
                    implicitHeight: 16
                    color: root.urgencyAccent
                    radius: width / 2
                    border.width: 1.5
                    border.color: Colours.tileFill

                    ColouredIcon {
                        anchors.centerIn: parent
                        implicitSize: 10
                        source: Quickshell.iconPath(root.appIcon)
                        colour: root.urgencyOnAccent
                        layer.enabled: root.appIcon.endsWith("symbolic")
                    }
                }
            }
        }

        Column {
            id: column

            Layout.fillWidth: true
            spacing: root.expanded ? Math.round(Tokens.spacing.small / 2) : 2

            RowLayout {
                id: header

                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Tokens.spacing.smaller

                StyledText {
                    Layout.fillWidth: true
                    text: root.modelData
                    color: Colours.palette.m3onSurface
                    textPointSize: Tokens.font.size.small
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                StyledText {
                    animate: true
                    text: root.activeNotifs[0]?.timeStr ?? ""
                    color: Colours.palette.m3outline
                    textPointSize: Tokens.font.size.small
                    font.family: Tokens.font.family.mono
                    opacity: 0.9
                }

                // Expand / count chip
                StyledRect {
                    implicitWidth: expandBtn.implicitWidth + Tokens.padding.small * 2
                    implicitHeight: 24
                    color: root.urgency === NotificationUrgency.Critical
                        ? Colours.palette.m3error
                        : Qt.alpha(Colours.palette.m3onSurface, expandHover.containsMouse ? 0.12 : 0.07)
                    radius: height / 2
                    border.width: 0
                    border.color: "transparent"

                    Behavior on color {
                        CAnim {}
                    }

                    StateLayer {
                        id: expandHover
                        radius: parent.radius
                        color: root.urgency === NotificationUrgency.Critical
                            ? Colours.palette.m3onError
                            : Colours.palette.m3onSurface
                        onClicked: root.toggleExpand(!root.expanded)
                    }

                    RowLayout {
                        id: expandBtn

                        anchors.centerIn: parent
                        spacing: 2

                        StyledText {
                            id: groupCount

                            animate: true
                            text: root.notifCount
                            color: root.urgency === NotificationUrgency.Critical
                                ? Colours.palette.m3onError
                                : Colours.palette.m3onSurface
                            textPointSize: Tokens.font.size.small
                            font.weight: Font.Medium
                            font.family: Tokens.font.family.mono
                        }

                        MaterialIcon {
                            text: "expand_more"
                            color: root.urgency === NotificationUrgency.Critical
                                ? Colours.palette.m3onError
                                : Colours.palette.m3onSurfaceVariant
                            iconPointSize: Tokens.font.size.normal
                            rotation: root.expanded ? 180 : 0

                            Behavior on rotation {
                                Anim {
                                    type: Anim.DefaultSpatial
                                }
                            }
                        }
                    }
                }
            }

            NotifGroupList {
                id: notifList

                props: root.props
                notifs: root.notifs
                expanded: root.expanded
                container: root.container
                visibilities: root.visibilities
                onRequestToggleExpand: expand => root.toggleExpand(expand)
            }
        }
    }
}
