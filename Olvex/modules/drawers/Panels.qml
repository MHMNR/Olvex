import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QCtls
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Hyprland
import Olvex.Config
import Olvex.Services
import qs.components
import qs.components.effects
import qs.components.controls as Controls
import qs.services
import qs.modules.bar as Bar
import qs.modules.dashboard as Dashboard
import qs.modules.launcher as Launcher
import qs.modules.notifications as Notifications
import qs.modules.flyouts as Osd
import qs.modules.powermenu as Session
import qs.modules.qspanel as Utilities
import qs.modules.bar.popouts as BarPopouts
import qs.modules.qspanel.toasts as Toasts
import Quickshell.Widgets
import qs.modules.launcher.services as LauncherServices
import qs.modules.clipboard as Clipboard
import qs.utils

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property Bar.BarWrapper bar
    required property real borderThickness
    required property var safeBorder
    property Item flyoutsScreenCapture: null

    readonly property alias flyouts: flyouts
    readonly property alias flyoutsWrapper: flyoutsWrapper
    readonly property alias notifications: notifications
    readonly property alias powermenu: powermenu
    readonly property alias powermenuWrapper: powermenuWrapper
    readonly property alias launcher: launcher
    readonly property alias wallpaperSelector: wallpaperSelector
    readonly property alias dashboard: dashboard
    readonly property alias popouts: popoutsWrapper.content
    readonly property alias popoutsWrapper: popoutsWrapper
    readonly property alias qspanel: qspanel
    readonly property alias toasts: toasts
    readonly property alias bottomPanel: bottomPanel

    readonly property alias pinnedLayout: layout

    // App launch morph — set by ContentWindow after creation
    property var appLaunchMorph: null

    readonly property bool powermenuVisible: powermenu.visible

    // Focus to receive key events
    focus: true
    Keys.onEscapePressed: {
        if (contextMenuVisible) {
            hideContextMenu();
            event.accepted = true;
        } else if (visibilities.wallpaperLauncher) {
            visibilities.wallpaperLauncher = false;
            event.accepted = true;
        } else if (visibilities.launcher) {
            visibilities.launcher = false;
            event.accepted = true;
        } else if (visibilities.dashboard) {
            visibilities.dashboard = false;
            event.accepted = true;
        } else if (visibilities.qspanel) {
            visibilities.qspanel = false;
            event.accepted = true;
        } else if (visibilities.clipboard) {
            visibilities.clipboard = false;
            event.accepted = true;
        } else if (visibilities.notificationcenter) {
            visibilities.notificationcenter = false;
            event.accepted = true;
        } else if (visibilities.powermenu) {
            visibilities.powermenu = false;
            event.accepted = true;
        } else if (popoutsWrapper.content.hasCurrent) {
            popoutsWrapper.content.hasCurrent = false;
            bar.closeTray();
            event.accepted = true;
        }
    }

    // Expand bottom margin to 80px whenever panel is visible (any mode)
    // so the border blob expands and panel sits inside it. Only always mode
    // sets exclusiveZone=80 to push windows.
    property real bottomMargin: {
        const baseMargin = borderThickness + (safeBorder.floating ? 5 : 0);
        if (bottomPanelVisible)
            return 80 + (safeBorder.floating ? 5 : 0);
        return baseMargin;
    }

    // Bottom panel config
    readonly property bool bottomPanelEnabled: Config.bar.bottomPanel && Config.bar.bottomPanel.enabled !== undefined ? Config.bar.bottomPanel.enabled : true
    readonly property string bottomPanelMode: Config.bar.bottomPanel && Config.bar.bottomPanel.visibilityMode ? Config.bar.bottomPanel.visibilityMode : "always"

    property bool hasWindowsOverlappingPanel: false
    property bool _lastOverlapState: false
    property int _geometryStableTicks: 0
    property int geometryPollInterval: 1000

    // Context menu state - for root-level popup menu
    property string contextMenuAppId: ""
    property bool contextMenuVisible: false
    property real contextMenuX: 0
    property real contextMenuY: 0
    property var contextMenuWindows: []  // List of running windows for this app
    property Item contextMenuHoveredItem: null
    readonly property int contextMenuWidth: 240
    readonly property int contextMenuRowHeight: 40
    readonly property int contextMenuIconCell: 20
    readonly property int contextMenuCloseCell: 24

    function showContextMenu(appId, sourceItem) {
        // If same menu already open, toggle close
        if (contextMenuVisible && contextMenuAppId === appId) {
            hideContextMenu();
            return;
        }

        // Cancel any pending fade-out timer to allow smooth morphing
        menuFadeOutTimer.stop();

        // Collect all windows for this app
        const toplevels = Hypr.toplevels?.values ?? [];
        const windows = [];
        for (let i = 0; i < toplevels.length; i++) {
            const ipc = toplevels[i].lastIpcObject;
            if (ipc && ipc.class === appId) {
                windows.push({
                    title: ipc.title || "Untitled",
                    address: normalizeAddress(ipc.address),
                    workspaceId: ipc.workspace?.id ?? 1
                });
            }
        }

        // Position menu centered horizontally on the icon, above the panel
        const pos = sourceItem.mapToItem(bottomPanel, 0, 0);
        const menuW = root.contextMenuWidth;
        let mx = pos.x + sourceItem.width / 2 - menuW / 2;

        // Horizontal bounds checking
        const panelWidth = bottomPanel.width;
        const minMargin = 8;
        if (mx < minMargin) {
            mx = minMargin;
        } else if (mx + menuW > panelWidth - minMargin) {
            mx = panelWidth - menuW - minMargin;
        }

        // Y will be calculated dynamically in menuContainer based on its height
        contextMenuX = mx;
        contextMenuY = 0;  // Not used, will calculate in binding
        contextMenuWindows = windows;
        contextMenuAppId = appId;
        contextMenuVisible = true;
    }

    function hideContextMenu() {
        contextMenuVisible = false;
        contextMenuHoveredItem = null;
        // Delay clearing the data so animation can complete
        menuFadeOutTimer.restart();
    }

    function normalizeAddress(addr) {
        if (!addr)
            return "";
        const str = String(addr);
        return str.startsWith("0x") ? str : "0x" + str;
    }

    // Resolve entry from appId at action time — never store the live object
    function contextMenuEntry() {
        if (!contextMenuAppId)
            return undefined;
        const apps = DesktopEntries.applications.values;
        for (let i = 0; i < apps.length; i++) {
            if (apps[i].id === contextMenuAppId)
                return apps[i];
        }
        return undefined;
    }

    // Trigger app launch morph: flying icon from launcher to pinned dock slot
    function triggerAppMorph(appId, iconSource, sx, sy, sw, sh) {
        if (!root.appLaunchMorph)
            return;
        root.appLaunchMorph.trigger(appId, iconSource, {
            x: sx,
            y: sy,
            w: sw,
            h: sh
        });
    }

    function checkOverlap() {
        const mon = Hypr.monitorFor(root.screen);
        const ws = mon?.activeWorkspace;
        const monY = mon?.lastIpcObject?.y ?? 0;
        const screenH = root.screen.height;
        const panelTop = monY + screenH - 80;
        const windows = ws?.toplevels?.values ?? [];
        for (let i = 0; i < windows.length; i++) {
            const ipc = windows[i].lastIpcObject;
            if (!ipc)
                continue;
            const winY = ipc.at?.[1] ?? 0;
            const winH = ipc.size?.[1] ?? 0;

            // Only consider windows on this monitor that overlap the bottom 80px
            if (winH > 0 && (winY + winH) > panelTop) {
                return true;
            }
        }
        return false;
    }
    // Hyprland IPC limitation: it DOES NOT emit any events when windows
    // are toggled floating/tiled or dragged manually.
    // The ONLY way to know a window moved into the panel's space is to actively sync.
    // Poll overlap for smarthide; fast when state may change, slow when stable.
    Timer {
        id: geometrySyncLoop
        interval: 350
        property int ticksLeft: 0
        running: ticksLeft > 0 && bottomPanelMode === "smarthide" && root.bottomPanelEnabled && (!LockState.locked || LockState.unlocking)
        repeat: true
        onTriggered: {
            ticksLeft--;
            Hyprland.refreshToplevels();
            const overlap = checkOverlap();
            if (overlap !== hasWindowsOverlappingPanel)
                hasWindowsOverlappingPanel = overlap;
            _lastOverlapState = overlap;
        }

        function kick(ticks = 3): void {
            ticksLeft = Math.max(ticksLeft, ticks);
            restart();
            Hyprland.refreshToplevels();
            const overlap = root.checkOverlap();
            if (overlap !== root.hasWindowsOverlappingPanel)
                root.hasWindowsOverlappingPanel = overlap;
            root._lastOverlapState = overlap;
        }
    }

    Connections {
        target: Hypr
        function onToplevelUpdateCounterChanged(): void {
            if (root.bottomPanelMode !== "smarthide")
                return;
            geometrySyncLoop.kick(3);
        }
        function onActiveWsIdChanged(): void {
            if (root.bottomPanelMode !== "smarthide")
                return;
            geometrySyncLoop.kick(3);
        }
        function onFocusedWorkspaceChanged(): void {
            if (root.bottomPanelMode !== "smarthide")
                return;
            geometrySyncLoop.kick(3);
        }
    }

    Connections {
        target: Hyprland.workspaces
        function onValuesChanged(): void {
            if (root.bottomPanelMode === "smarthide")
                geometrySyncLoop.kick(3);
        }
    }

    Connections {
        target: Hyprland.toplevels
        function onValuesChanged(): void {
            if (root.bottomPanelMode === "smarthide")
                geometrySyncLoop.kick(3);
        }
    }

    // Close context menu when launcher opens
    Connections {
        target: root.visibilities
        function onLauncherChanged(): void {
            if (root.visibilities.launcher && root.contextMenuVisible) {
                root.hideContextMenu();
            }
        }
    }

    // Timer to clear menu data after fade-out animation completes
    Timer {
        id: menuFadeOutTimer
        interval: 300  // Match the opacity animation duration
        onTriggered: {
            contextMenuAppId = "";
            contextMenuWindows = [];
        }
    }

    // Whether the panel should be visible based on mode
    readonly property bool bottomPanelVisible: {
        if (!bottomPanelEnabled)
            return false;
        if (visibilities.powermenu)
            return false;
        // Force panel visible when context menu is open (suppress autohide)
        if (contextMenuVisible)
            return true;
        if (bottomPanelMode === "smarthide") {
            // If a window overlaps the bottom 80px, react like autohide (hover to show)
            // If no window overlaps, always show
            return hasWindowsOverlappingPanel ? visibilities.bottomPanel : true;
        }
        if (bottomPanelMode === "autohide") {
            // Use Interactions.qml hover-controlled visibilities.bottomPanel
            return visibilities.bottomPanel;
        }
        // "always": always visible
        return true;
    }
    Component.onCompleted: {
        geometrySyncLoop.kick(10);
    }

    Behavior on bottomMargin {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    anchors.fill: parent
    anchors.margins: borderThickness + (safeBorder.floating ? 5 : 0)
    anchors.bottomMargin: bottomMargin

    anchors.leftMargin: bar.implicitWidth + (safeBorder.floating ? 5 : 0)

    Item {
        id: flyoutsWrapper

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 0
        clip: root.powermenuVisible

        implicitWidth: flyouts.implicitWidth * (1 - flyouts.offsetScale)
        implicitHeight: flyouts.implicitHeight

        Osd.Wrapper {
            id: flyouts

            screen: root.screen
            visibilities: root.visibilities
            sidebarOrSessionVisible: root.powermenuVisible
            screenCapture: root.flyoutsScreenCapture

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
        }
    }

    Notifications.Wrapper {
        id: notifications

        visibilities: root.visibilities
        flyoutsPanel: flyoutsWrapper
        powermenuPanel: powermenuWrapper

        anchors.top: parent.top
        anchors.right: parent.right
        // Above other panel chrome so expand / swipe hit the card, not qspanel hot-zone
        z: 30
    }

    Item {
        id: powermenuWrapper

        anchors.fill: parent
        anchors.leftMargin: -bar.implicitWidth
        anchors.topMargin: -root.anchors.margins
        anchors.rightMargin: -root.anchors.margins
        anchors.bottomMargin: -root.anchors.margins
        z: 999

        Session.Wrapper {
            id: powermenu

            visibilities: root.visibilities

            anchors.fill: parent
        }
    }

    Launcher.Wrapper {
        id: launcher

        screen: root.screen
        visibilities: root.visibilities
        panels: root

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -(bar.implicitWidth - root.borderThickness) / 2
        anchors.bottom: parent.bottom
    }

    // Independent Wallpaper Selector drawer
    Launcher.WallpaperWrapper {
        id: wallpaperSelector

        screen: root.screen
        visibilities: root.visibilities
        panels: root

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -(bar.implicitWidth - root.borderThickness) / 2
        anchors.bottom: parent.bottom
        width: Math.min(parent.width - 32, 1030)
    }

    Dashboard.Wrapper {
        id: dashboard

        visibilities: root.visibilities

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -(bar.implicitWidth - root.borderThickness) / 2
        anchors.top: parent.top
    }

    BarPopouts.ClipWrapper {
        id: popoutsWrapper

        screen: root.screen
        borderThickness: root.borderThickness
    }

    Utilities.Wrapper {
        id: qspanel

        visibilities: root.visibilities
        popouts: popoutsWrapper.content

        // Full height right column — root item already shrinks by bottomMargin, no extra offset needed
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
    }

    // Top-right: drag-only open via Interactions (no click MouseArea — would steal heads-up notifs).
    // Bottom-right: still click-to-open when bottom panel is off.
    MouseArea {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 32
        height: 32
        visible: !(root.bottomPanelEnabled) && !root.visibilities.qspanel && Config.qspanel.enabled
        z: 20

        onClicked: {
            root.visibilities.qspanel = true;
        }
    }



    Toasts.Toasts {
        id: toasts

        // Float above bottom panel / screen bottom in bottom-center
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: (root.bottomPanelEnabled && root.bottomPanelVisible) ? bottomPanel.top : parent.bottom
        anchors.bottomMargin: Tokens.padding.large + ((root.bottomPanelEnabled && root.bottomPanelVisible) ? 12 : 24)
        z: 35
    }

    Item {
        id: bottomPanel

        readonly property real safeParentHeight: parent ? (parent.height > 100 ? parent.height : (root.screen?.height ?? 1080)) : 1080

        // Anchor horizontally to cover the full width of the content area
        anchors.left: parent.left
        anchors.leftMargin: 0
        anchors.right: parent.right
        anchors.rightMargin: -(root.borderThickness + (safeBorder.floating ? 5 : 0))

        height: 80
        visible: root.bottomPanelEnabled
        // Float above content in overlay modes; behind nothing in always mode
        z: root.bottomPanelMode === "always" ? 0 : 10

        // Slide-up behavior relative to parent (which has bottomMargin)
        opacity: root.bottomPanelVisible ? 1 : 0
        y: root.bottomPanelVisible ? safeParentHeight + root.bottomMargin - height : safeParentHeight + root.bottomMargin

        Behavior on opacity {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            enabled: parent ? parent.height > 100 : false
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        // Clean premium glassmorphic overlay for the full-width panel background
        StyledRect {
            anchors.fill: parent
            color: "transparent"

            // Dismiss QS panel and clipboard if clicking empty space in the bottom panel
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.contextMenuVisible) {
                        root.hideContextMenu();
                        return;
                    }
                    if (root.visibilities.launcher) {
                        root.visibilities.launcher = false;
                        return;
                    }
                    if (root.visibilities.qspanel) {
                        root.visibilities.qspanel = false;
                    } else if (root.visibilities.clipboard) {
                        root.visibilities.clipboard = false;
                    }
                }
            }

            // Pill layout container — same glass bg as Quick Toggles card
            Rectangle {
                anchors.centerIn: parent
                height: 70
                width: layout.width + 20
                radius: 20
                visible: pinnedModel.count > 0
                color: Colours.tileGlassStrong
                border.color: Colours.tileShine
                border.width: 1

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: parent.radius - 1
                    color: "transparent"
                    border.color: Colours.tileShineSoft
                    border.width: 1
                }

                // Manual positioning container for drag-and-drop
                Item {
                    id: layout
                    anchors.centerIn: parent
                    width: {
                        const c = pinnedModel.count;
                        return c * 52 + Math.max(0, c - 1) * 12;
                    }
                    height: 58

                    ListModel { id: pinnedModel }

                    Connections {
                        target: root.visibilities
                        function onPinnedAppsChanged() {
                            if (!pinnedState.isDragging && !pinnedState.isLandingNow)
                                pinnedState.syncModel(root.visibilities.pinnedApps || []);
                        }
                    }

                    Component.onCompleted: {
                        pinnedState.syncModel(root.visibilities.pinnedApps || []);
                    }

                    QtObject {
                        id: pinnedState
                        property string draggedAppId: ""
                        property int draggedOriginalIndex: -1
                        property Item hoveredAppIcon: null
                        property int hoverTargetSlot: -1
                        property real dragStartX: 0
                        property real dragStartY: 0
                        property bool isDragging: false
                        property bool isLandingNow: false
                        property string landingAppId: ""
                        readonly property real dragThreshold: 10

                        function syncModel(apps) {
                            while (pinnedModel.count > apps.length)
                                pinnedModel.remove(pinnedModel.count - 1);
                            for (let i = 0; i < apps.length; i++) {
                                if (i < pinnedModel.count) {
                                    if (pinnedModel.get(i).appId !== apps[i])
                                        pinnedModel.set(i, { "appId": apps[i] });
                                } else {
                                    pinnedModel.append({ "appId": apps[i] });
                                }
                            }
                        }
                        function startDrag(appId, index, startX, startY) {
                            draggedAppId = appId; draggedOriginalIndex = index;
                            dragStartX = startX; dragStartY = startY;
                            hoverTargetSlot = index; isDragging = false;
                        }
                        function updateDrag(mouseX, mouseY) {
                            if (!isDragging) {
                                const dx = mouseX - dragStartX, dy = mouseY - dragStartY;
                                if (Math.sqrt(dx*dx + dy*dy) > dragThreshold) isDragging = true;
                            }
                            if (isDragging)
                                hoverTargetSlot = Math.max(0, Math.min(pinnedModel.count - 1, Math.round((mouseX - layout.x) / 64)));
                        }
                        function endDrag() {
                            if (isDragging && draggedOriginalIndex !== hoverTargetSlot) {
                                const from = draggedOriginalIndex, to = hoverTargetSlot, appId = draggedAppId;
                                isDragging = false; isLandingNow = true; landingAppId = appId;
                                pinnedModel.move(from, to, 1);
                                const newOrder = [];
                                for (let i = 0; i < pinnedModel.count; i++) newOrder.push(pinnedModel.get(i).appId);
                                root.visibilities.pinnedApps = newOrder;
                                draggedAppId = ""; draggedOriginalIndex = -1; hoverTargetSlot = -1;
                                landingEndTimer.restart();
                            } else {
                                draggedAppId = ""; draggedOriginalIndex = -1; hoverTargetSlot = -1;
                                isDragging = false; isLandingNow = false;
                            }
                        }
                        function cancelDrag() {
                            draggedAppId = ""; draggedOriginalIndex = -1; hoverTargetSlot = -1; isDragging = false;
                        }
                        function getTargetX(currentIndex) {
                            if (isDragging) {
                                if (currentIndex === draggedOriginalIndex) return hoverTargetSlot * 64;
                                if (draggedOriginalIndex < hoverTargetSlot) {
                                    if (currentIndex > draggedOriginalIndex && currentIndex <= hoverTargetSlot)
                                        return (currentIndex - 1) * 64;
                                } else {
                                    if (currentIndex < draggedOriginalIndex && currentIndex >= hoverTargetSlot)
                                        return (currentIndex + 1) * 64;
                                }
                            }
                            return currentIndex * 64;
                        }
                    }

                    Timer {
                        id: landingEndTimer
                        interval: 450
                        onTriggered: { pinnedState.isLandingNow = false; pinnedState.landingAppId = ""; }
                    }

                    Connections {
                        target: root.visibilities
                        function onPinnedAppsLandingAppIdChanged() {
                            const appId = root.visibilities.pinnedAppsLandingAppId;
                            if (appId && appId !== "") {
                                pinnedState.isLandingNow = true;
                                pinnedState.landingAppId = appId;
                                root.visibilities.pinnedAppsLandingAppId = "";
                            }
                        }
                    }

                    Rectangle {
                        id: pinnedHoverHighlight
                        visible: pinnedState.hoveredAppIcon !== null
                        opacity: visible ? 1 : 0
                        color: Colours.layer(Colours.palette.m3surfaceVariant, 0.8)
                        border.color: Qt.alpha(Colours.palette.m3onSurface, 0.12)
                        border.width: 1
                        width: 52; height: 52; radius: 12
                        x: pinnedState.hoveredAppIcon ? pinnedState.hoveredAppIcon.x : 0
                        y: pinnedState.hoveredAppIcon ? pinnedState.hoveredAppIcon.y + 3 : 0
                        Behavior on x { enabled: pinnedHoverHighlight.opacity > 0; SpringAnimation { spring: 7.0; damping: 0.8; mass: 1.0; epsilon: 0.005 } }
                        Behavior on y { enabled: pinnedHoverHighlight.opacity > 0; SpringAnimation { spring: 7.0; damping: 0.8; mass: 1.0; epsilon: 0.005 } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    Repeater {
                        model: pinnedModel

                        Item {
                            id: appWrapper
                            required property var model
                            required property int index

                            readonly property string appId: model.appId
                            property string cachedIcon: ""
                            property var entry: {
                                const apps = DesktopEntries.applications.values;
                                for (let i = 0; i < apps.length; i++) {
                                    if (apps[i].id === appId)
                                        return apps[i];
                                }
                                return undefined;
                            }

                            onEntryChanged: {
                                cachedIcon = Icons.resolveIcon(entry?.icon || "", "image-missing");
                            }

                            width: 52
                            height: 52 + 6

                            property int runningInstances: 0

                            function normalizeAddress(addr) {
                                if (!addr) return "";
                                const str = String(addr);
                                return str.startsWith("0x") ? str : "0x" + str;
                            }

                            function updateRunningCount() {
                                if (!appId) { runningInstances = 0; return; }
                                const toplevels = Hypr.toplevels?.values ?? [];
                                let count = 0;
                                for (let i = 0; i < toplevels.length; i++) {
                                    const ipc = toplevels[i].lastIpcObject;
                                    if (ipc && ipc.class === appId) count++;
                                }
                                runningInstances = count;
                            }

                            Connections {
                                target: Hypr
                                function onToplevelUpdateCounterChanged() { appWrapper.updateRunningCount(); }
                            }

                            Component.onCompleted: {
                                cachedIcon = Icons.resolveIcon(entry?.icon || "", "image-missing");
                                updateRunningCount();
                            }

                            Connections {
                                target: pinnedState
                                function onLandingAppIdChanged() {
                                    if (pinnedState.landingAppId === appId) landingAnim.start();
                                }
                            }

                            x: pinnedState.getTargetX(index)
                            y: (pinnedState.draggedAppId === appId && pinnedState.isDragging) ? -12 : 0
                            z: pinnedState.draggedAppId === appId ? 100 : 0

                            Behavior on x { SpringAnimation { spring: 6.5; damping: 0.75; mass: 1.0; epsilon: 0.005 } }
                            Behavior on y { SpringAnimation { spring: 7.0; damping: 0.68; mass: 1.0; epsilon: 0.005 } }

                            Rectangle {
                                id: iconBg
                                objectName: "iconBg"
                                anchors.centerIn: parent
                                width: 52
                                height: 52
                                radius: 12
                                smooth: false
                                antialiasing: true

                                color: "transparent"
                                border.color: "transparent"
                                border.width: 1

                                scale: (pinnedState.isLandingNow && pinnedState.landingAppId === appId) ? 1.0
                                    : ((pinnedState.draggedAppId === appId && pinnedState.isDragging) ? 1.25
                                    : (dragArea.containsMouse && !pinnedState.isDragging ? 1.1 : 1.0))

                                Behavior on scale {
                                    enabled: !(pinnedState.isLandingNow && pinnedState.landingAppId === appId)
                                    SpringAnimation { spring: 7.0; damping: 0.68; mass: 1.0; epsilon: 0.005 }
                                }
                                Behavior on color {
                                    ColorAnimation { duration: Tokens.anim.durations.small; easing: Tokens.anim.standard }
                                }

                                SequentialAnimation {
                                    id: landingAnim
                                    NumberAnimation {
                                        target: iconBg; property: "scale"; from: 1.0; to: 0.92
                                        duration: Tokens.anim.durations.expressiveFastEffects
                                        easing: Tokens.anim.expressiveFastSpatial
                                    }
                                    NumberAnimation {
                                        target: iconBg; property: "scale"; from: 0.92; to: 1.0
                                        duration: Tokens.anim.durations.expressiveDefaultEffects
                                        easing: Tokens.anim.emphasizedDecel
                                    }
                                }

                                IconImage {
                                    id: icon
                                    asynchronous: true
                                    source: appWrapper.cachedIcon
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    smooth: true

                                    scale: (pinnedState.draggedAppId === appId && pinnedState.isDragging) ? 1.15
                                        : (pinnedState.isLandingNow && pinnedState.landingAppId === appId) ? 1.0 : 1.0

                                    Behavior on scale {
                                        enabled: !(pinnedState.isLandingNow && pinnedState.landingAppId === appId)
                                        SpringAnimation { spring: 7.0; damping: 0.68; mass: 1.0; epsilon: 0.005 }
                                    }

                                    SequentialAnimation {
                                        id: iconAnim
                                        ScaleAnimator {
                                            target: icon; from: 1.0; to: 1.4
                                            duration: Tokens.anim.durations.small; easing: Tokens.anim.emphasized
                                        }
                                        ScaleAnimator {
                                            target: icon; from: 1.4; to: 1.0
                                            duration: Tokens.anim.durations.normal; easing: Tokens.anim.emphasized
                                        }
                                    }
                                }

                                // Running instances indicator bar
                                Item {
                                    anchors.top: iconBg.bottom
                                    anchors.topMargin: -4
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 52
                                    height: appWrapper.runningInstances > 0 ? 3 : 0
                                    visible: appWrapper.runningInstances > 0

                                    Behavior on height { Anim { type: Anim.DefaultSpatial } }

                                    Row {
                                        anchors.fill: parent
                                        spacing: appWrapper.runningInstances > 1 ? 1 : 0
                                        Repeater {
                                            model: appWrapper.runningInstances
                                            Rectangle {
                                                width: (52 - (appWrapper.runningInstances > 1 ? (appWrapper.runningInstances - 1) : 0)) / appWrapper.runningInstances
                                                height: 3; radius: 1.5
                                                color: Colours.palette.m3primary
                                                Behavior on color { ColorAnimation { duration: Tokens.anim.durations.small } }
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: dragArea
                                anchors.fill: parent
                                anchors.margins: -4
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                hoverEnabled: true
                                cursorShape: Qt.ArrowCursor
                                property bool isPressing: false

                                onPressed: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        isPressing = true;
                                        pinnedState.startDrag(appId, index, appWrapper.x + mouse.x, appWrapper.y + mouse.y);
                                    } else if (mouse.button === Qt.RightButton) {
                                        root.showContextMenu(appId, iconBg);
                                    }
                                }
                                onContainsMouseChanged: {
                                    if (containsMouse && !pinnedState.isDragging)
                                        pinnedState.hoveredAppIcon = appWrapper;
                                    else if (pinnedState.hoveredAppIcon === appWrapper)
                                        pinnedState.hoveredAppIcon = null;
                                }
                                onPositionChanged: mouse => {
                                    if (isPressing && pinnedState.draggedAppId === appId)
                                        pinnedState.updateDrag(appWrapper.x + mouse.x, appWrapper.y + mouse.y);
                                }
                                onReleased: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        if (pinnedState.draggedAppId === appId) {
                                            if (!pinnedState.isDragging && appWrapper.entry) {
                                                iconAnim.start();
                                                const toplevels = Hypr.toplevels?.values ?? [];
                                                const matches = [];
                                                for (let i = 0; i < toplevels.length; i++) {
                                                    const ipc = toplevels[i].lastIpcObject;
                                                    if (ipc && ipc.class === appId) matches.push(toplevels[i]);
                                                }
                                                if (matches.length === 0) {
                                                    LauncherServices.Apps.launch(appWrapper.entry);
                                                } else if (matches.length === 1) {
                                                    const ipc = matches[0].lastIpcObject;
                                                    const addr = appWrapper.normalizeAddress(ipc.address);
                                                    const wsId = ipc.workspace?.id ?? 1;
                                                    Hypr.dispatch(`workspace ${wsId}`);
                                                    Hypr.dispatch(`focuswindow address:${addr}`);
                                                } else {
                                                    const activeWindow = Hyprland.activeToplevel;
                                                    const activeIpc = activeWindow?.lastIpcObject;
                                                    const activeAddr = appWrapper.normalizeAddress(activeIpc?.address);
                                                    let activeIndex = -1;
                                                    for (let i = 0; i < matches.length; i++) {
                                                        const matchIpc = matches[i].lastIpcObject;
                                                        const matchAddr = appWrapper.normalizeAddress(matchIpc?.address);
                                                        if (matchAddr === activeAddr) { activeIndex = i; break; }
                                                    }
                                                    const targetWindow = activeIndex === -1 ? matches[0] : matches[(activeIndex + 1) % matches.length];
                                                    const targetIpc = targetWindow.lastIpcObject;
                                                    const targetAddr = appWrapper.normalizeAddress(targetIpc?.address);
                                                    const targetWsId = targetIpc?.workspace?.id ?? 1;
                                                    Hypr.dispatch(`workspace ${targetWsId}`);
                                                    Hypr.dispatch(`focuswindow address:${targetAddr}`);
                                                }
                                                root.visibilities.bottomPanel = false;
                                            }
                                            pinnedState.endDrag();
                                        }
                                        isPressing = false;
                                    }
                                }
                                onCanceled: {
                                    if (pinnedState.draggedAppId === appId) pinnedState.cancelDrag();
                                    isPressing = false;
                                }
                            }
                        }
                    }
                }
            }


        }
    }

    // Global backdrop to close menu when clicking outside (at root level to cover entire screen)
    MouseArea {
        visible: root.contextMenuVisible
        anchors.fill: parent
        z: 9999
        onClicked: root.hideContextMenu()
    }

    // Menu card — positioned at root level above the panel
    Elevation {
        id: menuContainer
        x: root.contextMenuX
        y: root.height + root.bottomMargin - 80 - implicitHeight - 8
        radius: Tokens.rounding.normal
        level: 2
        z: 10000
        visible: root.contextMenuVisible

        implicitWidth: root.contextMenuWidth
        implicitHeight: Math.min(menuCol.implicitHeight + Tokens.padding.normal * 2, 350)

        scale: root.contextMenuVisible ? 1 : 0.85
        transformOrigin: Item.Bottom
        opacity: root.contextMenuVisible ? 1 : 0

        readonly property var m3Emphasized: [0.2, 0.0, 0.0, 1.0, 1, 1]

        Behavior on opacity {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 250
                easing.type: Easing.BezierSpline
                easing.bezierCurve: menuContainer.m3Emphasized
            }
        }

        Behavior on x {
            NumberAnimation {
                duration: 250
                easing.type: Easing.BezierSpline
                easing.bezierCurve: menuContainer.m3Emphasized
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: 250
                easing.type: Easing.BezierSpline
                easing.bezierCurve: menuContainer.m3Emphasized
            }
        }

        StyledRect {
            anchors.fill: parent
            radius: parent.radius
            color: Colours.palette.m3surfaceContainerLow
            clip: true

            // Sliding hover highlight marker
            StyledRect {
                id: contextMenuHoverHighlight
                visible: root.contextMenuHoveredItem !== null
                opacity: visible ? 0.08 : 0
                color: Colours.palette.m3onSurface
                radius: Tokens.rounding.small

                // Position it matching the hoveredItem
                x: root.contextMenuHoveredItem ? root.contextMenuHoveredItem.mapToItem(parent, 0, 0).x : 0
                y: root.contextMenuHoveredItem ? root.contextMenuHoveredItem.mapToItem(parent, 0, 0).y : 0
                width: root.contextMenuHoveredItem ? root.contextMenuHoveredItem.width : 0
                height: root.contextMenuHoveredItem ? root.contextMenuHoveredItem.height : 0

                Behavior on x {
                    enabled: contextMenuHoverHighlight.opacity > 0
                    SpringAnimation {
                        spring: 7.0
                        damping: 0.8
                        mass: 1.0
                        epsilon: 0.005
                    }
                }
                Behavior on y {
                    enabled: contextMenuHoverHighlight.opacity > 0
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

            QCtls.ScrollView {
                anchors.fill: parent
                clip: true
                QCtls.ScrollBar.vertical.policy: QCtls.ScrollBar.AsNeeded
                QCtls.ScrollBar.horizontal.visible: false

                ColumnLayout {
                    id: menuCol
                    width: parent.width
                    spacing: 2
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8

                    readonly property var m3Emphasized: [0.2, 0.0, 0.0, 1.0, 1, 1]

                    // Running windows (if any)
                    Repeater {
                        model: root.contextMenuWindows ?? []

                        StyledRect {
                            id: windowItem
                            required property int index
                            required property var modelData
                            readonly property bool active: windowState.containsMouse || windowState.pressed || root.contextMenuHoveredItem === windowItem

                            Layout.fillWidth: true
                            implicitHeight: root.contextMenuRowHeight

                            opacity: root.contextMenuVisible && visible ? 1 : 0
                            scale: root.contextMenuVisible && visible ? 1 : 0.95
                            transformOrigin: Item.Top
                            visible: true

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: menuCol.m3Emphasized
                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: menuCol.m3Emphasized
                                }
                            }

                            Timer {
                                id: closeAnimationTimer
                                interval: 200
                                onTriggered: {
                                    const win = windowItem.modelData;
                                    if (win && win.address) {
                                        Hypr.dispatch(`closewindow address:${win.address}`);
                                    }
                                }
                            }

                            radius: Tokens.rounding.small
                            topLeftRadius: Tokens.rounding.small
                            topRightRadius: Tokens.rounding.small
                            bottomLeftRadius: Tokens.rounding.small
                            bottomRightRadius: Tokens.rounding.small
                            color: "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }
                            }

                            StateLayer {
                                id: windowState
                                radius: parent.radius
                                topLeftRadius: parent.topLeftRadius
                                topRightRadius: parent.topRightRadius
                                bottomLeftRadius: parent.bottomLeftRadius
                                bottomRightRadius: parent.bottomRightRadius
                                color: windowItem.active ? Colours.palette.m3primary : Colours.palette.m3onSurface
                                disabled: !root.contextMenuVisible
                                hoverEnabled: false

                                onClicked: {
                                    const win = windowItem.modelData;
                                    if (win) {
                                        Hypr.dispatch(`workspace ${win.workspaceId}`);
                                        Hypr.dispatch(`focuswindow address:${win.address}`);
                                        root.hideContextMenu();
                                        root.visibilities.bottomPanel = false;
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                                onEntered: {
                                    if (root.contextMenuVisible) {
                                        root.contextMenuHoveredItem = windowItem;
                                    }
                                }
                                onExited: {
                                    if (root.contextMenuHoveredItem === windowItem) {
                                        root.contextMenuHoveredItem = null;
                                    }
                                }
                            }

                            RowLayout {
                                id: windowRow
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                spacing: 12

                                MaterialIcon {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredWidth: root.contextMenuIconCell
                                    Layout.preferredHeight: root.contextMenuIconCell
                                    text: "tab"
                                    iconPointSize: Tokens.font.size.normal
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    color: windowItem.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                }

                                Item {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: windowTitle.implicitHeight
                                    clip: true

                                    StyledText {
                                        id: windowTitle
                                        text: windowTitleMetrics.elidedText
                                        textPixelSize: 14
                                        color: windowItem.active ? Colours.palette.m3primary : Colours.palette.m3onSurface
                                        anchors.verticalCenter: parent.verticalCenter

                                        readonly property string fullTitle: windowItem.modelData?.title ?? qsTr("Untitled")
                                        readonly property real textWidth: windowTitleMetrics.tightBoundingRect.width
                                        readonly property real containerWidth: parent.width
                                        readonly property bool needsScroll: textWidth > containerWidth

                                        TextMetrics {
                                            id: windowTitleMetrics
                                            text: windowTitle.fullTitle
                                            font.pixelSize: windowTitle.resolvedPixelSize
                                            font.family: windowTitle.font.family
                                            elide: Text.ElideRight
                                            elideWidth: windowTitle.containerWidth
                                        }
                                    }
                                }

                                Item {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredWidth: root.contextMenuCloseCell
                                    Layout.preferredHeight: root.contextMenuCloseCell
                                    opacity: windowItem.active ? 1 : 0

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 200
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    MaterialIcon {
                                        id: closeIcon
                                        text: "close"
                                        iconPointSize: Tokens.font.size.normal
                                        color: Colours.palette.m3primary
                                        anchors.centerIn: parent
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter

                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                windowItem.opacity = 0;
                                                windowItem.scale = 0.85;
                                                windowItem.visible = false;
                                                closeAnimationTimer.restart();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // "Open New Window"
                    StyledRect {
                        id: openItem
                        readonly property bool active: openNewState.containsMouse || openNewState.pressed

                        Layout.fillWidth: true
                        implicitHeight: root.contextMenuRowHeight

                        opacity: root.contextMenuVisible ? 1 : 0
                        scale: root.contextMenuVisible ? 1 : 0.95
                        transformOrigin: Item.Top

                        radius: Tokens.rounding.small
                        topLeftRadius: Tokens.rounding.small
                        topRightRadius: Tokens.rounding.small
                        bottomLeftRadius: Tokens.rounding.small
                        bottomRightRadius: Tokens.rounding.small

                        color: "transparent"

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: menuCol.m3Emphasized
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: menuCol.m3Emphasized
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }

                        StateLayer {
                            id: openNewState
                            radius: parent.radius
                            topLeftRadius: parent.topLeftRadius
                            topRightRadius: parent.topRightRadius
                            bottomLeftRadius: parent.bottomLeftRadius
                            bottomRightRadius: parent.bottomRightRadius

                            color: openItem.active ? Colours.palette.m3primary : Colours.palette.m3onSurface
                            disabled: !root.contextMenuVisible
                            hoverEnabled: false

                            onClicked: {
                                const e = root.contextMenuEntry();
                                if (e)
                                    LauncherServices.Apps.launch(e);
                                root.hideContextMenu();
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                            onEntered: {
                                if (root.contextMenuVisible) {
                                    root.contextMenuHoveredItem = openItem;
                                }
                            }
                            onExited: {
                                if (root.contextMenuHoveredItem === openItem) {
                                    root.contextMenuHoveredItem = null;
                                }
                            }
                        }

                        RowLayout {
                            id: openRow
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            MaterialIcon {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: root.contextMenuIconCell
                                Layout.preferredHeight: root.contextMenuIconCell
                                text: "add"
                                iconPointSize: Tokens.font.size.normal
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                color: openItem.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                                text: qsTr("Open New Window")
                                textPixelSize: 14
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignLeft
                                color: openItem.active ? Colours.palette.m3primary : Colours.palette.m3onSurface
                            }
                        }
                    }

                    // "Remove from Panel"
                    StyledRect {
                        id: removeItem
                        readonly property bool active: removeState.containsMouse || removeState.pressed

                        Layout.fillWidth: true
                        implicitHeight: root.contextMenuRowHeight

                        opacity: root.contextMenuVisible ? 1 : 0
                        scale: root.contextMenuVisible ? 1 : 0.95
                        transformOrigin: Item.Top

                        radius: Tokens.rounding.small
                        topLeftRadius: Tokens.rounding.small
                        topRightRadius: Tokens.rounding.small
                        bottomLeftRadius: Tokens.rounding.small
                        bottomRightRadius: Tokens.rounding.small

                        color: "transparent"

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: menuCol.m3Emphasized
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: menuCol.m3Emphasized
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }

                        StateLayer {
                            id: removeState
                            radius: parent.radius
                            topLeftRadius: parent.topLeftRadius
                            topRightRadius: parent.topRightRadius
                            bottomLeftRadius: parent.bottomLeftRadius
                            bottomRightRadius: parent.bottomRightRadius

                            color: removeItem.active ? Colours.palette.m3primary : Colours.palette.m3onSurface
                            disabled: !root.contextMenuVisible
                            hoverEnabled: false

                            onClicked: {
                                const pinned = (root.visibilities.pinnedApps || []).slice();
                                const idx = pinned.indexOf(root.contextMenuAppId);
                                if (idx > -1) {
                                    pinned.splice(idx, 1);
                                    root.visibilities.pinnedApps = pinned;
                                }
                                root.hideContextMenu();
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                            onEntered: {
                                if (root.contextMenuVisible) {
                                    root.contextMenuHoveredItem = removeItem;
                                }
                            }
                            onExited: {
                                if (root.contextMenuHoveredItem === removeItem) {
                                    root.contextMenuHoveredItem = null;
                                }
                            }
                        }

                        RowLayout {
                            id: removeRow
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            MaterialIcon {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: root.contextMenuIconCell
                                Layout.preferredHeight: root.contextMenuIconCell
                                text: "keep_off"
                                iconPointSize: Tokens.font.size.normal
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                color: removeItem.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                                text: qsTr("Remove from Panel")
                                textPixelSize: 14
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignLeft
                                color: removeItem.active ? Colours.palette.m3primary : Colours.palette.m3onSurface
                            }
                        }
                    }
                }
            }
        }
    }
}
