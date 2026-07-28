pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Olvex.Blobs
import Olvex.Config
import qs.components
import qs.components.containers
import qs.modules.bar
import qs.services
import QtCore
import "../utilities/cards" as Cards

StyledWindow {
    id: root

    readonly property var safeBorder: (contentItem && contentItem.Config && contentItem.Config.border) ? contentItem.Config.border : {
        thickness: 0,
        rounding: 0,
        minThickness: 0,
        floating: false,
        smoothing: 0,
        clampedThickness: 0
    }

    readonly property bool _initApps: {
        Qt.application.name = "Olvex";
        Qt.application.organization = "Olvex";
        return true;
    }

    name: "drawers"
    readonly property alias bar: bar
    readonly property alias interactionWrapper: interactions
    readonly property alias visibilities: visibilities

    // OSK registers itself here so its clicks don't close panels
    property var oskWindow: null

    readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
    readonly property bool hasSpecialWorkspace: (monitor?.lastIpcObject.specialWorkspace?.name.length ?? 0) > 0
    readonly property bool hasFullscreen: {
        if (hasSpecialWorkspace) {
            const specialName = monitor?.lastIpcObject.specialWorkspace?.name;
            if (!specialName)
                return false;
            const specialWs = Hypr.workspaces.values.find(ws => ws.name === specialName);
            return specialWs?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false;
        }
        return monitor?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false;
    }
    property real borderThickness: hasFullscreen ? 0 : safeBorder.thickness
    readonly property real borderLayoutThickness: hasFullscreen ? 0 : safeBorder.thickness
    property real borderRounding: hasFullscreen ? 0 : safeBorder.rounding
    property real shadowOpacity: hasFullscreen ? 0 : 0.7
    readonly property bool effectLayerActive: shadowOpacity > 0.01 && (morph.active || visibilities.utilities || visibilities.dashboard || visibilities.launcher || visibilities.wallpaperLauncher || visibilities.session || visibilities.sidebar || visibilities.clipboard || panels.popouts.hasCurrent || panels.contextMenuVisible)
    readonly property bool shellMotionActive: shellMotionGrace.running

    property real bottomBorderHeight: {
        if (hasFullscreen)
            return 0;
        // Expand blob border to 80px whenever panel is visible (any mode)
        if (panels.bottomPanelVisible)
            return 80;
        return root.borderThickness;
    }

    Behavior on bottomBorderHeight {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    readonly property int dragMaskPadding: {
        if (focusGrab.active || panels.popouts.isDetached)
            return 0;

        if (monitor?.lastIpcObject.specialWorkspace?.name || monitor?.activeWorkspace.lastIpcObject.windows > 0)
            return 0;

        const thresholds = [];
        for (const panel of ["dashboard", "launcher", "session", "sidebar", "utilities"])
            if (contentItem.Config[panel]?.enabled)
                thresholds.push(contentItem.Config[panel].dragThreshold ?? 40);
        return Math.max(...thresholds);
    }

    onHasFullscreenChanged: {
        visibilities.launcher = false;
        visibilities.session = false;
        visibilities.dashboard = false;
    }

    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: focusGrab.active ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property bool launchTransition: false
    Timer {
        id: launchTransitionTimer
        interval: 350
        onTriggered: root.launchTransition = false
    }

    Timer {
        id: shellMotionGrace
        interval: 520
        repeat: false
    }

    function pulseShellMotion(): void {
        shellMotionGrace.restart();
        Visibilities.pulseShellMotion(shellMotionGrace.interval);
    }

    Connections {
        target: visibilities

        function onUtilitiesChanged(): void { root.pulseShellMotion(); }
        function onDashboardChanged(): void { root.pulseShellMotion(); }
        function onLauncherChanged(): void { root.pulseShellMotion(); }
        function onWallpaperLauncherChanged(): void { root.pulseShellMotion(); }
        function onSessionChanged(): void { root.pulseShellMotion(); }
        function onSidebarChanged(): void { root.pulseShellMotion(); }
        function onClipboardChanged(): void { root.pulseShellMotion(); }
    }

    Connections {
        target: panels.popouts

        function onHasCurrentChanged(): void { root.pulseShellMotion(); }
    }

    Connections {
        target: panels

        function onContextMenuVisibleChanged(): void { root.pulseShellMotion(); }
    }

    mask: (hasFullscreen || morph.active || panels.contextMenuVisible || visibilities.launcher || visibilities.wallpaperLauncher) ? null : regions

    Regions {
        id: regions
        bar: bar
        panels: panels
        win: root
        morph: morph
    }

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    Behavior on borderThickness {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on borderRounding {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on shadowOpacity {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (visibilities.wallpaperLauncher)
                visibilities.wallpaperLauncher = false;
            else if (visibilities.launcher)
                visibilities.launcher = false;
            else if (visibilities.dashboard)
                visibilities.dashboard = false;
            else if (visibilities.utilities)
                visibilities.utilities = false;
            else if (visibilities.clipboard)
                visibilities.clipboard = false;
            else if (visibilities.sidebar)
                visibilities.sidebar = false;
            else if (visibilities.session)
                visibilities.session = false;
            else if (panels.popouts.hasCurrent) {
                panels.popouts.hasCurrent = false;
                bar.closeTray();
            }
        }
    }

    HyprlandFocusGrab {
        id: focusGrab

        active: (visibilities.launcher && root.contentItem?.Config?.launcher?.enabled) || (visibilities.wallpaperLauncher && root.contentItem?.Config?.launcher?.enabled) || (visibilities.session && root.contentItem?.Config?.session?.enabled) || (visibilities.sidebar && root.contentItem?.Config?.sidebar?.enabled) || (visibilities.dashboard && root.contentItem?.Config?.dashboard?.enabled) || (panels.popouts.currentName.startsWith("traymenu") && (panels.popouts.current as StackView)?.depth > 1) || visibilities.utilities || visibilities.clipboard
        windows: root.oskWindow && visibilities.osk ? [root, root.oskWindow] : [root]
        onActiveChanged: {
            if (active) {
                root.launchTransition = true;
                launchTransitionTimer.restart();
            }
        }
        onCleared: {
            if (root.launchTransition)
                return;
            visibilities.launcher = false;
            visibilities.wallpaperLauncher = false;
            visibilities.session = false;
            visibilities.sidebar = false;
            visibilities.dashboard = false;
            panels.popouts.hasCurrent = false;
            bar.closeTray();
        }
    }

    StyledRect {
        anchors.fill: parent
        opacity: visibilities.session && Config.session.enabled ? 0.5 : 0
        color: Colours.palette.m3scrim

        Behavior on opacity {
            Anim {}
        }
    }

    Item {
        anchors.fill: parent
        opacity: Colours.transparencyEnabled ? Colours.transparencyBase : 1
        layer.enabled: root.effectLayerActive && !root.shellMotionActive
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 15
            shadowColor: Qt.alpha(Colours.palette.m3shadow, Math.max(0, root.shadowOpacity))
        }

        Item {
            id: blobContainer
            anchors.fill: parent

            // Background fade-in on unlock
            opacity: root.isVisible ? 1 : 0
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: 300
                    }
                    NumberAnimation {
                        duration: 1000
                        easing.type: Easing.OutCubic
                    }
                }
            }

            BlobGroup {
                id: blobGroup
                color: Colours.palette.m3surface
                smoothing: safeBorder.smoothing
                Behavior on color {
                    CAnim {}
                }
            }

            BlobGroup {
                id: drawerGroup
                color: Colours.palette.m3surface
                smoothing: safeBorder.smoothing
                Behavior on color {
                    CAnim {}
                }
            }

            BlobInvertedRect {
                anchors.fill: parent
                anchors.margins: -50 // Make border thicker to smooth out bulge from closed drawers
                group: blobGroup
                radius: root.borderRounding
                borderLeft: bar.implicitWidth - anchors.margins
                borderRight: root.borderThickness - anchors.margins
                borderTop: root.borderThickness - anchors.margins
                borderBottom: root.bottomBorderHeight - anchors.margins
            }

            PanelBg {
                id: dashBg

                panel: panels.dashboard
                deformAmount: 0.1
            }

            PanelBg {
                id: launcherBg

                panel: panels.launcher
                deformAmount: 0.1
            }

            PanelBg {
                id: wallpaperSelectorBg

                panel: panels.wallpaperSelector
                deformAmount: 0.1
            }

            PanelBg {
                id: sessionBg

                panel: panels.sessionWrapper
                deformAmount: 0.2
                x: visibilities.session ? 0 : panels.sessionWrapper.x + panels.session.x + panels.x
                y: visibilities.session ? 0 : panels.sessionWrapper.y + panels.session.y + panels.y
                implicitWidth: visibilities.session ? root.width : 0
                implicitHeight: visibilities.session ? root.height : 0
                radius: visibilities.session ? 0 : Tokens.rounding.large
            }

            PanelBg {
                id: osdBg

                panel: panels.osdWrapper
                deformAmount: 0.1
            }

            PanelBg {
                id: notifsBg

                panel: panels.notifications
            }

            PanelBg {
                id: utilsBg

                panel: panels.utilities
                deformAmount: 0.15
            }

            PanelBg {
                id: popoutBg

                panel: panels.popoutsWrapper
                deformAmount: panels.popouts.isDetached ? 0.05 : panels.popouts.hasCurrent ? 0.08 : 0.05
            }
        }
    }

    DrawerVisibilities {
        id: visibilities

        Component.onCompleted: {
            Visibilities.load(root.screen, this);
            if (pinnedAppsSettings.pinnedApps !== undefined) {
                const loaded = pinnedAppsSettings.pinnedApps;
                if (loaded) {
                    visibilities.pinnedApps = loaded;
                }
            }
        }

        onPinnedAppsChanged: {
            const currentSettings = pinnedAppsSettings.pinnedApps || [];
            const currentPinned = visibilities.pinnedApps || [];
            let changed = currentSettings.length !== currentPinned.length;
            if (!changed) {
                for (let i = 0; i < currentPinned.length; i++) {
                    if (currentPinned[i] !== currentSettings[i]) {
                        changed = true;
                        break;
                    }
                }
            }
            if (changed) {
                const arr = [];
                for (let i = 0; i < currentPinned.length; i++) {
                    arr.push(currentPinned[i]);
                }
                pinnedAppsSettings.pinnedApps = arr;
            }
        }
    }

    Settings {
        id: pinnedAppsSettings
        category: "DrawerVisibilities"
        property var pinnedApps: []
    }

    // Entrance Animation State
    readonly property bool isVisible: !LockState.locked

    // ── Stop rendering entirely while locked ────────────────────────────────
    // The lock surface fully occludes this window, but Qt keeps compositing it
    // (opacity:0 ≠ hidden), so any continuously-animating child — e.g. the media
    // overlay's WavyLine progress bar while music plays — keeps forcing a ~144Hz
    // GPU present that competes with the lock screen on the shared iGPU and drops
    // frames across every lock animation. Unmap the surface a beat after locking
    // (the lock surface is already on top, so no flash) so this window costs zero
    // until unlock, then re-map instantly so the entrance fade-in still plays.
    // Mirrors the bar's own visible:false self-hide (line ~487).
    property bool surfaceMapped: true
    visible: surfaceMapped

    Timer {
        id: lockHideGrace
        interval: 200
        onTriggered: root.surfaceMapped = false
    }

    Connections {
        target: LockState
        function onLockedChanged(): void {
            if (LockState.locked) {
                lockHideGrace.restart();
            } else {
                lockHideGrace.stop();
                root.surfaceMapped = true;
            }
        }
    }

    Item {
        id: revealContainer
        anchors.fill: parent
        opacity: isVisible ? 1 : 0

        // Full-screen live capture used as the backdrop-blur source for OSD
        // sliders. Invisible here — each slider crops its own region via
        // ShaderEffectSource.sourceRect using mapToItem(osdScreenCapture).
        // live only while the OSD is actually on screen to save bandwidth.
        ScreencopyView {
            id: osdScreenCapture
            anchors.fill: parent
            captureSource: root.screen
            live: visibilities.osd
            visible: false
        }

        // Removed global behavior to fix jitter on QS Panel and other drawers

        Interactions {
            id: interactions

            screen: root.screen
            popouts: panels.popouts
            visibilities: visibilities
            panels: panels
            bar: bar
            borderThickness: root.borderLayoutThickness
            fullscreen: root.hasFullscreen
            safeBorder: root.safeBorder

            Panels {
                id: panels
                z: visibilities.session ? 100 : 0

                screen: root.screen
                visibilities: visibilities
                bar: bar
                borderThickness: root.borderThickness
                safeBorder: root.safeBorder
                osdScreenCapture: osdScreenCapture

                // Wire the flying-icon morph overlay back into Panels so GridAppItem → Panels.triggerAppMorph reaches it
                appLaunchMorph: appLaunchMorphId

                utilities.deformMatrix: utilsBg.rawDeformMatrix

                dashboard.transform: Matrix4x4 {
                    matrix: dashBg.deformMatrix
                }
                launcher.transform: Matrix4x4 {
                    matrix: launcherBg.deformMatrix
                }
                wallpaperSelector.transform: Matrix4x4 {
                    matrix: wallpaperSelectorBg.deformMatrix
                }
                session.transform: Matrix4x4 {
                    matrix: sessionBg.deformMatrix
                }
                // No deform on the OSD content: its backing blob (osdBg) is now
                // invisible, so warping the sliders to follow the blob's liquid
                // spring-settle just distorts their rounded bottoms with nothing
                // to justify it (the "goes buggy ~1s after open"). The sliders
                // draw their own clean shape; leave them un-deformed.
                notifications.transform: Matrix4x4 {
                    matrix: notifsBg.deformMatrix
                }
                utilities.transform: Matrix4x4 {
                    matrix: utilsBg.deformMatrix
                }
                popouts.transform: Matrix4x4 {
                    matrix: popoutBg.deformMatrix
                }
            }

            BarWrapper {
                id: bar

                anchors.top: parent.top
                anchors.bottom: parent.bottom

                screen: root.screen
                visibilities: visibilities
                popouts: panels.popouts
                mediaMorph: morph

                fullscreen: root.hasFullscreen
                safeBorder: root.safeBorder
                enabled: !visibilities.session
                visible: opacity > 0

                // Staggered entry for bar
                opacity: visibilities.session ? 0 : (root.isVisible ? 1 : 0)
                transform: Translate {
                    x: root.isVisible ? 0 : -120
                    Behavior on x {
                        SequentialAnimation {
                            PauseAnimation {
                                duration: 50
                            }
                            NumberAnimation {
                                duration: 800
                                easing.type: Easing.OutExpo
                            }
                        }
                    }
                }
                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation {
                            duration: 50
                        }
                        NumberAnimation {
                            duration: 600
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Component.onCompleted: Visibilities.bars.set(root.screen, this)
            }
        }

        // Dismiss QS panel / clipboard when clicking outside — logic moved to Interactions.qml
        // so event.accepted=false properly reaches app windows through the null mask.

        // Dismiss layer: closes launcher when clicking outside it
        // NOTE: launcher dismiss logic lives in Interactions.qml onPressed so that
        // event.accepted=false properly reaches underlying app windows. This layer
        // only exists as a safety fallback for edge cases where Interactions doesn't fire.
        MouseArea {
            anchors.fill: parent
            enabled: visibilities.launcher && !morph.active
            hoverEnabled: false
            z: 48
            propagateComposedEvents: true
            onPressed: mouse => {
                const launcher = panels.launcher;
                const mapped = launcher.mapToItem(revealContainer, 0, 0);
                const inLauncher = mouse.x >= mapped.x && mouse.x <= mapped.x + launcher.width && mouse.y >= mapped.y && mouse.y <= mapped.y + launcher.height;
                const bp = panels.bottomPanel;
                const bpMapped = bp.mapToItem(revealContainer, 0, 0);
                const inBottomPanel = mouse.x >= bpMapped.x && mouse.x <= bpMapped.x + bp.width && mouse.y >= bpMapped.y && mouse.y <= bpMapped.y + bp.height;

                let inOsIcon = false;
                if (bar.osIcon) {
                    const osMapped = bar.osIcon.mapToItem(revealContainer, 0, 0);
                    inOsIcon = mouse.x >= osMapped.x && mouse.x <= osMapped.x + bar.osIcon.width && mouse.y >= osMapped.y && mouse.y <= osMapped.y + bar.osIcon.height;
                }

                if (!inLauncher && !inBottomPanel && !inOsIcon) {
                    visibilities.launcher = false;
                }
                // Always propagate — Interactions already handled the accept/reject decision
                mouse.accepted = false;
            }
            onClicked: mouse => {
                mouse.accepted = false;
            }
        }

        // Dismiss layer: closes wallpaper selector when clicking outside it
        MouseArea {
            anchors.fill: parent
            enabled: visibilities.wallpaperLauncher && !morph.active
            hoverEnabled: false
            z: 47
            propagateComposedEvents: true
            onPressed: mouse => {
                const ws = panels.wallpaperSelector;
                const mapped = ws.mapToItem(revealContainer, 0, 0);
                const inWS = mouse.x >= mapped.x && mouse.x <= mapped.x + ws.width && mouse.y >= mapped.y && mouse.y <= mapped.y + ws.height;
                const bp = panels.bottomPanel;
                const bpMapped = bp.mapToItem(revealContainer, 0, 0);
                const inBottomPanel = mouse.x >= bpMapped.x && mouse.x <= bpMapped.x + bp.width && mouse.y >= bpMapped.y && mouse.y <= bpMapped.y + bp.height;

                let inOsIcon = false;
                if (bar.osIcon) {
                    const osMapped = bar.osIcon.mapToItem(revealContainer, 0, 0);
                    inOsIcon = mouse.x >= osMapped.x && mouse.x <= osMapped.x + bar.osIcon.width && mouse.y >= osMapped.y && mouse.y <= osMapped.y + bar.osIcon.height;
                }

                if (!inWS && !inBottomPanel && !inOsIcon) {
                    visibilities.wallpaperLauncher = false;
                }
                // Always propagate
                mouse.accepted = false;
            }
            onClicked: mouse => {
                mouse.accepted = false;
            }
        }

        Cards.MediaMorphOverlay {
            id: morph

            screen: root.screen
        }

        // Flying-icon overlay for launcher → pinned-dock morph
        AppLaunchMorph {
            id: appLaunchMorphId

            visibilities: visibilities
            bottomPanel: panels.bottomPanel
            pinnedLayout: panels.pinnedLayout
        }
    }

    component PanelBg: BlobRect {
        required property Item panel
        property real deformAmount: 0.15
        readonly property bool active: panel.visible

        group: root.safeBorder.floating ? drawerGroup : blobGroup
        x: panel.x + panels.x
        y: panel.y + panels.y
        implicitWidth: active ? panel.width : 0
        implicitHeight: active ? panel.height : 0
        radius: Tokens.rounding.large
        deformScale: (deformAmount * Config.appearance.deformScale) / 10000
    }
}
