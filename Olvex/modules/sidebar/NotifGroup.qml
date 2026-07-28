pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Olvex.Config
import qs.components
import qs.components.effects
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
            ? Colours.palette.m3surfaceContainerHighest
            : Colours.palette.m3secondaryContainer
    readonly property color urgencyOnAccent: urgency === NotificationUrgency.Critical
        ? Colours.palette.m3onError
        : urgency === NotificationUrgency.Low
            ? Colours.palette.m3onSurface
            : Colours.palette.m3onSecondaryContainer

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
    radius: Tokens.rounding.large
    color: Colours.tileSurface
    border.width: 1
    border.color: Colours.tileStrokeSubtle

    // Soft inner rim — single subtle pass, not heavy double frame
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius - 1
        color: "transparent"
        border.width: 1
        border.color: Colours.tileInnerLine
        z: 0
    }

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
            implicitWidth: root.avatarSize
            implicitHeight: root.avatarSize

            Component {
                id: imageComp

                Image {
                    source: Qt.resolvedUrl(root.image)
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: root.avatarSize
                    sourceSize.height: root.avatarSize
                    cache: false
                    asynchronous: true
                    width: root.avatarSize
                    height: root.avatarSize
                }
            }

            Component {
                id: appIconComp

                ColouredIcon {
                    implicitSize: Math.round(root.avatarSize * 0.52)
                    source: Quickshell.iconPath(root.appIcon)
                    colour: root.urgencyOnAccent
                    layer.enabled: root.appIcon.endsWith("symbolic")
                }
            }

            Component {
                id: materialIconComp

                MaterialIcon {
                    text: Icons.getNotifIcon(root.activeNotifs[0]?.summary, root.urgency)
                    color: root.urgencyOnAccent
                    iconPointSize: Tokens.font.size.normal
                }
            }

            StyledClippingRect {
                anchors.fill: parent
                color: root.urgencyAccent
                radius: Tokens.rounding.full

                Loader {
                    asynchronous: true
                    anchors.centerIn: parent
                    sourceComponent: root.image ? imageComp : root.appIcon ? appIconComp : materialIconComp
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
                    radius: Tokens.rounding.full
                    border.width: 1.5
                    border.color: Colours.tileSurface

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
                    radius: Tokens.rounding.full
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
