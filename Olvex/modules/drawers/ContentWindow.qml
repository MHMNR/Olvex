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
        for (const panel of ["dashboard", "launcher", "session", "sidebar"])
            if (contentItem.Config[panel].enabled)
                thresholds.push(contentItem.Config[panel].dragThreshold);
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

    mask: (morph.active || visibilities.utilities || panels.contextMenuVisible || visibilities.launcher || visibilities.wallpaperLauncher) ? null : regions

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
        layer.enabled: root.effectLayerActive
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

            BlobGroup {
                id: osdGroup
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
                x: panels.sessionWrapper.x + panels.session.x + panels.x
                implicitWidth: visibilities.session ? panels.session.width : 0
                implicitHeight: visibilities.session ? panels.session.height : 0
            }

            PanelBg {
                id: osdBg

                radius: safeBorder.floating ? Tokens.rounding.large * 1.5 : Tokens.rounding.large
                group: safeBorder.floating ? osdGroup : blobGroup
                exclude: [popoutBg]
                panel: panels.osdWrapper
                deformAmount: 0.1
                x: panels.osdWrapper.x + panels.osd.x + panels.x
                y: panels.osdWrapper.y + panels.osd.y + panels.y
                implicitWidth: panels.osd.width
                implicitHeight: panels.osd.height
                opacity: panels.osd.opacity
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

    Item {
        id: revealContainer
        anchors.fill: parent
        opacity: isVisible ? 1 : 0

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
                osd.transform: Matrix4x4 {
                    matrix: osdBg.deformMatrix
                }
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
                    x: root.isVisible ? 0 : -30
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

        // Dismiss layer: closes QS panel when clicking outside it
        MouseArea {
            anchors.fill: parent
            enabled: visibilities.utilities && !morph.active
            hoverEnabled: false
            z: 50 // above panels (z:0) but below morph (z:1000)
            propagateComposedEvents: true
            onPressed: mouse => {
                // map utilities panel rect to root coordinates
                const util = panels.utilities;
                const mapped = util.mapToItem(revealContainer, 0, 0);
                const inUtil = mouse.x >= mapped.x && mouse.x <= mapped.x + util.width && mouse.y >= mapped.y && mouse.y <= mapped.y + util.height;

                // also exclude the bottom panel so toggle buttons can receive clicks
                const bp = panels.bottomPanel;
                const bpMapped = bp.mapToItem(revealContainer, 0, 0);
                const inBottomPanel = mouse.x >= bpMapped.x && mouse.x <= bpMapped.x + bp.width && mouse.y >= bpMapped.y && mouse.y <= bpMapped.y + bp.height;

                // also exclude clipboard panel
                const cb = panels.clipboard;
                const cbMapped = cb.mapToItem(revealContainer, 0, 0);
                const inClipboard = cb.visible && mouse.x >= cbMapped.x && mouse.x <= cbMapped.x + cb.width && mouse.y >= cbMapped.y && mouse.y <= cbMapped.y + cb.height;

                if (!inUtil && !inBottomPanel && !inClipboard) {
                    visibilities.utilities = false;
                    mouse.accepted = true;
                } else {
                    mouse.accepted = false;
                }
            }
            onClicked: mouse => {
                mouse.accepted = false;
            }
        }

        // Dismiss layer: closes clipboard when clicking outside it
        MouseArea {
            anchors.fill: parent
            enabled: visibilities.clipboard && !morph.active
            hoverEnabled: false
            z: 49
            propagateComposedEvents: true
            onPressed: mouse => {
                const cb = panels.clipboard;
                const cbMapped = cb.mapToItem(revealContainer, 0, 0);
                const inClipboard = mouse.x >= cbMapped.x && mouse.x <= cbMapped.x + cb.width && mouse.y >= cbMapped.y && mouse.y <= cbMapped.y + cb.height;
                const bp = panels.bottomPanel;
                const bpMapped = bp.mapToItem(revealContainer, 0, 0);
                const inBottomPanel = mouse.x >= bpMapped.x && mouse.x <= bpMapped.x + bp.width && mouse.y >= bpMapped.y && mouse.y <= bpMapped.y + bp.height;
                if (!inClipboard && !inBottomPanel) {
                    visibilities.clipboard = false;
                    mouse.accepted = true;
                } else {
                    mouse.accepted = false;
                }
            }
            onClicked: mouse => {
                mouse.accepted = false;
            }
        }

        // Dismiss layer: closes launcher when clicking outside it
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
                    mouse.accepted = true;
                } else {
                    mouse.accepted = false;
                }
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
                    mouse.accepted = true;
                } else {
                    mouse.accepted = false;
                }
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
