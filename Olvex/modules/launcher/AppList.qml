pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Olvex.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.launcher.items
import qs.modules.launcher.services

Item {
    id: root

    required property StyledTextField search
    required property DrawerVisibilities visibilities

    property bool suspended: false

    readonly property string state: {
        const text = search.text;
        const prefix = GlobalConfig.launcher.actionPrefix;
        if (text.startsWith(prefix)) {
            for (const action of ["calc", "scheme", "variant"])
                if (text.startsWith(`${prefix}${action} `))
                    return action;

            return "actions";
        }

        return "apps";
    }

    onStateChanged: {
        suspended = false;
        if (state === "scheme" || state === "variant")
            Schemes.reload();
    }

    // Dynamic reactive model values binding
    readonly property var modelValues: {
        if (state === "apps") return Apps.search(search.text);
        if (state === "actions") return Actions.query(search.text);
        if (state === "calc") return [0];
        if (state === "scheme") return Schemes.query(search.text);
        if (state === "variant") return M3Variants.query(search.text);
        return [];
    }

    readonly property int count: state === "apps" ? appGrid.count : actionList.count
    readonly property int currentIndex: state === "apps" ? appGrid.currentIndex : actionList.currentIndex
    readonly property var currentItem: state === "apps" ? appGrid.currentItem : actionList.currentItem

    function decrementCurrentIndex() {
        if (state === "apps") {
            appGrid.currentIndex = Math.max(0, appGrid.currentIndex - 5);
        } else {
            actionList.decrementCurrentIndex();
        }
    }

    function incrementCurrentIndex() {
        if (state === "apps") {
            appGrid.currentIndex = Math.min(appGrid.count - 1, appGrid.currentIndex + 5);
        } else {
            actionList.incrementCurrentIndex();
        }
    }

    function suspend(): void {
        suspended = true;
        decayTimer.stop();
        scrollSpeed = 0;
        appGrid.currentIndex = 0;
        actionList.currentIndex = 0;
    }

    // ── ELASTIC SCROLL PHYSICS TRACKING ──────────────────────────────────────
    property real scrollSpeed: 0
    property real lastContentY: 0

    // ── CASCADING SPRING CHAIN ROW OFFSETS ───────────────────────────────────
    property real row0Offset: -scrollSpeed * 0.75
    property real row1Offset: -scrollSpeed * 0.75
    property real row2Offset: -scrollSpeed * 0.75
    property real row3Offset: -scrollSpeed * 0.75
    property real row4Offset: -scrollSpeed * 0.75

    Behavior on row0Offset {
        SequentialAnimation {
            NumberAnimation { duration: 450; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
        }
    }
    Behavior on row1Offset {
        SequentialAnimation {
            PauseAnimation { duration: 30 } // Staggered delay!
            NumberAnimation { duration: 450; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
        }
    }
    Behavior on row2Offset {
        SequentialAnimation {
            PauseAnimation { duration: 60 } // Staggered delay!
            NumberAnimation { duration: 450; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
        }
    }
    Behavior on row3Offset {
        SequentialAnimation {
            PauseAnimation { duration: 90 } // Staggered delay!
            NumberAnimation { duration: 450; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
        }
    }
    Behavior on row4Offset {
        SequentialAnimation {
            PauseAnimation { duration: 120 } // Staggered delay!
            NumberAnimation { duration: 450; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
        }
    }

    Connections {
        target: appGrid
        enabled: appGrid.visible
        ignoreUnknownSignals: true
        function onContentYChanged() {
            const currentY = appGrid.contentY;
            const delta = currentY - lastContentY;
            // Amplify native scroll deltas (8.0x) so they produce highly visible spring offsets!
            scrollSpeed = Math.max(-120, Math.min(120, delta * 8.0));
            lastContentY = currentY;
            decayTimer.restart();
        }
    }

    Timer {
        id: decayTimer
        interval: 16
        repeat: true
        running: false
        onTriggered: {
            scrollSpeed = scrollSpeed * 0.90; // Slower decay for more elastic wobble recoil!
            if (Math.abs(scrollSpeed) < 0.1) {
                scrollSpeed = 0;
                stop();
            }
        }
    }

    implicitWidth: state === "apps" ? 590 : Tokens.sizes.launcher.itemWidth
    implicitHeight: {
        if (state === "apps") {
            const rows = Math.ceil(count / 5);
            const visibleRows = Math.max(1, Math.min(rows, 4)); // Show at least 1 row, max 4 rows
            return visibleRows * 120 + 10;
        } else {
            const maxShown = Config.launcher.maxShown ?? 6;
            return (Tokens.sizes.launcher.itemHeight + 8) * Math.min(maxShown, count) - 8;
        }
    }

    // ── GRID STYLE: Application Grid ────────────────────────────────────────
    GridView {
        id: appGrid

        visible: root.state === "apps"

        // Buttery-smooth discrete scroll animation
        NumberAnimation {
            id: smoothScrollAnim
            target: appGrid
            property: "contentY"
            duration: 280
            easing.type: Easing.OutCubic
        }

        // Next-level scroll handler: smooths mouse wheel scrolling, preserves trackpad responsiveness
        WheelHandler {
            id: smoothScrollHandler
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            function onWheel(event) {
                const delta = event.angleDelta.y;
                const isDiscrete = Math.abs(delta) >= 120;
                
                // 110px step matches the icon column height beautifully!
                const step = isDiscrete ? 110 : Math.abs(delta) * 1.2;
                const direction = delta > 0 ? -1 : 1;
                
                const maxScroll = Math.max(0, appGrid.contentHeight - appGrid.height);
                const currentTargetY = smoothScrollAnim.running ? smoothScrollAnim.to : appGrid.contentY;
                const targetY = Math.max(0, Math.min(maxScroll, currentTargetY + direction * step));
                
                if (isDiscrete) {
                    smoothScrollAnim.stop();
                    smoothScrollAnim.to = targetY;
                    smoothScrollAnim.start();
                } else {
                    appGrid.contentY = targetY;
                }
                
                // Spike scrollSpeed for immediate tactile spring wobble!
                root.scrollSpeed = Math.max(-120, Math.min(120, direction * 85));
                decayTimer.restart();
                
                event.accepted = true; // Block jumpy native scrolling!
            }
        }

        width: 550
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        clip: true

        boundsBehavior: Flickable.DragAndOvershootBounds // Super premium rubber-band edges!
        interactive: true

        cellWidth: 110
        cellHeight: 120

        model: !root.suspended && root.state === "apps" ? root.modelValues : null

        delegate: gridAppItemComponent

        // Skip view transitions during teardown to avoid incubator races.
        add: Transition {
            enabled: root.state === "apps"
            NumberAnimation { properties: "opacity,scale"; from: 0; to: 1; duration: 200; easing.type: Easing.OutBack }
        }
        remove: Transition {
            enabled: root.state === "apps"
            NumberAnimation { properties: "opacity,scale"; from: 1; to: 0; duration: 150; easing.type: Easing.InQuad }
        }
        displaced: Transition {
            enabled: root.state === "apps"
            NumberAnimation { properties: "x,y"; duration: 250; easing.type: Easing.OutBack }
        }
    }

    Component {
        id: gridAppItemComponent
        GridAppItem {
            visibilities: root.visibilities
            gridView: appGrid
            rowOffset: {
                const row = Math.floor(index / 5);
                if (row === 0) return root.row0Offset;
                if (row === 1) return root.row1Offset;
                if (row === 2) return root.row2Offset;
                if (row === 3) return root.row3Offset;
                return root.row4Offset;
            }
        }
    }

    StyledScrollBar {
        id: gridScrollBar
        flickable: appGrid
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        visible: appGrid.visible && appGrid.contentHeight > appGrid.height
    }

    // ── LIST STYLE: Fallback List for Actions / Calculations ──────────────────
    StyledListView {
        id: actionList

        visible: root.state !== "apps"
        anchors.fill: parent
        clip: true
        spacing: 8

        model: !root.suspended && root.state !== "apps" ? root.modelValues : null

        delegate: {
            if (root.state === "actions") return actionItem;
            if (root.state === "calc") return calcItem;
            if (root.state === "scheme") return schemeItem;
            if (root.state === "variant") return variantItem;
            return null;
        }

        highlightFollowsCurrentItem: false
        highlight: StyledRect {
            radius: Tokens.rounding.normal
            color: Colours.palette.m3onSurface
            opacity: 0.08

            y: actionList.currentItem?.y ?? 0
            implicitWidth: actionList.width
            implicitHeight: actionList.currentItem?.implicitHeight ?? 0

            Behavior on y {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
        }

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: actionList
            visible: actionList.visible && actionList.contentHeight > actionList.height
        }
    }

    // ── DELEGATES FOR FALLBACK LIST ──────────────────────────────────────────
    Component {
        id: actionItem
        ActionItem { list: actionList }
    }

    Component {
        id: calcItem
        CalcItem { list: actionList }
    }

    Component {
        id: schemeItem
        SchemeItem { list: actionList }
    }

    Component {
        id: variantItem
        VariantItem { list: actionList }
    }
}
