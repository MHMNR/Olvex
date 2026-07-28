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
    property bool osdShortcutActive
    property bool utilitiesShortcutActive: false
    property bool bottomPanelShortcutActive: false
    property bool wallpaperShortcutActive: false
    property bool launcherHoverDisabled: false

    readonly property int floatingGap: safeBorder.floating ? 5 : 0
    readonly property real hoverTolerance: root.borderThickness + 20
    readonly property real verticalTolerance: root.borderThickness + floatingGap + 8

    function inBottomPanelArea(x: real, y: real): bool {
        if (visibilities.bottomPanel) {
            return y >= height - 80 - verticalTolerance && x >= bar.implicitWidth;
        }
        const bottomEdge = height - 8;
        return y >= bottomEdge && x >= bar.implicitWidth;
    }

    function withinPanelHeight(panel: Item, x: real, y: real): bool {
        const panelY = root.borderThickness + floatingGap + panel.y;
        return y >= panelY - verticalTolerance && y <= panelY + panel.height + verticalTolerance;
    }

    function withinPanelWidth(panel: Item, x: real, y: real): bool {
        const panelX = bar.implicitWidth + floatingGap + panel.x;
        return x >= panelX - safeBorder.rounding - hoverTolerance && x <= panelX + panel.width + safeBorder.rounding + hoverTolerance;
    }

    function inLeftPanel(panel: Item, x: real, y: real): bool {
        return x < bar.implicitWidth + floatingGap + panel.x + panel.width + hoverTolerance && withinPanelHeight(panel, x, y);
    }

    function inRightPanel(panel: Item, x: real, y: real): bool {
        return x > Math.min(width - safeBorder.minThickness - floatingGap, bar.implicitWidth + floatingGap + panel.x) - hoverTolerance && withinPanelHeight(panel, x, y);
    }

    function inTopPanel(panel: Item, x: real, y: real): bool {
        const panelHeight = panel.height * (1 - (panel.offsetScale ?? 0)); // qmllint disable missing-property
        return y < Math.max(safeBorder.minThickness + floatingGap, safeBorder.thickness + floatingGap + panelHeight) + verticalTolerance && withinPanelWidth(panel, x, y);
    }

    function inBottomPanel(panel: Item, x: real, y: real, isCorner = false): bool {
        const panelHeight = panel.height * (1 - (panel.offsetScale ?? 0)); // qmllint disable missing-property
        return y > height - Math.max(safeBorder.minThickness + floatingGap, safeBorder.thickness + floatingGap + panelHeight) - (isCorner ? safeBorder.rounding : 0) - verticalTolerance && withinPanelWidth(panel, x, y);
    }

    function onWheel(event: WheelEvent): void {
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
        dragStart = Qt.point(event.x, event.y);

        // Click peeked dashboard to open
        if (Config.dashboard.showOnHover && inTopPanel(panels.dashboard, event.x, event.y) && !visibilities.dashboard) {
            visibilities.dashboard = true;
            dashboardShortcutActive = true;
            event.accepted = true;
            return;
        }

        // Click peeked utilities to open (only when bottom panel is off and utilities is peeking)
        const bottomPanelOff = !(Config.bar.bottomPanel?.enabled ?? true);
        if (bottomPanelOff && panels.utilities.hovered && !visibilities.utilities
                && inBottomPanel(panels.utilities, event.x, event.y, true)) {
            visibilities.utilities = true;
            utilitiesShortcutActive = true;
            event.accepted = true;
            return;
        }

        // Bottom-right corner click opens utilities (only when bottom panel is off)
        if (bottomPanelOff && !visibilities.utilities
                && event.x >= width - 60 && event.y >= height - 60) {
            visibilities.utilities = true;
            utilitiesShortcutActive = true;
            event.accepted = true;
            return;
        }

        // NUCLEAR FIX: If dashboard is open, DO NOT accept clicks in the main area.
        // This forces events to propagate to the buttons.
        if (visibilities.dashboard && event.y > root.borderThickness && event.x > bar.implicitWidth) {
            event.accepted = false;
            return;
        }

        // Pass clicks through to launcher UI (wallpaper tabs, items, search, etc.)
        if (visibilities.launcher
                && inBottomPanel(panels.launcher, event.x, event.y)
                && withinPanelWidth(panels.launcher, event.x, event.y)) {
            event.accepted = false;
            return;
        }

        if (event.x < bar.implicitWidth) {
            // Bar music pill uses child MouseAreas — parent must not steal presses
            if (Players.active) {
                event.accepted = false;
                return;
            }
            event.accepted = true;
        } else if (!visibilities.dashboard) {
            event.accepted = true;
        } else {
            event.accepted = false;
        }
    }
    onContainsMouseChanged: {
        if (!containsMouse) {
            // Only hide if not activated by shortcut
            if (!osdShortcutActive) {
                visibilities.osd = false;
                root.panels.osd.hovered = false;
            }

            if (!dashboardShortcutActive) {
                visibilities.dashboard = false;
            }
            root.panels.dashboard.hovered = false;

            // Close utilities on hover-away
            if (!utilitiesShortcutActive)
                visibilities.utilities = false;
            root.panels.utilities.hovered = false;

            if (!bottomPanelShortcutActive)
                visibilities.bottomPanel = false;

            if (!popouts.currentName.startsWith("traymenu") || ((popouts.current as StackView)?.depth ?? 0) <= 1) {
                popouts.hasCurrent = false;
                bar.closeTray();
            }

            if (Config.bar.showOnHover)
                bar.isHovered = false;
        }
    }

    onPositionChanged: event => {
        if (popouts.isDetached)
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
        const showOsd = inRightPanel(panels.osdWrapper, x, y);

        // Always update visibility based on hover if not in shortcut mode
        if (!osdShortcutActive) {
            visibilities.osd = showOsd;
            root.panels.osd.hovered = showOsd;
        } else if (showOsd) {
            // If hovering over OSD area while in shortcut mode, transition to hover control
            osdShortcutActive = false;
            root.panels.osd.hovered = true;
        }

        // Show/hide session on drag
        if (pressed && (dragStart.x > width - 50)) {
            if (dragX > Config.session.dragThreshold)
                visibilities.session = false;
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

        // Always update visibility based on hover if not in shortcut mode
        if (!dashboardShortcutActive) {
            panels.dashboard.hovered = showDashboard;
            if (!showDashboard) {
                visibilities.dashboard = false;
            }
        } else if (showDashboard) {
            // If hovering over dashboard area while in shortcut mode, transition to hover control
            dashboardShortcutActive = false;
            panels.dashboard.hovered = true;
        }

        // Show/hide dashboard on drag (for touchscreen devices)
        if (pressed && inTopPanel(panels.dashboard, dragStart.x, dragStart.y) && withinPanelWidth(panels.dashboard, x, y)) {
            if (dragY > Config.dashboard.dragThreshold)
                visibilities.dashboard = true;
            else if (dragY < -Config.dashboard.dragThreshold)
                visibilities.dashboard = false;
        }

        // Show/hide utilities hover peek when bottom panel is off
        const _bottomPanelOff = !(Config.bar.bottomPanel?.enabled ?? true);
        if (_bottomPanelOff && !visibilities.utilities && !utilitiesShortcutActive) {
            const inUtilitiesHover = inBottomPanel(panels.utilities, x, y, true);
            panels.utilities.hovered = inUtilitiesHover;
        } else if (!_bottomPanelOff) {
            panels.utilities.hovered = false;
        }

        // Show bottomPanel on hover (suppressed while session/power menu is open)
        const showBottomPanel = !visibilities.session && root.inBottomPanelArea(x, y);

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
        } else if ((!popouts.currentName.startsWith("traymenu") || ((popouts.current as StackView)?.depth ?? 0) <= 1) && !inLeftPanel(panels.popoutsWrapper, x, y)) {
            popouts.hasCurrent = false;
            bar.closeTray();
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
                root.osdShortcutActive = false;
                root.utilitiesShortcutActive = false;
                root.wallpaperShortcutActive = false;

                // Disable hover activation if mouse is still in the launcher area
                if (root.inBottomPanel(root.panels.launcher, root.mouseX, root.mouseY))
                    root.launcherHoverDisabled = true;

                // Also hide dashboard and OSD if they're not being hovered
                const inDashboardArea = root.inTopPanel(root.panels.dashboard, root.mouseX, root.mouseY);
                const inOsdArea = root.inRightPanel(root.panels.osdWrapper, root.mouseX, root.mouseY);

                if (!inDashboardArea) {
                    root.visibilities.dashboard = false;
                    root.panels.dashboard.hovered = false;
                }
                if (!inOsdArea) {
                    root.visibilities.osd = false;
                    root.panels.osd.hovered = false;
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

        function onOsdChanged() {
            if (root.visibilities.osd) {
                // OSD became visible, immediately check if this should be shortcut mode
                const inOsdArea = root.inRightPanel(root.panels.osdWrapper, root.mouseX, root.mouseY);
                if (!inOsdArea) {
                    root.osdShortcutActive = true;
                }
            } else {
                // OSD hidden, clear shortcut flag
                root.osdShortcutActive = false;
            }
        }

        function onUtilitiesChanged() {
            if (root.visibilities.utilities) {
                // Utilities became visible, immediately check if this should be shortcut mode
                const inUtilitiesArea = root.inBottomPanel(root.panels.utilities, root.mouseX, root.mouseY, true);
                if (!inUtilitiesArea) {
                    root.utilitiesShortcutActive = true;
                }
            } else {
                // Utilities hidden, clear shortcut flag
                root.utilitiesShortcutActive = false;
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

        function onSessionChanged() {
            if (root.visibilities.session) {
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
