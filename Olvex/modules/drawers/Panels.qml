import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Olvex.Config
import Olvex.Services
import qs.components
import qs.services
import qs.modules.bar as Bar
import qs.modules.dashboard as Dashboard
import qs.modules.launcher as Launcher
import qs.modules.notifications as Notifications
import qs.modules.osd as Osd
import qs.modules.session as Session
import qs.modules.utilities as Utilities
import qs.modules.bar.popouts as BarPopouts
import qs.modules.utilities.toasts as Toasts
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

    readonly property alias osd: osd
    readonly property alias osdWrapper: osdWrapper
    readonly property alias notifications: notifications
    readonly property alias session: session
    readonly property alias sessionWrapper: sessionWrapper
    readonly property alias launcher: launcher
    readonly property alias dashboard: dashboard
    readonly property alias popouts: popoutsWrapper.content
    readonly property alias popoutsWrapper: popoutsWrapper
    readonly property alias utilities: utilities
    readonly property alias toasts: toasts
    readonly property alias bottomPanel: bottomPanel
    readonly property alias clipboard: clipboard

    readonly property bool sessionVisible: session.visible

    // Expand bottom margin to 80px whenever panel is visible (any mode)
    // so the border blob expands and panel sits inside it. Only always mode
    // sets exclusiveZone=80 to push windows.
    property real bottomMargin: {
        const baseMargin = borderThickness + (((Config && ((typeof Config !== "undefined" && Config && Config.border) ? Config.border : {thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0})) ? ((typeof Config !== "undefined" && Config && Config.border) ? Config.border : {thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0}) : ({thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0})).floating ? 5 : 0);
        if (bottomPanelVisible)
            return 80 + (((Config && ((typeof Config !== "undefined" && Config && Config.border) ? Config.border : {thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0})) ? ((typeof Config !== "undefined" && Config && Config.border) ? Config.border : {thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0}) : ({thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0})).floating ? 5 : 0);
        return baseMargin;
    }

    // Bottom panel config
    readonly property bool bottomPanelEnabled: Config.bar.bottomPanel?.enabled ?? true
    readonly property string bottomPanelMode: Config.bar.bottomPanel?.visibilityMode ?? "always"

    property bool hasWindowsOverlappingPanel: false
    property bool _lastOverlapState: false
    property int _geometryStableTicks: 0
    property int geometryPollInterval: 200

    function checkOverlap() {
        const mon = Hypr.monitorFor(root.screen);
        const ws = mon?.activeWorkspace;
        const monY = mon?.lastIpcObject?.y ?? 0;
        const screenH = root.screen.height;
        const panelTop = monY + screenH - 80;
        const windows = ws?.toplevels?.values ?? [];
        for (let i = 0; i < windows.length; i++) {
            const ipc = windows[i].lastIpcObject;
            if (!ipc) continue;
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
        interval: root.geometryPollInterval
        running: bottomPanelMode === "smarthide"
        repeat: true
        onTriggered: {
            CpuProfile.bump("geometrySyncLoop");
            if (_geometryStableTicks < 2) {
                Hyprland.refreshToplevels();
                CpuProfile.bump("hyprRefreshToplevels");
            }
            const overlap = checkOverlap();
            if (overlap !== hasWindowsOverlappingPanel)
                hasWindowsOverlappingPanel = overlap;
            if (overlap === _lastOverlapState)
                _geometryStableTicks++;
            else {
                _geometryStableTicks = 0;
                _lastOverlapState = overlap;
            }
            const slow = _geometryStableTicks >= 10;
            geometryPollInterval = slow ? (hasWindowsOverlappingPanel ? 400 : 800) : 200;
        }
    }

    Connections {
        target: Hypr
        function onToplevelUpdateCounterChanged(): void {
            if (root.bottomPanelMode !== "smarthide")
                return;
            root._geometryStableTicks = 0;
            root.geometryPollInterval = 200;
            const overlap = root.checkOverlap();
            if (overlap !== root.hasWindowsOverlappingPanel)
                root.hasWindowsOverlappingPanel = overlap;
            root._lastOverlapState = overlap;
        }
    }


    // Whether the panel should be visible based on mode
    readonly property bool bottomPanelVisible: {
        if (!bottomPanelEnabled) return false;
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
        hasWindowsOverlappingPanel = checkOverlap();
        _lastOverlapState = hasWindowsOverlappingPanel;
    }

    Behavior on bottomMargin {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    anchors.fill: parent
    anchors.margins: borderThickness + (((Config && ((typeof Config !== "undefined" && Config && Config.border) ? Config.border : {thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0})) ? ((typeof Config !== "undefined" && Config && Config.border) ? Config.border : {thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0}) : ({thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0})).floating ? 5 : 0)
    anchors.bottomMargin: bottomMargin

    anchors.leftMargin: bar.implicitWidth + (((Config && ((typeof Config !== "undefined" && Config && Config.border) ? Config.border : {thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0})) ? ((typeof Config !== "undefined" && Config && Config.border) ? Config.border : {thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0}) : ({thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0})).floating ? 5 : 0)

    Item {
        id: osdWrapper

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 0
        clip: root.sessionVisible

        implicitWidth: osd.implicitWidth * (1 - osd.offsetScale)
        implicitHeight: osd.implicitHeight

        Osd.Wrapper {
            id: osd

            screen: root.screen
            visibilities: root.visibilities
            sidebarOrSessionVisible: root.sessionVisible

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
        }
    }

    Notifications.Wrapper {
        id: notifications

        visibilities: root.visibilities
        osdPanel: osdWrapper
        sessionPanel: sessionWrapper

        anchors.top: parent.top
        anchors.right: parent.right
    }

    Item {
        id: sessionWrapper

        anchors.fill: parent
        anchors.leftMargin: -bar.implicitWidth
        anchors.topMargin: -root.anchors.margins
        anchors.rightMargin: -root.anchors.margins
        anchors.bottomMargin: -root.anchors.margins
        z: 999

        Session.Wrapper {
            id: session

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
        id: utilities

        visibilities: root.visibilities
        popouts: popoutsWrapper.content

        anchors.bottom: parent.bottom
        anchors.right: parent.right
    }

    Clipboard.ClipboardPanel {
        id: clipboard

        visibilities: root.visibilities

        anchors.bottom: bottomPanel.visible ? bottomPanel.top : parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: Tokens.spacing.normal
        anchors.rightMargin: Tokens.spacing.normal

        width: Tokens.sizes.utilities.width || 380
        height: 520

        visible: root.visibilities.clipboard
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        transform: Translate {
            y: root.visibilities.clipboard ? 0 : 16
            Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        }
    }

    Toasts.Toasts {
        id: toasts

        anchors.bottom: utilities.top
        anchors.right: parent.right
        anchors.margins: Tokens.padding.normal
    }

    Item {
        id: bottomPanel

        // Anchor horizontally to cover the full width of the content area
        anchors.left: parent.left
        anchors.leftMargin: 0
        anchors.right: parent.right
        anchors.rightMargin: -(root.borderThickness + (((Config && ((typeof Config !== "undefined" && Config && Config.border) ? Config.border : {thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0})) ? ((typeof Config !== "undefined" && Config && Config.border) ? Config.border : {thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0}) : ({thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0})).floating ? 5 : 0))

        height: 80
        visible: root.bottomPanelEnabled
        // Float above content in overlay modes; behind nothing in always mode
        z: root.bottomPanelMode === "always" ? 0 : 10

        // Slide-up behavior relative to parent (which has bottomMargin)
        opacity: root.bottomPanelVisible ? 1 : 0
        y: root.bottomPanelVisible
            ? parent.height + root.bottomMargin - height
            : parent.height + root.bottomMargin

        Behavior on opacity {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        // Clean premium glassmorphic overlay for the full-width panel background
        StyledRect {
            anchors.fill: parent
            color: "transparent"

            // Pill layout container — background provided by blob border expansion
            Rectangle {
                anchors.centerIn: parent
                height: 64
                width: layout.implicitWidth + 20
                radius: 20
                color: "transparent"
                border.color: "transparent"
                border.width: 0

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: parent.radius - 1
                    color: "transparent"
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.05)
                    border.width: 1
                }

                RowLayout {
                    id: layout
                    anchors.centerIn: parent
                    spacing: 10 // Symmetrical spacing between icons

                    Repeater {
                        id: pinnedRepeater
                        model: root.visibilities.pinnedApps

                        Item {
                            id: appWrapper
                            required property string modelData
                            property var entry: {
                                const apps = DesktopEntries.applications.values;
                                for (let i = 0; i < apps.length; i++) {
                                    if (apps[i].id === modelData) return apps[i];
                                }
                                return undefined;
                            }

                            implicitWidth: 44 // Balanced item size
                            implicitHeight: 44
                            visible: entry !== undefined

                            Component.onCompleted: {
                                console.log("App Wrapper created for:", modelData, "Entry is:", entry !== undefined);
                            }

                            StateLayer {
                                id: state
                                anchors.fill: parent
                                anchors.margins: -4
                                radius: Tokens.rounding.normal
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                hoverEnabled: true

                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        const rawPinned = root.visibilities.pinnedApps || [];
                                        let pinned = [];
                                        for (let i = 0; i < rawPinned.length; i++) {
                                            pinned.push(rawPinned[i]);
                                        }
                                        const idx = pinned.indexOf(appWrapper.modelData);
                                        if (idx > -1) {
                                            pinned.splice(idx, 1);
                                            root.visibilities.pinnedApps = pinned;
                                        }
                                    } else if (appWrapper.entry) {
                                        iconAnim.start();
                                        LauncherServices.Apps.launch(appWrapper.entry);
                                        root.visibilities.bottomPanel = false;
                                    }
                                }
                            }

                            Rectangle {
                                id: iconBg
                                anchors.fill: parent
                                radius: 10 // Mathematically concentric with outer radius 20
                                color: state.containsMouse ? Colours.layer(Colours.palette.m3surfaceVariant, 0.8) : "transparent"
                                border.color: state.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.12) : "transparent"
                                border.width: 1

                                scale: state.containsMouse ? 1.12 : 1.0

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 250
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.2
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }

                                IconImage {
                                    id: icon
                                    asynchronous: true
                                    source: Quickshell.iconPath(appWrapper.entry?.icon, "image-missing")
                                    anchors.fill: parent
                                    anchors.margins: 6 // Symmetrical 6px padding inside icon background
                                    
                                    // Icon animation on click
                                    SequentialAnimation {
                                        id: iconAnim
                                        ScaleAnimator {
                                            target: icon
                                            from: 1.0
                                            to: 1.4
                                            duration: 150
                                            easing.type: Easing.OutBack
                                            easing.overshoot: 1.3
                                        }
                                        ScaleAnimator {
                                            target: icon
                                            from: 1.4
                                            to: 1.0
                                            duration: 200
                                            easing.type: Easing.OutElastic
                                            easing.overshoot: 0.5
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }



            // Clipboard Toggle Button (left of QS toggle)
            Item {
                id: clipboardToggle
                anchors.right: qsToggle.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 44
                implicitHeight: 44

                StateLayer {
                    id: clipState
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: Tokens.rounding.normal
                    hoverEnabled: true

                    onClicked: {
                        clipboardAnim.start();
                        root.visibilities.clipboard = !root.visibilities.clipboard;
                        if (root.visibilities.utilities)
                            root.visibilities.utilities = false;
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: clipState.containsMouse || root.visibilities.clipboard
                        ? Colours.layer(Colours.palette.m3surfaceVariant, 0.8)
                        : "transparent"
                    border.color: clipState.containsMouse || root.visibilities.clipboard
                        ? Qt.alpha(Colours.palette.m3onSurface, 0.12)
                        : "transparent"
                    border.width: 1

                    scale: clipState.containsMouse ? 1.12 : 1.0
                    Behavior on scale {
                        NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    }

                    MaterialIcon {
                        id: clipIcon
                        text: root.visibilities.clipboard ? "content_paste" : "content_paste"
                        anchors.fill: parent
                        anchors.margins: 10
                        fill: root.visibilities.clipboard ? 1 : 0
                        color: root.visibilities.clipboard
                            ? Colours.palette.m3primary
                            : Colours.palette.m3onSurface

                        Behavior on fill { Anim {} }
                        Behavior on color { ColorAnimation { duration: 200 } }

                        SequentialAnimation {
                            id: clipboardAnim
                            NumberAnimation {
                                target: clipIcon; property: "scale"
                                from: 1.0; to: 1.3; duration: 120
                                easing.type: Easing.OutBack; easing.overshoot: 1.5
                            }
                            NumberAnimation {
                                target: clipIcon; property: "scale"
                                from: 1.3; to: 1.0; duration: 180
                                easing.type: Easing.OutElastic; easing.overshoot: 0.5
                            }
                        }
                    }
                }
            }

            // QS Panel Toggle Button (right side)
            Item {
                id: qsToggle
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 44
                implicitHeight: 44

                StateLayer {
                    id: qsState
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: Tokens.rounding.normal
                    hoverEnabled: true

                    onClicked: {
                        settingsAnim.start();
                        root.visibilities.utilities = !root.visibilities.utilities;
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: qsState.containsMouse || root.visibilities.utilities ? Colours.layer(Colours.palette.m3surfaceVariant, 0.8) : "transparent"
                    border.color: qsState.containsMouse || root.visibilities.utilities ? Qt.alpha(Colours.palette.m3onSurface, 0.12) : "transparent"
                    border.width: 1

                    scale: qsState.containsMouse ? 1.12 : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.2
                        }
                    }

                    MaterialIcon {
                        id: settingsIcon
                        text: "settings"
                        anchors.fill: parent
                        anchors.margins: 10
                        color: root.visibilities.utilities ? Colours.palette.m3primary : Colours.palette.m3onSurface
                        
                        // Settings icon rotation animation on click
                        SequentialAnimation {
                            id: settingsAnim
                            RotationAnimator {
                                target: settingsIcon
                                from: 0
                                to: 180
                                duration: 300
                                easing.type: Easing.OutBack
                                easing.overshoot: 0.8
                            }
                            ScriptAction {
                                script: settingsIcon.rotation = 0
                            }
                        }
                    }
                }
            }

            // Bottom-right corner click area for utilities (cursor at bottom-right)
            MouseArea {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 100
                height: 100

                onClicked: {
                    root.visibilities.utilities = !root.visibilities.utilities;
                }
            }
        }
    }
}

