
import "../../components"
import "../../components/controls"
import "../../components/containers"
import ".."
import QtQuick
import QtQuick.Layouts
import Quickshell
import Olvex.Config
import qs.components
import qs.services
import qs.modules.settings

Item {
    id: root

    required property ShellScreen screen
    required property Session session
    required property bool initialOpeningComplete

    implicitWidth: layout.implicitWidth + Tokens.padding.larger * 4
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2

    property Item hoveredItem: null

    Timer {
        id: clearHoverTimer
        interval: 75
        onTriggered: root.hoveredItem = null
    }

    // Sliding hover highlight marker
    StyledRect {
        id: hoverHighlight
        visible: opacity > 0.001
        opacity: (root.hoveredItem !== null && root.hoveredItem.parent && !root.hoveredItem.parent.active) ? 0.08 : 0
        color: Colours.palette.m3onSurface
        radius: Tokens.rounding.full
        z: 0

        x: root.hoveredItem ? root.hoveredItem.mapToItem(root, 0, 0).x : x
        y: root.hoveredItem ? root.hoveredItem.mapToItem(root, 0, 0).y : y
        width: root.hoveredItem ? root.hoveredItem.width : width
        height: root.hoveredItem ? root.hoveredItem.height : height

        Behavior on x {
            enabled: hoverHighlight.opacity > 0
            SpringAnimation {
                spring: 7.0
                damping: 0.8
                mass: 1.0
                epsilon: 0.005
            }
        }
        Behavior on y {
            enabled: hoverHighlight.opacity > 0
            SpringAnimation {
                spring: 7.0
                damping: 0.8
                mass: 1.0
                epsilon: 0.005
            }
        }
        Behavior on width {
            enabled: hoverHighlight.opacity > 0
            SpringAnimation {
                spring: 7.0
                damping: 0.8
                mass: 1.0
                epsilon: 0.005
            }
        }
        Behavior on height {
            enabled: hoverHighlight.opacity > 0
            SpringAnimation {
                spring: 7.0
                damping: 0.8
                mass: 1.0
                epsilon: 0.005
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tokens.padding.larger * 2
        spacing: Tokens.spacing.normal

        states: State {
            name: "expanded"
            when: root.session.navExpanded

            PropertyChanges {
                layout.spacing: root.Tokens.spacing.small
            }
        }

        transitions: Transition {
            Anim {
                properties: "spacing"
            }
        }

        Loader {
            Layout.topMargin: Tokens.spacing.large
            asynchronous: true
            active: !root.session.floating
            visible: active

            sourceComponent: StyledRect {
                readonly property int nonAnimWidth: normalWinIcon.implicitWidth + (root.session.navExpanded ? normalWinLabel.anchors.leftMargin + normalWinLabel.implicitWidth : 0) + normalWinIcon.anchors.leftMargin * 2

                implicitWidth: nonAnimWidth
                implicitHeight: root.session.navExpanded ? normalWinIcon.implicitHeight + Tokens.padding.normal * 2 : nonAnimWidth

                color: Colours.palette.m3primaryContainer
                radius: Tokens.rounding.small

                StateLayer {
                    id: normalWinState

                    onClicked: {
                        root.session.root.close();
                        WindowFactory.create(null, {
                            active: root.session.active,
                            navExpanded: root.session.navExpanded
                        });
                    }

                    color: Colours.palette.m3onPrimaryContainer
                }

                MaterialIcon {
                    id: normalWinIcon

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.padding.large

                    text: "select_window"
                    color: Colours.palette.m3onPrimaryContainer
                    iconPointSize: Tokens.font.size.large
                    fill: 1
                }

                StyledText {
                    id: normalWinLabel

                    anchors.left: normalWinIcon.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.spacing.normal

                    text: qsTr("Float window")
                    color: Colours.palette.m3onPrimaryContainer
                    opacity: root.session.navExpanded ? 1 : 0

                    Behavior on opacity {
                        Anim {
                            type: Anim.StandardSmall
                        }
                    }
                }

                Behavior on implicitWidth {
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }

                Behavior on implicitHeight {
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }
            }
        }

        Repeater {
            model: PaneRegistry.count

            NavItem {
                required property int index

                Layout.topMargin: index === 0 ? Tokens.spacing.large * 2 : 0
                icon: PaneRegistry.getByIndex(index).icon
                label: PaneRegistry.getByIndex(index).label
            }
        }
    }

    component NavItem: Item {
        id: item

        required property string icon
        required property string label
        readonly property bool active: root.session.active === label

        implicitWidth: background.implicitWidth
        implicitHeight: background.implicitHeight + smallLabel.implicitHeight + smallLabel.anchors.topMargin

        states: State {
            name: "expanded"
            when: root.session.navExpanded

            PropertyChanges {
                expandedLabel.opacity: 1
                smallLabel.opacity: 0
                background.implicitWidth: icon.implicitWidth + icon.anchors.leftMargin * 2 + expandedLabel.anchors.leftMargin + expandedLabel.implicitWidth
                background.implicitHeight: icon.implicitHeight + root.Tokens.padding.normal * 2
                item.implicitHeight: background.implicitHeight
            }
        }

        transitions: Transition {
            Anim {
                property: "opacity"
                type: Anim.StandardSmall
            }

            Anim {
                properties: "implicitWidth,implicitHeight"
                type: Anim.DefaultSpatial
            }
        }

        StyledRect {
            id: background

            radius: Tokens.rounding.full
            color: Qt.alpha(Colours.palette.m3secondaryContainer, item.active ? 1 : 0)

            implicitWidth: icon.implicitWidth + icon.anchors.leftMargin * 2
            implicitHeight: icon.implicitHeight + Tokens.padding.small

            StateLayer {
                showHoverBackground: false
                onEntered: {
                    clearHoverTimer.stop();
                    root.hoveredItem = background;
                }
                onExited: {
                    clearHoverTimer.restart();
                }
                onClicked: {
                    // Prevent tab switching during initial opening animation to avoid blank pages
                    if (!root.initialOpeningComplete) {
                        return;
                    }
                    root.session.active = item.label;
                }

                color: item.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
            }

            MaterialIcon {
                id: icon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.large

                text: item.icon
                color: item.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                iconPointSize: Tokens.font.size.large
                fill: item.active ? 1 : 0

                Behavior on fill {
                    Anim {}
                }
            }

            StyledText {
                id: expandedLabel

                anchors.left: icon.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.spacing.normal

                opacity: 0
                text: item.label
                color: item.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                font.capitalization: Font.Capitalize
            }

            StyledText {
                id: smallLabel

                anchors.horizontalCenter: icon.horizontalCenter
                anchors.top: icon.bottom
                anchors.topMargin: Tokens.spacing.small / 2

                text: item.label
                textPointSize: Tokens.font.size.small
                font.capitalization: Font.Capitalize
            }
        }
    }
}
