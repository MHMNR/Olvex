pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Olvex.Config
import qs.components
import qs.components.effects
import qs.services
import qs.modules.drawers

MouseArea {
    id: root

    enum Side {
        Top,
        Bottom,
        Left,
        Right
    }

    required property Item attachTo
    property int attachSideX: Menu.Right
    property int attachSideY: Menu.Bottom
    property int thisSideX: Menu.Right
    property int thisSideY: Menu.Top
    property real marginX
    property real marginY

    property list<MenuItem> items
    readonly property int itemCount: items ? items.length : 0
    property MenuItem active: itemCount > 0 ? items[0] : null
    property bool expanded
    property bool highlightActive: false
    property Item hoveredItem: null

    readonly property bool _isContextMenu: true

    onExpandedChanged: {
        if (!expanded) {
            hoveredItem = null;
        }
        if (expanded && parent) {
            for (let i = 0; i < parent.children.length; i++) {
                const child = parent.children[i];
                if (child !== root && child._isContextMenu) {
                    child.expanded = false;
                }
            }
        }
    }

    signal itemSelected(item: var)

    readonly property Item overlayParent: {
        const win = QsWindow.window;
        if (!win)
            return null;
        const contentWin = win as ContentWindow;
        if (contentWin?.interactionWrapper)
            return contentWin.interactionWrapper;
        return (win as QsWindow)?.contentItem ?? null;
    }

    parent: {
        return root.overlayParent;
    }
    anchors.fill: parent ?? undefined

    enabled: expanded
    onClicked: expanded = false

    opacity: expanded ? 1 : 0
    layer.enabled: opacity < 1

    Behavior on opacity {
        Anim {
            duration: Tokens.anim.durations.small
        }
    }

    TransformWatcher {
        id: watcher

        a: root.parent
        b: root.attachTo
    }

    Elevation {
        id: menu

        readonly property var m3Emphasized: [0.2, 0.0, 0.0, 1.0, 1, 1]

        x: {
            watcher.transform; // mapToItem is not reactive so this forces updates
            const item = root.attachTo;
            if (!item || !root.parent)
                return 0;
            let off = root.attachSideX === Menu.Left ? 0 : item.width;
            if (root.thisSideX === Menu.Right)
                off -= width;
            return item.mapToItem(root.parent, off, 0).x + root.marginX;
        }
        y: {
            watcher.transform; // mapToItem is not reactive so this forces updates
            const item = root.attachTo;
            if (!item || !root.parent)
                return 0;
            let off = root.attachSideY === Menu.Top ? 0 : item.height;
            if (root.thisSideY === Menu.Bottom)
                off -= height;
            return item.mapToItem(root.parent, 0, off).y + root.marginY;
        }

        Behavior on x {
            enabled: root.expanded
            NumberAnimation {
                duration: 250
                easing.type: Easing.BezierSpline
                easing.bezierCurve: menu.m3Emphasized
            }
        }

        Behavior on y {
            enabled: root.expanded
            NumberAnimation {
                duration: 250
                easing.type: Easing.BezierSpline
                easing.bezierCurve: menu.m3Emphasized
            }
        }

        radius: Tokens.rounding.normal
        level: 2

        implicitWidth: Math.max(200, column.implicitWidth + column.anchors.margins * 2)
        implicitHeight: column.implicitHeight + column.anchors.margins * 2

        transform: Scale {
            yScale: root.expanded ? 1 : 0.1
            origin.y: root.thisSideY === Menu.Bottom ? menu.height : 0

            Behavior on yScale {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
        }

        StyledRect {
            anchors.fill: parent
            radius: parent.radius
            color: Colours.palette.m3surfaceContainerLow

            // Sliding hover highlight marker
            StyledRect {
                id: hoverHighlight
                visible: root.hoveredItem !== null
                opacity: visible ? 0.08 : 0
                color: Colours.palette.m3onSurface
                radius: Tokens.rounding.small
                
                // Position it matching the hoveredItem
                x: root.hoveredItem ? root.hoveredItem.mapToItem(parent, 0, 0).x : 0
                y: root.hoveredItem ? root.hoveredItem.mapToItem(parent, 0, 0).y : 0
                width: root.hoveredItem ? root.hoveredItem.width : 0
                height: root.hoveredItem ? root.hoveredItem.height : 0

                Behavior on x {
                    enabled: hoverHighlight.opacity > 0
                    SpringAnimation { spring: 7.0; damping: 0.8; mass: 1.0; epsilon: 0.005 }
                }
                Behavior on y {
                    enabled: hoverHighlight.opacity > 0
                    SpringAnimation { spring: 7.0; damping: 0.8; mass: 1.0; epsilon: 0.005 }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }
            }

            ColumnLayout {
                id: column

                readonly property int menuItemCount: root.itemCount

                anchors.fill: parent
                anchors.margins: Tokens.padding.small
                spacing: 0

                Repeater {
                    id: repeater

                    model: root.items ?? []

                    StyledRect {
                        id: item

                        required property int index
                        required property MenuItem modelData
                        readonly property bool active: modelData != null && modelData === root.active

                        visible: modelData != null
                        Layout.fillWidth: true
                        implicitWidth: menuOptionRow.implicitWidth + Tokens.padding.normal * 2
                        implicitHeight: menuOptionRow.implicitHeight + Tokens.padding.normal * 2

                        radius: Tokens.rounding.small
                        topLeftRadius: Tokens.rounding.small
                        topRightRadius: Tokens.rounding.small
                        bottomLeftRadius: Tokens.rounding.small
                        bottomRightRadius: Tokens.rounding.small

                        color: Qt.alpha(Colours.palette.m3primary, (root.highlightActive && active) ? 0.12 : 0)

                        Behavior on radius {
                            Anim {}
                        }

                        StateLayer {
                            topLeftRadius: parent.topLeftRadius
                            topRightRadius: parent.topRightRadius
                            bottomLeftRadius: parent.bottomLeftRadius
                            bottomRightRadius: parent.bottomRightRadius

                            color: (root.highlightActive && item.active) ? Colours.palette.m3primary : Colours.palette.m3onSurface
                            disabled: !root.expanded
                            hoverEnabled: false
                            onClicked: {
                                if (!item.modelData)
                                    return;
                                root.itemSelected(item.modelData);
                                root.active = item.modelData;
                                item.modelData.clicked();
                                root.expanded = false;
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                            onEntered: {
                                if (root.expanded) {
                                    root.hoveredItem = item;
                                }
                            }
                            onExited: {
                                if (root.hoveredItem === item) {
                                    root.hoveredItem = null;
                                }
                            }
                        }

                        RowLayout {
                            id: menuOptionRow

                            anchors.fill: parent
                            anchors.margins: Tokens.padding.normal
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                Layout.alignment: Qt.AlignVCenter
                                text: item.modelData ? item.modelData.icon : ""
                                color: (root.highlightActive && item.active) ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                                text: item.modelData ? item.modelData.text : ""
                                horizontalAlignment: Text.AlignLeft
                                color: (root.highlightActive && item.active) ? Colours.palette.m3primary : Colours.palette.m3onSurface
                            }

                            Loader {
                                asynchronous: true
                                Layout.alignment: Qt.AlignVCenter
                                active: item.modelData && item.modelData.trailingIcon.length > 0
                                visible: active

                                sourceComponent: MaterialIcon {
                                    text: item.modelData ? item.modelData.trailingIcon : ""
                                    color: item.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
