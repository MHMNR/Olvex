import QtQuick
import QtQuick.Controls
import Quickshell
import Olvex.Config
import qs.components
import qs.components.controls
import qs.modules.bar as Bar
import qs.modules.bar.popouts as BarPopouts
import qs.services

CustomMouseArea {
    id: root

    required property ShellScreen screen
    required property BarPopouts.Wrapper popouts
    required property DrawerVisibilities visibilities
    required property Panels panels
    required property Bar.BarWrapper bar
    required property real borderThickness
    required property var safeBorder
    required property bool fullscreen

    property point dragStart
    property bool dashboardShortcutActive
    property bool flyoutsShortcutActive
    property bool qspanelShortcutActive: false
    property bool bottomPanelShortcutActive: false
    property bool wallpaperShortcutActive: false
    property bool launcherHoverDisabled: false

    readonly property int floatingGap: safeBorder.floating ? 5 : 0
    readonly property real hoverTolerance: root.borderThickness + floatingGap
    readonly property real verticalTolerance: root.borderThickness + floatingGap

    function inBottomPanelArea(x: real, y: real): bool {
        if (x < bar.implicitWidth)
            return false;
        if (visibilities.bottomPanel) {
            return y >= height - 80;
        }
        return y >= height - 4;
    }

    function withinPanelHeight(panel: Item, x: real, y: real): bool {
        const panelY = root.borderThickness + floatingGap + panel.y;
        return y >= panelY && y <= panelY + panel.height;
    }

    function withinPanelWidth(panel: Item, x: real, y: real): bool {
        const panelX = bar.implicitWidth + floatingGap + panel.x;
        return x >= panelX && x <= panelX + panel.width;
    }

    function inPopout(x: real, y: real): bool {
        if (!popouts.hasCurrent)
            return false;

        const pop = panels.popoutsWrapper;
        if (!pop)
            return false;

        const content = pop.content;
        const cWidth = Math.max(pop.width, content ? (content.nonAnimWidth || content.implicitWidth) : 0);
        const cHeight = Math.max(pop.height, content ? (content.nonAnimHeight || content.implicitHeight) : 0);

        // 1. Direct hit on popout content (with 16px safety padding)
        const pt = pop.mapFromItem(root, x, y);
        if (pt.x >= -16 && pt.x <= cWidth + 16 && pt.y >= -16 && pt.y <= cHeight + 16)
            return true;

        // 2. Continuous bridge corridor between the bar edge and the popout
        const rightOfBar = x >= (bar.implicitWidth - 16);
        const leftOfPopout = x <= (bar.implicitWidth + cWidth + 32);
        const inVerticalRange = y >= (pop.y - 32) && y <= (pop.y + cHeight + 32);

        return rightOfBar && leftOfPopout && inVerticalRange;
    }

    function inLeftPanel(panel: Item, x: real, y: real): bool {
        return inPopout(x, y);
    }

    // Right-edge panels (OSD, powermenu, QS qspanel).
    function inRightPanel(panel: Item, x: real, y: real): bool {
        const offset = panel.offsetScale ?? 0; // qmllint disable missing-property
        if (offset < 1 && panel.width > 0) {
            // Open / peeking — use live panel geometry
            return x >= bar.implicitWidth + floatingGap + panel.x && withinPanelHeight(panel, x, y);
        }
        // Fully closed — right-edge hot zone (narrow edge trigger only)
        const inX = x >= width - 4;
        return inX && withinPanelHeight(panel, x, y);
    }

    // Top-right corner hot zone — drag-only opens QS qspanel panel (no click).
    function inTopRightCorner(x: real, y: real): bool {
        const edge = Math.max(6, safeBorder.thickness + floatingGap);
        return (x >= width - 80 && y <= edge) || (x >= width - edge && y <= 80);
    }

    // Heads-up notifs sit top-right — never steal their press/drag (expand / dismiss)
    function overNotifications(x: real, y: real): bool {
        const n = panels.notifications;
        if (!n || n.height <= 0 || n.width <= 0)
            return false;
        const p = n.mapFromItem(root, x, y);
        return p.x >= 0 && p.y >= 0 && p.x <= n.width && p.y <= n.height;
    }

    function inTopPanel(panel: Item, x: real, y: real): bool {
        if (!withinPanelWidth(panel, x, y))
            return false;
        if (panel.offsetScale !== undefined && panel.offsetScale < 1) {
            const panelHeight = panel.height * (1 - panel.offsetScale);
            return y <= safeBorder.thickness + floatingGap + panelHeight;
        }
        if (panel.peekOffset !== undefined && panel.peekOffset > 0) {
            return y <= Math.max(7, panel.peekOffset - 10);
        }
        // Closed state: edge hover trigger at the very top edge only
        return y <= Math.max(4, safeBorder.thickness + floatingGap);
    }

    // Bottom-left corner hot zone (launcher trigger)
    function inBottomLeftCorner(x: real, y: real): bool {
        const edgeH = Math.max(60, safeBorder.thickness + floatingGap + 30);
        const edgeW = Math.max(60, bar.implicitWidth + 30);
        return x <= edgeW && y >= height - edgeH;
    }

    // Bottom-right corner hot zone (QS panel trigger)
    function inBottomRightCorner(x: real, y: real): bool {
        const edgeH = Math.max(60, safeBorder.thickness + floatingGap + 30);
        const edgeW = Math.max(80, safeBorder.thickness + floatingGap + 40);
        return x >= width - edgeW && y >= height - edgeH;
    }

    function inBottomPanel(panel: Item, x: real, y: real, isCorner = false): bool {
        if (!withinPanelWidth(panel, x, y))
            return false;
        if (panel.offsetScale !== undefined && panel.offsetScale < 1) {
            const panelHeight = panel.height * (1 - panel.offsetScale);
            return y >= height - safeBorder.thickness - floatingGap - panelHeight;
        }
        return y >= height - Math.max(4, safeBorder.thickness + floatingGap);
    }

    function onWheel(event) {
        if (fullscreen)
            return;
        if (event.x < bar.implicitWidth) {
            bar.handleWheel(event.y, event.angleDelta);
            event.accepted = true;
            return;
        }
        if (visibilities.launcher
                && inBottomPanel(panels.launcher, event.x, event.y)
                && withinPanelWidth(panels.launcher, event.x, event.y)) {
            event.accepted = false;
        }
    }

    anchors.fill: parent
    acceptedButtons: fullscreen ? Qt.NoButton : Qt.AllButtons
    hoverEnabled: !fullscreen

    propagateComposedEvents: true
    onPressed: event => {
        if (Visibilities.areaPickerActive) {
            event.accepted = false;
            return;
        }

        dragStart = Qt.point(event.x, event.y);

        // Click bottom-left corner to toggle launcher
        if (inBottomLeftCorner(event.x, event.y)) {
            visibilities.launcher = !visibilities.launcher;
            event.accepted = true;
            return;
        }

        // Click bottom-right corner to toggle QS panel
        if (inBottomRightCorner(event.x, event.y)) {
            visibilities.qspanel = !visibilities.qspanel;
            if (visibilities.qspanel)
                qspanelShortcutActive = true;
            event.accepted = true;
            return;
        }

        // Click peeked dashboard to open
        if (Config.dashboard.showOnHover && inTopPanel(panels.dashboard, event.x, event.y) && !visibilities.dashboard) {
            visibilities.dashboard = true;
            dashboardShortcutActive = true;
            event.accepted = true;
            return;
        }

        // Heads-up notifs (any size) — never steal expand / swipe / action clicks
        if (overNotifications(event.x, event.y)) {
            event.accepted = false;
            return;
        }

        // Dismiss popout menus (tray context menu, popouts) when clicking outside
        if (popouts.hasCurrent) {
            const pop = panels.popoutsWrapper;
            const content = pop ? pop.content : null;
            const cWidth = Math.max(pop ? pop.width : 0, content ? (content.nonAnimWidth || content.implicitWidth) : 0);
            const cHeight = Math.max(pop ? pop.height : 0, content ? (content.nonAnimHeight || content.implicitHeight) : 0);
            const pt = pop ? pop.mapFromItem(root, event.x, event.y) : ({ x: -1, y: -1 });
            const inPopoutContent = pt.x >= 0 && pt.x <= cWidth && pt.y >= 0 && pt.y <= cHeight;

            if (!inPopoutContent) {
                popouts.hasCurrent = false;
                bar.closeTray();
                event.accepted = false;
                return;
            }
        }

        // Dismiss qspanel (QS panel) when clicking outside — only if NOT on a shell panel.
        // Must close + reject here (not ContentWindow MouseArea) so Wayland gets the event.
        if (visibilities.qspanel) {
            const util = panels.qspanel;
            const utilMapped = util.mapFromItem(root, event.x, event.y);
            const inUtil = utilMapped.x >= 0 && utilMapped.y >= 0 
                        && utilMapped.x <= util.width && utilMapped.y <= util.height;

            if (!inUtil) {
                visibilities.qspanel = false;
                event.accepted = false;
                return;
            }
        }

        // Dismiss launcher / wallpaper-selector when clicking outside their area.
        // Must happen in Interactions (not a separate overlay MouseArea) so that
        // event.accepted = false actually forwards the click to the underlying app.
        if (visibilities.launcher && !inBottomPanel(panels.launcher, event.x, event.y)) {
            // Let bar OS icon still toggle launcher
            let inOsIcon = false;
            if (bar.osIcon) {
                const osMapped = bar.osIcon.mapFromItem(root, event.x, event.y);
                inOsIcon = osMapped.x >= 0 && osMapped.y >= 0 && osMapped.x <= bar.osIcon.width && osMapped.y <= bar.osIcon.height;
            }
            const inBp = panels.bottomPanel.visible && event.y >= (height - panels.bottomPanel.height - root.borderThickness - floatingGap);
            if (!inOsIcon && !inBp) {
                visibilities.launcher = false;
                event.accepted = false;
                return;
            }
        }

        if (visibilities.wallpaperLauncher && !inBottomPanel(panels.wallpaperSelector, event.x, event.y)) {
            let inOsIcon = false;
            if (bar.osIcon) {
                const osMapped = bar.osIcon.mapFromItem(root, event.x, event.y);
                inOsIcon = osMapped.x >= 0 && osMapped.y >= 0 && osMapped.x <= bar.osIcon.width && osMapped.y <= bar.osIcon.height;
            }
            const inBp = panels.bottomPanel.visible && event.y >= (height - panels.bottomPanel.height - root.borderThickness - floatingGap);
            if (!inOsIcon && !inBp) {
                visibilities.wallpaperLauncher = false;
                event.accepted = false;
                return;
            }
        }

        // Dismiss dashboard when clicking outside — only if NOT on dashboard panel
        if (visibilities.dashboard) {
            const dash = panels.dashboard;
            const dashMapped = dash.mapFromItem(root, event.x, event.y);
            const inDash = dashMapped.x >= 0 && dashMapped.y >= 0 
                        && dashMapped.x <= dash.width && dashMapped.y <= dash.height;

            if (!inDash) {
                visibilities.dashboard = false;
                event.accepted = false;
                return;
            } else {
                event.accepted = false;
                return;
            }
        }

        dragStart = Qt.point(event.x, event.y);
    }

    // No click-to-open on top-right — drag only (see onPositionChanged).

    onContainsMouseChanged: {
        if (!containsMouse) {
            if (Visibilities.areaPickerActive)
                return;

            // Only hide if not activated by shortcut
            if (!flyoutsShortcutActive) {
                visibilities.flyouts = false;
                root.panels.flyouts.hovered = false;
            }

            root.panels.dashboard.hovered = false;

            // Close qspanel on hover-away
            if (!qspanelShortcutActive)
                visibilities.qspanel = false;
            root.panels.qspanel.hovered = false;

            if (!bottomPanelShortcutActive)
                visibilities.bottomPanel = false;

            if (!popouts.currentName.startsWith("traymenu")) {
                popouts.hasCurrent = false;
                bar.closeTray();
            }

            if (Config.bar.showOnHover)
                bar.isHovered = false;
        }
    }

    onPositionChanged: event => {
        if (Visibilities.areaPickerActive || popouts.isDetached)
            return;

        const x = event.x;
        const y = event.y;
        const dragX = x - dragStart.x;
        const dragY = y - dragStart.y;

        // Show bar in non-exclusive mode on hover
        if (!visibilities.bar && Config.bar.showOnHover && x < bar.clampedWidth)
            bar.isHovered = true;

        // Show/hide bar on drag
        if (pressed && dragStart.x < bar.clampedWidth) {
            if (dragX > Config.bar.dragThreshold)
                visibilities.bar = true;
            else if (dragX < -Config.bar.dragThreshold)
                visibilities.bar = false;
        }

        // Show OSD on hover
        const showOsd = inRightPanel(panels.flyoutsWrapper, x, y);

        // Always update visibility based on hover if not in shortcut mode
        if (!flyoutsShortcutActive) {
            visibilities.flyouts = showOsd;
            root.panels.flyouts.hovered = showOsd;
        } else if (showOsd) {
            // If hovering over OSD area while in shortcut mode, transition to hover control
            flyoutsShortcutActive = false;
            root.panels.flyouts.hovered = true;
        }

        // Show/hide powermenu on drag
        if (pressed && (dragStart.x > width - 50)) {
            if (dragX > Config.powermenu.dragThreshold)
                visibilities.powermenu = false;
        }

        // QS qspanel: drag left from top-right → open; drag right from right edge → close.
        // Inward (left) only — pure down/up would steal heads-up notif expand.
        // Hugging: slightly lower threshold (thinner chrome).
        if (pressed && Config.qspanel.enabled) {
            const baseThresh = Config.qspanel.dragThreshold ?? 40;
            const utilThresh = safeBorder.floating ? baseThresh : Math.max(20, Math.round(baseThresh * 0.65));
            if (!visibilities.qspanel
                    && inTopRightCorner(dragStart.x, dragStart.y)
                    && !overNotifications(dragStart.x, dragStart.y)) {
                // Require clear leftward drag; horizontal must dominate vertical
                if (dragX < -utilThresh && Math.abs(dragX) >= Math.abs(dragY) * 0.55) {
                    visibilities.qspanel = true;
                    qspanelShortcutActive = true;
                }
            } else if (visibilities.qspanel && dragStart.x > width - Math.max(60, utilThresh + 20)) {
                if (dragX > utilThresh) {
                    visibilities.qspanel = false;
                    qspanelShortcutActive = false;
                }
            }
        }


        // Show launcher on hover, or show/hide on drag if hover is disabled
        if (Config.launcher.showOnHover) {
            const inLauncherArea = inBottomPanel(panels.launcher, x, y);
            if (!visibilities.launcher && inLauncherArea && !root.launcherHoverDisabled) {
                visibilities.launcher = true;
            } else if (!inLauncherArea && root.launcherHoverDisabled) {
                root.launcherHoverDisabled = false;
            }
        } else if (!visibilities.wallpaperLauncher && !wallpaperShortcutActive
                && pressed && inBottomPanel(panels.launcher, dragStart.x, dragStart.y)
                && withinPanelWidth(panels.launcher, x, y)) {
            if (dragY < -Config.launcher.dragThreshold)
                visibilities.launcher = true;
            else if (dragY > Config.launcher.dragThreshold)
                visibilities.launcher = false;
        }

        if (visibilities.wallpaperLauncher && inBottomPanel(panels.wallpaperSelector, x, y))
            wallpaperShortcutActive = false;

        // Peek dashboard on hover
        const showDashboard = Config.dashboard.showOnHover && inTopPanel(panels.dashboard, x, y);
        panels.dashboard.hovered = showDashboard && !visibilities.dashboard;

        // Show/hide dashboard on drag (for touchscreen devices)
        if (pressed && inTopPanel(panels.dashboard, dragStart.x, dragStart.y) && withinPanelWidth(panels.dashboard, x, y)) {
            if (dragY > Config.dashboard.dragThreshold)
                visibilities.dashboard = true;
            else if (dragY < -Config.dashboard.dragThreshold)
                visibilities.dashboard = false;
        }

        // Show/hide qspanel hover peek from the right edge when bottom panel is off
        const _bottomPanelOff = !(Config.bar.bottomPanel && Config.bar.bottomPanel.enabled !== undefined ? Config.bar.bottomPanel.enabled : true);
        if (_bottomPanelOff && !visibilities.qspanel && !qspanelShortcutActive) {
            panels.qspanel.hovered = inRightPanel(panels.qspanel, x, y);
        } else if (!_bottomPanelOff) {
            panels.qspanel.hovered = false;
        }

        // Show bottomPanel on hover (suppressed while powermenu/power menu is open)
        const showBottomPanel = !visibilities.powermenu && root.inBottomPanelArea(x, y);

        // Always update visibility based on hover if not in shortcut mode
        if (!bottomPanelShortcutActive) {
            visibilities.bottomPanel = showBottomPanel;
        } else if (showBottomPanel) {
            // If hovering over bottomPanel area while in shortcut mode, transition to hover control
            bottomPanelShortcutActive = false;
        }

        // Show popouts on hover
        if (x < bar.implicitWidth) {
            bar.checkPopout(y);
        } else if (inPopout(x, y)) {
            // Mouse is inside or transitioning into the popout menu — keep open!
        } else {
            // Tray menus close only when clicked outside or on the icon again
            if (!popouts.currentName.startsWith("traymenu")) {
                popouts.hasCurrent = false;
                bar.closeTray();
            }
        }
    }

    // Monitor individual visibility changes
    Connections {
        function onLauncherChanged() {
            if (root.visibilities.launcher) {
                root.launcherHoverDisabled = false;
            } else {
                // If launcher is hidden, clear shortcut flags for dashboard and OSD
                root.dashboardShortcutActive = false;
                root.flyoutsShortcutActive = false;
                root.qspanelShortcutActive = false;
                root.wallpaperShortcutActive = false;

                // Disable hover activation if mouse is still in the launcher area
                if (root.inBottomPanel(root.panels.launcher, root.mouseX, root.mouseY))
                    root.launcherHoverDisabled = true;

                // Also hide dashboard and OSD if they're not being hovered
                const inDashboardArea = root.inTopPanel(root.panels.dashboard, root.mouseX, root.mouseY);
                const inOsdArea = root.inRightPanel(root.panels.flyoutsWrapper, root.mouseX, root.mouseY);

                if (!inDashboardArea) {
                    root.panels.dashboard.hovered = false;
                }
                if (!inOsdArea) {
                    root.visibilities.flyouts = false;
                    root.panels.flyouts.hovered = false;
                }
            }
        }

        function onDashboardChanged() {
            if (root.visibilities.dashboard) {
                // Dashboard became visible, immediately check if this should be shortcut mode
                const inDashboardArea = root.inTopPanel(root.panels.dashboard, root.mouseX, root.mouseY);
                if (!inDashboardArea) {
                    root.dashboardShortcutActive = true;
                }
            } else {
                // Dashboard hidden, clear shortcut flag
                root.dashboardShortcutActive = false;
            }
        }

        function onFlyoutsChanged() {
            if (root.visibilities.flyouts) {
                // OSD became visible, immediately check if this should be shortcut mode
                const inOsdArea = root.inRightPanel(root.panels.flyoutsWrapper, root.mouseX, root.mouseY);
                if (!inOsdArea) {
                    root.flyoutsShortcutActive = true;
                }
            } else {
                // OSD hidden, clear shortcut flag
                root.flyoutsShortcutActive = false;
            }
        }

        function onQspanelChanged() {
            if (root.visibilities.qspanel) {
                // Utilities became visible, immediately check if this should be shortcut mode
                const inUtilitiesArea = root.inRightPanel(root.panels.qspanel, root.mouseX, root.mouseY);
                if (!inUtilitiesArea) {
                    root.qspanelShortcutActive = true;
                }
            } else {
                // Utilities hidden, clear shortcut flag
                root.qspanelShortcutActive = false;
            }
        }

        function onBottomPanelChanged() {
            if (root.visibilities.bottomPanel) {
                const inPanel = root.inBottomPanelArea(root.mouseX, root.mouseY);
                if (!inPanel) {
                    root.bottomPanelShortcutActive = true;
                }
            } else {
                root.bottomPanelShortcutActive = false;
            }
        }

        function onPowermenuChanged() {
            if (root.visibilities.powermenu) {
                root.visibilities.bottomPanel = false;
                root.bottomPanelShortcutActive = false;
            }
        }

        function onWallpaperLauncherChanged() {
            if (root.visibilities.wallpaperLauncher) {
                const inWallpaperArea = root.inBottomPanel(root.panels.wallpaperSelector, root.mouseX, root.mouseY);
                if (!inWallpaperArea)
                    root.wallpaperShortcutActive = true;
            } else {
                root.wallpaperShortcutActive = false;
            }
        }

        target: root.visibilities
    }
}
