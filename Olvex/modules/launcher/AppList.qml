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
    required property var panels

    // Shared context menu state — single menu instance slides between items
    property DesktopEntry sharedMenuEntry: null
    property Item sharedMenuAttachTo: null
    property bool keyboardHighlightActive: false

    readonly property int appsRowHeight: 120
    readonly property int appsColumns: 5
    readonly property int appsVisibleRows: 4
    readonly property int appsPaneHeight: appsVisibleRows * appsRowHeight + 10

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
        keyboardHighlightActive = false;
        if (state === "scheme" || state === "variant")
            Schemes.reload();
    }

    property bool suspended: false

    // Reactive model — auto-updates on search text change
    readonly property var modelValues: {
        if (state === "apps") return Apps.search(search.text);
        if (state === "actions") return Actions.query(search.text);
        if (state === "calc") return [0];
        if (state === "scheme") return Schemes.query(search.text);
        if (state === "variant") return M3Variants.query(search.text);
        return [];
    }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            Apps.invalidateCatalog();
        }
    }

    readonly property int count: state === "apps" ? appGrid.count : actionList.count
    readonly property int currentIndex: state === "apps" ? appGrid.currentIndex : actionList.currentIndex
    readonly property var currentItem: state === "apps" ? appGrid.currentItem : actionList.currentItem

    function showKeyboardHighlight() {
        keyboardHighlightActive = true;
        appGrid.hoveredItem = null;
    }

    function showMouseHighlight(item: Item) {
        keyboardHighlightActive = false;
        appGrid.currentIndex = item.index;
        appGrid.hoveredItem = item;
    }

    function decrementCurrentIndex() {
        if (state === "apps") {
            showKeyboardHighlight();
            appGrid.currentIndex = Math.max(0, appGrid.currentIndex - appsColumns);
            Qt.callLater(scrollToCurrentItem);
        } else {
            actionList.decrementCurrentIndex();
        }
    }

    function incrementCurrentIndex() {
        if (state === "apps") {
            showKeyboardHighlight();
            appGrid.currentIndex = Math.min(appGrid.count - 1, appGrid.currentIndex + appsColumns);
            Qt.callLater(scrollToCurrentItem);
        } else {
            actionList.incrementCurrentIndex();
        }
    }

    function moveLeft() {
        if (state === "apps") {
            showKeyboardHighlight();
            appGrid.currentIndex = Math.max(0, appGrid.currentIndex - 1);
            Qt.callLater(scrollToCurrentItem);
        } else {
            actionList.decrementCurrentIndex();
        }
    }

    function moveRight() {
        if (state === "apps") {
            showKeyboardHighlight();
            appGrid.currentIndex = Math.min(appGrid.count - 1, appGrid.currentIndex + 1);
            Qt.callLater(scrollToCurrentItem);
        } else {
            actionList.incrementCurrentIndex();
        }
    }

    // Smoothly scroll grid so the keyboard-selected item is fully visible
    function scrollToCurrentItem() {
        const item = appGrid.currentItem;
        if (!item) return;
        const itemTop = item.y;                        // content-space Y
        const itemBot = itemTop + item.height;
        const visTop = appGrid.contentY;
        const visBot = visTop + appGrid.height;
        const maxScroll = Math.max(0, appGrid.contentHeight - appGrid.height);
        let target = -1;
        if (itemTop < visTop) {
            target = Math.max(0, itemTop - 4);
        } else if (itemBot > visBot) {
            target = Math.min(maxScroll, itemBot - appGrid.height + 4);
        }
        if (target < 0) return;
        smoothScrollAnim.stop();
        smoothScrollAnim.from = appGrid.contentY;
        smoothScrollAnim.to = target;
        smoothScrollAnim.start();
    }

    property int revealEpoch: 0
    property bool revealPending: false

    readonly property var m3Emphasized: [0.2, 0.0, 0.0, 1.0, 1, 1]

    function playOpenReveal() {
        if (root.state !== "apps" || !root.visibilities.launcher)
            return;
        jellySpring.stop();
        revealDelay.stop();
        revealPending = true;
        keyboardHighlightActive = false;
        scrollVelocity = 0;
        scrollJellyActive = false;
        revealDelay.restart();
    }

    property bool scrollJellyActive: false
    property real scrollVelocity: 0
    property real lastContentY: 0

    function bumpScrollVelocity(impulse) {
        if (!root.scrollJellyActive)
            return;
        scrollVelocity = Math.max(-72, Math.min(72, scrollVelocity + impulse));
        jellySpring.stop();
        jellySpring.from = scrollVelocity;
        jellySpring.to = 0;
        jellySpring.start();
    }

    function suspend() {
        smoothScrollAnim.stop();
        jellySpring.stop();
        revealDelay.stop();
        revealPending = false;
        keyboardHighlightActive = false;
        scrollVelocity = 0;
        scrollJellyActive = false;
        lastContentY = 0;
        appGrid.contentY = 0;
        appGrid.currentIndex = 0;
        actionList.currentIndex = 0;
    }

    function resume() {
        revealDelay.stop();
        revealPending = true;
        Qt.callLater(playOpenReveal);
    }

    Connections {
        target: visibilities
        function onLauncherChanged() {
            if (visibilities.launcher)
                resume();
            else {
                suspend();
                // Dismiss context menu when launcher closes
                sharedContextMenu.expanded = false;
            }
        }
    }

    NumberAnimation {
        id: smoothScrollAnim
        target: appGrid
        property: "contentY"
        duration: 260
        easing.type: Easing.OutCubic
    }

    Timer {
        id: revealDelay

        interval: 120
        repeat: false
        onTriggered: {
            root.revealPending = false;
            root.revealEpoch++;
        }
    }

    SpringAnimation {
        id: jellySpring
        target: root
        property: "scrollVelocity"
        to: 0
        spring: 3.4
        damping: 0.72
        epsilon: 0.04

        onStopped: root.scrollJellyActive = false
    }

    Connections {
        target: appGrid
        enabled: appGrid.visible
        ignoreUnknownSignals: true

        function onContentYChanged() {
            if (!root.scrollJellyActive)
                return;
            const dy = appGrid.contentY - root.lastContentY;
            root.lastContentY = appGrid.contentY;
            if (Math.abs(dy) < 0.05)
                return;
            root.bumpScrollVelocity(Math.max(-72, Math.min(72, dy * 5.0)));
        }

        function onMovementStarted() {
            root.scrollJellyActive = true;
        }

        function onFlickStarted() {
            root.scrollJellyActive = true;
        }
    }

    Component.onCompleted: {
        Apps.warmCatalog();
        // Initialize safe non-null default for sharedMenuAttachTo
        sharedMenuAttachTo = appGridHost;
    }

    implicitWidth: state === "apps" ? 590 : Tokens.sizes.launcher.itemWidth
    implicitHeight: {
        if (state === "apps")
            return appsPaneHeight;
        const maxShown = Config.launcher.maxShown ? Config.launcher.maxShown : 6;
        return (Tokens.sizes.launcher.itemHeight + 8) * Math.min(maxShown, count) - 8;
    }

    Item {
        id: appGridHost

        visible: root.state === "apps"
        width: 550
        height: root.appsPaneHeight - 8
        transformOrigin: Item.Bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 4
        clip: true

        // Sliding hover highlight behind GridView items
        StyledRect {
            id: gridHoverHighlight
            visible: appGrid.hoveredItem !== null && root.state === "apps"
            opacity: visible ? 1 : 0
            color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
            border.color: Qt.alpha(Colours.palette.m3onSurface, 0.12)
            border.width: 1
            radius: 16

            width: 102
            height: 112

            x: appGrid.hoveredItem ? appGrid.hoveredItem.x + 4 : x
            y: appGrid.hoveredItem ? appGrid.hoveredItem.y - appGrid.contentY + 4 : y

            Behavior on x {
                enabled: root.visibilities.launcher
                SpringAnimation { spring: 7.0; damping: 0.8; mass: 1.0; epsilon: 0.005 }
            }
            Behavior on y {
                enabled: root.visibilities.launcher
                SpringAnimation { spring: 7.0; damping: 0.8; mass: 1.0; epsilon: 0.005 }
            }
            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }
        }

        // Sliding keyboard-selection highlight
        StyledRect {
            id: keyboardHighlight

            visible: root.keyboardHighlightActive && appGrid.hoveredItem === null && appGrid.currentItem !== null && root.state === "apps"
            opacity: visible ? 1 : 0
            color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
            border.color: Qt.alpha(Colours.palette.m3onSurface, 0.12)
            border.width: 1
            radius: 16

            width: 102
            height: 112

            x: appGrid.currentItem ? appGrid.currentItem.x + 4 : x
            y: appGrid.currentItem ? appGrid.currentItem.y - appGrid.contentY + 4 : y

            Behavior on x {
                enabled: root.visibilities.launcher
                SpringAnimation { spring: 7.0; damping: 0.8; mass: 1.0; epsilon: 0.005 }
            }
            Behavior on y {
                enabled: root.visibilities.launcher
                SpringAnimation { spring: 7.0; damping: 0.8; mass: 1.0; epsilon: 0.005 }
            }
            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }
        }

        GridView {
            id: appGrid
            property Item hoveredItem: null

            anchors.fill: parent

            cellWidth: 110
            cellHeight: root.appsRowHeight
            cacheBuffer: root.appsRowHeight * 2
            reuseItems: true
            boundsBehavior: Flickable.DragAndOvershootBounds
            flickDeceleration: 2200
            maximumFlickVelocity: 3200

            model: root.state === "apps" ? root.modelValues : null
            delegate: gridAppItemComponent

            add: Transition {
                enabled: root.search.text.length > 0
                NumberAnimation {
                    properties: "opacity,scale"
                    from: 0.65
                    to: 1
                    duration: 160
                    easing.type: Easing.OutQuad
                }
            }

            remove: Transition {
                NumberAnimation {
                    properties: "opacity,scale"
                    from: 1
                    to: 0
                    duration: 150
                    easing.type: Easing.InQuad
                }
            }

            displaced: Transition {
                NumberAnimation {
                    properties: "x,y"
                    duration: 220
                    easing.type: Easing.OutBack
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                onWheel: event => {
                    const delta = event.angleDelta.y;
                    if (!delta)
                        return;

                    root.scrollJellyActive = true;
                    root.lastContentY = appGrid.contentY;

                    const maxScroll = Math.max(0, appGrid.contentHeight - appGrid.height);
                    const isDiscrete = Math.abs(delta) >= 120;
                    const direction = delta > 0 ? -1 : 1;
                    const step = isDiscrete ? root.appsRowHeight : Math.max(18, Math.abs(delta) * 0.65);
                    const currentY = smoothScrollAnim.running ? smoothScrollAnim.to : appGrid.contentY;
                    const rawTarget = currentY + direction * step;
                    const targetY = Math.max(0, Math.min(maxScroll, rawTarget));

                    if (isDiscrete) {
                        smoothScrollAnim.stop();
                        smoothScrollAnim.from = appGrid.contentY;
                        smoothScrollAnim.to = targetY;
                        smoothScrollAnim.start();
                    } else {
                        smoothScrollAnim.stop();
                        appGrid.contentY = targetY;
                    }

                    event.accepted = true;
                }
            }
        }
    }

    Component {
        id: gridAppItemComponent
        GridAppItem {
            visibilities: root.visibilities
            panels: root.panels
            gridView: appGrid
            revealEpoch: root.revealEpoch
            revealPending: root.revealPending
            scrollVelocity: root.scrollVelocity

            onMouseActivated: item => root.showMouseHighlight(item)

            onContextMenuRequested: (src) => {
                root.sharedMenuEntry = modelData;
                root.sharedMenuAttachTo = src;
                sharedContextMenu.expanded = true;
            }
        }
    }

    // Shared context menu — single instance that slides between items (Panels.qml pattern)
    Menu {
        id: sharedContextMenu

        // Safe null-fallback: appGridHost is forward ref but resolved before first use
        attachTo: root.sharedMenuAttachTo ?? root

        items: [
            MenuItem {
                text: qsTr("Open")
                icon: "rocket_launch"
                onClicked: {
                    if (root.sharedMenuEntry) {
                        Apps.launch(root.sharedMenuEntry);
                        root.visibilities.launcher = false;
                    }
                }
            },
            MenuItem {
                readonly property bool isPinned: {
                    if (!root.sharedMenuEntry) return false;
                    const pApps = root.visibilities.pinnedApps || [];
                    for (let i = 0; i < pApps.length; i++) {
                        if (pApps[i] === root.sharedMenuEntry.id) return true;
                    }
                    return false;
                }
                text: isPinned ? qsTr("Remove from Panel") : qsTr("Add to Panel")
                icon: isPinned ? "keep_off" : "push_pin"
                onClicked: {
                    if (!root.sharedMenuEntry) return;
                    const id = root.sharedMenuEntry.id;
                    const rawPinned = root.visibilities.pinnedApps || [];
                    const pinned = [];
                    for (let i = 0; i < rawPinned.length; i++) pinned.push(rawPinned[i]);
                    const idx = pinned.indexOf(id);
                    if (idx > -1) pinned.splice(idx, 1);
                    else pinned.push(id);
                    root.visibilities.pinnedApps = pinned;
                }
            }
        ]
    }

    StyledScrollBar {
        id: gridScrollBar
        flickable: appGrid
        anchors.right: appGridHost.right
        anchors.top: appGridHost.top
        anchors.bottom: appGridHost.bottom
        visible: appGridHost.visible && appGrid.contentHeight > appGrid.height
    }

    StyledListView {
        id: actionList

        visible: root.state !== "apps"
        anchors.fill: parent
        clip: true
        spacing: 8

        model: root.state !== "apps" ? root.modelValues : null

        delegate: {
            if (root.state === "actions") return actionItem;
            if (root.state === "calc") return calcItem;
            if (root.state === "scheme") return schemeItem;
            if (root.state === "variant") return variantItem;
            return null;
        }

        highlightFollowsCurrentItem: true
        highlight: StyledRect {
            radius: Tokens.rounding.normal
            color: Colours.palette.m3primary
            opacity: 1.0
        }

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: actionList
            visible: actionList.visible && actionList.contentHeight > actionList.height
        }
    }

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
