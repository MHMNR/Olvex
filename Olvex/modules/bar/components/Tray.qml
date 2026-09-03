import QtQuick
import QtQuick.Layouts
import Quickshell
import Olvex.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property alias layout: layout
    readonly property alias items: items
    readonly property alias expandBtn: expandBtn

    readonly property bool compactMode: Config.bar ? Config.bar.tray.compact : (GlobalConfig.bar.tray.compact ?? false)
    readonly property bool trayBackground: Config.bar ? Config.bar.tray.background : (GlobalConfig.bar.tray.background ?? false)

    readonly property int padding: trayBackground ? (compactMode ? 4 : 8) : 2
    readonly property int spacing: compactMode ? 4 : 6

    property var bar: null
    property var popouts: bar ? bar.popouts : null

    property bool expanded: !compactMode

    readonly property bool isAnyMenuOpen: {
        const p = root.popouts || (bar ? bar.popouts : null);
        return Boolean(p && p.hasCurrent && (p.currentName || "").startsWith("traymenu"));
    }

    Connections {
        target: root.popouts || (bar ? bar.popouts : null)
        function onHasCurrentChanged() {
            if (root.isAnyMenuOpen) {
                expandTimer.stop();
                collapseTimer.stop();
                root.expanded = true;
            } else if (root.compactMode && !trayHover.hovered) {
                collapseTimer.restart();
            }
        }
        function onCurrentNameChanged() {
            if (root.isAnyMenuOpen) {
                expandTimer.stop();
                collapseTimer.stop();
                root.expanded = true;
            }
        }
    }

    readonly property real collapsedSize: Tokens.sizes.bar.innerWidth
    readonly property real contentHeight: {
        if (!TrayService.hasItems) return 0;
        if (!compactMode) {
            return layout.implicitHeight + padding * 2;
        }
        return expanded ? (layout.implicitHeight + 28 + spacing + padding * 2) : collapsedSize;
    }

    clip: true
    visible: TrayService.hasItems

    implicitWidth: collapsedSize
    implicitHeight: contentHeight
    width: implicitWidth
    height: implicitHeight

    Layout.preferredWidth: width
    Layout.preferredHeight: height

    color: trayBackground ? Colours.tPalette.m3surfaceContainer : "transparent"
    radius: Tokens.rounding.full
    border.width: trayBackground ? 1 : 0
    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.14)

    Behavior on color {
        CAnim {}
    }

    Behavior on implicitHeight {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    HoverHandler {
        id: trayHover
        margin: 6

        onHoveredChanged: {
            if (hovered) {
                collapseTimer.stop();
                if (root.compactMode && !root.expanded) {
                    expandTimer.restart();
                }
            } else {
                expandTimer.stop();
                if (!Visibilities.areaPickerActive && root.compactMode && root.expanded && !root.isAnyMenuOpen) {
                    collapseTimer.restart();
                }
            }
        }
    }

    // Hover dwell filter: 50ms (zero perceptible lag, filters accidental swipes)
    Timer {
        id: expandTimer
        interval: 50
        onTriggered: {
            if (root.compactMode && trayHover.hovered) {
                root.expanded = true;
            }
        }
    }

    // Snappy collapse grace period (prompt response on mouse leave)
    Timer {
        id: collapseTimer
        interval: 120
        onTriggered: {
            if (!Visibilities.areaPickerActive && root.compactMode && !trayHover.hovered && !root.isAnyMenuOpen) {
                root.expanded = false;
            }
        }
    }

    onIsAnyMenuOpenChanged: {
        if (!Visibilities.areaPickerActive && !isAnyMenuOpen && root.compactMode && !trayHover.hovered) {
            collapseTimer.restart();
        }
    }

    function trayItemAtY(globalY) {
        if (!items || items.count === 0) return null;
        for (let i = 0; i < items.count; i++) {
            const itm = items.itemAt(i);
            if (!itm) continue;
            const pt = itm.mapFromItem(null, 0, globalY);
            if (pt.y >= 0 && pt.y <= itm.height) {
                return { item: itm, index: i };
            }
        }
        return null;
    }

    Column {
        id: layout

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: root.compactMode ? expandBtn.top : undefined
        anchors.bottomMargin: root.compactMode ? root.spacing : 0
        anchors.top: !root.compactMode ? parent.top : undefined
        anchors.topMargin: !root.compactMode ? root.padding : 0
        spacing: root.spacing
        z: 1

        opacity: (!root.compactMode || root.expanded) && TrayService.hasItems ? 1 : 0
        scale: (!root.compactMode || root.expanded) ? 1.0 : 0.88
        transformOrigin: Item.Bottom
        visible: TrayService.hasItems

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        Repeater {
            id: items
            model: TrayService.items

            TrayItem {
                required property int index
                itemIndex: index
                bar: root.bar
            }
        }
    }

    // Clean expand/collapse chevron toggle for compact mode
    Item {
        id: expandBtn
        visible: root.compactMode && TrayService.hasItems
        z: 2

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round((root.collapsedSize - height) / 2)

        width: 28
        height: 28

        property real btnScale: 1.0
        scale: btnScale

        SequentialAnimation {
            id: expandSpring
            NumberAnimation { target: expandBtn; property: "btnScale"; to: 0.90; duration: 60; easing.type: Easing.OutQuad }
            SpringAnimation { target: expandBtn; property: "btnScale"; to: 1.0; spring: 5.0; damping: 0.65 }
        }

        StateLayer {
            anchors.fill: parent
            radius: Tokens.rounding.full
            color: Colours.palette.m3onSurfaceVariant
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                expandTimer.stop();
                collapseTimer.stop();
                expandSpring.start();
                root.expanded = !root.expanded;
            }
        }

        Item {
            id: arrowWrapper
            anchors.centerIn: parent
            width: 20
            height: 20
            rotation: root.expanded ? 180 : 0

            Behavior on rotation {
                NumberAnimation {
                    duration: (Tokens && Tokens.anim && Tokens.anim.durations) ? Tokens.anim.durations.expressiveDefaultSpatial : 350
                    easing: (Tokens && Tokens.anim) ? Tokens.anim.expressiveDefaultSpatial : Easing.OutCubic
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: "expand_less"
                iconPointSize: 18
                color: Colours.light ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
            }
        }
    }
}



