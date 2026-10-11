import ".."
import "../ui"
import "."
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Olvex.Config
import qs.services

Item {
    id: root

    property Session session: null
    required property var sections
    property string activeSection: ""
    signal sectionSelected(string section)

    readonly property bool isCollapsed: width < 100

    property Item hoveredItem: null

    Timer {
        id: clearHoverTimer
        interval: 75
        onTriggered: root.hoveredItem = null
    }

    // Active tab sliding highlight pill
    StyledRect {
        id: highlightRect
        x: root.isCollapsed ? Math.round((root.width - 40) / 2) : Math.round(colLayout.x + Tokens.padding.small)
        width: root.isCollapsed ? 40 : Math.max(40, Math.round(colLayout.width - (Tokens.padding.small * 2)))
        height: 40
        radius: height / 2
        color: Colours.palette.m3primary
        z: 0

        Behavior on x {
            NumberAnimation {
                duration: Tokens.anim.durations.expressiveFastSpatial
                easing: Tokens.anim.expressiveFastSpatial
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: Tokens.anim.durations.expressiveFastSpatial
                easing: Tokens.anim.expressiveFastSpatial
            }
        }
        Behavior on y {
            Anim { type: Anim.FastSpatial }
        }
    }

    // Sliding hover highlight marker
    StyledRect {
        id: hoverHighlightRect
        z: 0
        visible: opacity > 0.001
        opacity: (root.hoveredItem !== null && !root.hoveredItem.isActive) ? (root.hoveredItem.isPressed ? 0.12 : 0.08) : 0
        color: Colours.palette.m3onSurface
        radius: height / 2

        x: root.isCollapsed ? Math.round((root.width - 40) / 2) : (root.hoveredItem ? root.hoveredItem.mapToItem(root, 0, 0).x : x)
        y: root.hoveredItem ? root.hoveredItem.mapToItem(root, 0, 0).y : y
        width: root.isCollapsed ? 40 : (root.hoveredItem ? root.hoveredItem.width : width)
        height: root.hoveredItem ? root.hoveredItem.height : height

        Behavior on x {
            enabled: hoverHighlightRect.opacity > 0
            SpringAnimation {
                spring: 7.0
                damping: 0.8
                mass: 1.0
                epsilon: 0.005
            }
        }
        Behavior on y {
            enabled: hoverHighlightRect.opacity > 0
            SpringAnimation {
                spring: 7.0
                damping: 0.8
                mass: 1.0
                epsilon: 0.005
            }
        }
        Behavior on width {
            enabled: hoverHighlightRect.opacity > 0
            SpringAnimation {
                spring: 7.0
                damping: 0.8
                mass: 1.0
                epsilon: 0.005
            }
        }
        Behavior on height {
            enabled: hoverHighlightRect.opacity > 0
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
        id: colLayout
        anchors.fill: parent
        anchors.margins: root.isCollapsed ? 0 : Tokens.padding.small
        spacing: Tokens.spacing.extraSmall

        Behavior on anchors.margins {
            NumberAnimation {
                duration: Tokens.anim.durations.expressiveDefaultSpatial
                easing: Tokens.anim.expressiveDefaultSpatial
            }
        }

        Repeater {
            model: root.sections

            delegate: Item {
                id: delegateRoot
                Layout.fillWidth: true
                implicitHeight: 40

                required property var modelData

                readonly property bool isActive: root.activeSection === delegateRoot.modelData.id
                readonly property bool isPressed: segMa.pressed

                onIsActiveChanged: {
                    if (isActive) {
                        highlightRect.y = Qt.binding(() => colLayout.y + delegateRoot.y);
                    }
                }
                Component.onCompleted: {
                    if (isActive) {
                        highlightRect.y = Qt.binding(() => colLayout.y + delegateRoot.y);
                    }
                }

                Item {
                    anchors.fill: parent
                    clip: true

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: root.isCollapsed ? 0 : Tokens.padding.large
                        anchors.rightMargin: root.isCollapsed ? 0 : Tokens.padding.large
                        spacing: root.isCollapsed ? 0 : Tokens.spacing.normal

                        Item {
                            Layout.preferredWidth: root.isCollapsed ? parent.width : 24
                            Layout.preferredHeight: 24
                            Layout.alignment: Qt.AlignVCenter | (root.isCollapsed ? Qt.AlignHCenter : Qt.AlignLeft)

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: delegateRoot.modelData.icon ?? ""
                                color: delegateRoot.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                iconPointSize: Tokens.font.size.normal
                                Behavior on color { CAnim {} }
                            }
                        }

                        StyledText {
                            text: delegateRoot.modelData.label ?? ""
                            color: delegateRoot.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                            font.weight: delegateRoot.isActive ? Font.Medium : Font.Normal
                            textPointSize: Tokens.font.size.normal
                            Layout.fillWidth: true
                            visible: !root.isCollapsed
                            opacity: root.isCollapsed ? 0 : 1
                            elide: Text.ElideRight
                            Behavior on color { CAnim {} }
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
                        }
                    }
                }

                MouseArea {
                    id: segMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        clearHoverTimer.stop();
                        root.hoveredItem = delegateRoot;
                    }
                    onExited: {
                        clearHoverTimer.restart();
                    }
                    onClicked: root.sectionSelected(delegateRoot.modelData.id)
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }

    // Floating Tooltip when collapsed
    Item {
        id: floatTooltip
        z: 300
        visible: root.isCollapsed && root.hoveredItem !== null
        opacity: (root.isCollapsed && root.hoveredItem !== null) ? 1.0 : 0.0
        x: root.width + Tokens.spacing.normal
        y: root.hoveredItem ? root.hoveredItem.mapToItem(root, 0, 0).y + Math.round((root.hoveredItem.height - height) / 2) : 0

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }
        Behavior on y {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        StyledRect {
            id: tooltipBg
            anchors.fill: parent
            radius: Tokens.rounding.small
            color: Colours.palette.m3surfaceContainerHighest
            border.width: 0
            border.color: "transparent"

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Colours.palette.m3shadow
                shadowOpacity: 0.35
                shadowBlur: 0.3
            }
        }

        StyledText {
            id: tooltipText
            anchors.centerIn: parent
            anchors.leftMargin: Tokens.padding.normal
            anchors.rightMargin: Tokens.padding.normal
            text: (root.hoveredItem && root.hoveredItem.modelData) ? (root.hoveredItem.modelData.label ?? "") : ""
            color: Colours.palette.m3onSurface
            font.weight: Font.Medium
            textPointSize: Tokens.font.size.small
        }

        implicitWidth: Math.max(48, tooltipText.implicitWidth + (Tokens.padding.normal * 2))
        implicitHeight: 32
    }
}
