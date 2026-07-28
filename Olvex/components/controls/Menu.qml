pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Olvex.Config
import qs.components
import qs.components.containers
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
    // Cap popup height; content scrolls when items exceed this (font lists, etc.)
    property real maxHeight: 320
    // Only for font-family pickers — NEVER set item text as font.family otherwise
    // (broke recorder menu: text used as font face → blank/broken rows)
    property bool previewFontFace: false

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
            const rawX = item.mapToItem(root.parent, off, 0).x + root.marginX;
            const minX = 8;
            const maxX = Math.max(minX, root.parent.width - width - 8);
            return Math.max(minX, Math.min(rawX, maxX));
        }
        y: {
            watcher.transform; // mapToItem is not reactive so this forces updates
            const item = root.attachTo;
            if (!item || !root.parent)
                return 0;
            let off = root.attachSideY === Menu.Top ? 0 : item.height;
            if (root.thisSideY === Menu.Bottom)
                off -= height;
            const rawY = item.mapToItem(root.parent, 0, off).y + root.marginY;
            const minY = 8;
            const maxY = Math.max(minY, root.parent.height - height - 8);
            return Math.max(minY, Math.min(rawY, maxY));
        }

        radius: Tokens.rounding.normal
        level: 2

        readonly property real contentPad: Tokens.padding.small * 2
        readonly property real availableParentHeight: root.parent ? root.parent.height : 600
        readonly property real effectiveMaxHeight: Math.min(root.maxHeight, Math.max(120, availableParentHeight - 24))

        implicitWidth: Math.max(200, flickContent.implicitWidth + contentPad)
        // Scroll when list exceeds maxHeight or available parent space
        implicitHeight: Math.min(effectiveMaxHeight, flickContent.implicitHeight + contentPad)

        transform: Scale {
            yScale: root.expanded ? 1 : 0.05
            origin.y: root.thisSideY === Menu.Bottom ? menu.height : 0

            Behavior on yScale {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
        }

        // Same surface + marker language as Panels.qml taskbar context menu
        StyledRect {
            id: menuSurface

            anchors.fill: parent
            radius: parent.radius
            color: Colours.palette.m3surfaceContainerLow
            clip: true

            // Sliding hover highlight marker — copy of Panels contextMenuHoverHighlight
            StyledRect {
                id: hoverHighlight

                readonly property Item target: root.hoveredItem
                // Depend on scroll so mapToItem updates while flicking
                readonly property real _scroll: menuFlick.contentY

                z: 0
                visible: target !== null && root.expanded
                opacity: visible ? 0.08 : 0
                color: Colours.palette.m3onSurface
                radius: Tokens.rounding.small

                x: {
                    const _ = _scroll;
                    return target ? target.mapToItem(menuSurface, 0, 0).x : 0;
                }
                y: {
                    const _ = _scroll;
                    return target ? target.mapToItem(menuSurface, 0, 0).y : 0;
                }
                width: target ? target.width : 0
                height: target ? target.height : 0

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
                    NumberAnimation {
                        duration: 150
                    }
                }
            }

            StyledFlickable {
                id: menuFlick

                anchors.fill: parent
                anchors.margins: Tokens.padding.small
                z: 1
                contentWidth: width
                contentHeight: flickContent.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height + 1
                flickableDirection: Flickable.VerticalFlick
                edgeFades: false
                smoothWheel: true

                Column {
                    id: flickContent

                    width: menuFlick.width
                    spacing: 2

                    Repeater {
                        id: repeater

                        model: root.items ?? []

                        StyledRect {
                            id: item

                            required property int index
                            required property MenuItem modelData
                            readonly property bool active: modelData != null && modelData === root.active

                            visible: modelData != null
                            width: flickContent.width
                            implicitWidth: menuOptionRow.implicitWidth + Tokens.padding.normal * 2
                            implicitHeight: Math.max(40, menuOptionRow.implicitHeight + Tokens.padding.small * 2)
                            height: implicitHeight

                            // Active item gets primary background, otherwise transparent
                            radius: Tokens.rounding.small
                            color: item.active && root.highlightActive
                                ? Colours.palette.m3primary
                                : "transparent"

                            StateLayer {
                                id: itemState
                                anchors.fill: parent
                                radius: parent.radius
                                color: Colours.palette.m3onSurface
                                disabled: !root.expanded
                                // Hover tracked separately (same as Panels context menu)
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
                                    if (root.expanded)
                                        root.hoveredItem = item;
                                }
                                onExited: {
                                    if (root.hoveredItem === item)
                                        root.hoveredItem = null;
                                }
                            }

                            RowLayout {
                                id: menuOptionRow

                                anchors.fill: parent
                                anchors.leftMargin: Tokens.padding.normal
                                anchors.rightMargin: Tokens.padding.normal
                                spacing: Tokens.spacing.small

                                MaterialIcon {
                                    Layout.alignment: Qt.AlignVCenter
                                    visible: !!(item.modelData && item.modelData.icon && item.modelData.icon.length > 0)
                                    text: item.modelData ? item.modelData.icon : ""
                                    color: item.active && root.highlightActive
                                        ? Colours.palette.m3onPrimary
                                        : Colours.palette.m3onSurfaceVariant
                                    iconPointSize: Tokens.font.size.normal
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.fillWidth: true
                                    text: item.modelData ? item.modelData.text : ""
                                    horizontalAlignment: Text.AlignLeft
                                    elide: Text.ElideRight
                                    color: item.active && root.highlightActive
                                        ? Colours.palette.m3onPrimary
                                        : Colours.palette.m3onSurface
                                    textPointSize: Tokens.font.size.small
                                    font.family: root.previewFontFace && item.modelData?.text
                                        ? item.modelData.text
                                        : Tokens.font.family.sans
                                }

                                Loader {
                                    asynchronous: true
                                    Layout.alignment: Qt.AlignVCenter
                                    active: !!(item.modelData && item.modelData.trailingIcon && item.modelData.trailingIcon.length > 0)
                                    visible: active

                                    sourceComponent: MaterialIcon {
                                        text: item.modelData ? item.modelData.trailingIcon : ""
                                        color: Colours.palette.m3onSurfaceVariant
                                        iconPointSize: Tokens.font.size.normal
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
