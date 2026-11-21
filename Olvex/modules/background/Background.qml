
import QtQuick
import Quickshell
import Quickshell.Wayland
import Olvex
import Olvex.Config
import "../olvex" as Olvex
import qs.components
import qs.components.containers
import qs.services
import qs.utils
import "../setup"

Variants {
    model: Screens.screens.filter(s => GlobalConfig.forScreen(s.name).background.enabled)

    StyledWindow {
        id: win

        required property ShellScreen modelData

        screen: modelData
        name: "background"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: contentItem.Config.background.wallpaperEnabled ? WlrLayer.Background : WlrLayer.Bottom
        color: contentItem.Config.background.wallpaperEnabled ? "black" : "transparent"
        surfaceFormat.opaque: contentItem.Config.background.wallpaperEnabled

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        readonly property string currentWallPath: Wallpapers.getMonitorWallpaper(win.modelData.name)
        readonly property string analysisImagePath: {
            const raw = win.currentWallPath;
            if (!raw) return "";
            if (Wallpapers.isVideoPath(raw)) {
                // Return thumbnail generated for live video wallpaper
                return Wallpapers.displayPathFor(raw);
            }
            return raw;
        }

        readonly property string placementStrategy: (win.contentItem.Config.background && win.contentItem.Config.background.desktopClock && win.contentItem.Config.background.desktopClock.placementStrategy) ? win.contentItem.Config.background.desktopClock.placementStrategy : "fixed"
        readonly property bool isAutoPlacement: placementStrategy === "leastBusy" || placementStrategy === "mostBusy"

        onAnalysisImagePathChanged: triggerAutoPlacement()
        onPlacementStrategyChanged: triggerAutoPlacement()

        Connections {
            target: Wallpapers
            function onThumbnailUpdateCountChanged() {
                if (Wallpapers.isVideoPath(win.currentWallPath)) {
                    win.triggerAutoPlacement();
                }
            }
        }

        Component.onCompleted: {
            triggerAutoPlacement();
        }

        readonly property real uiScale: UiScale.forScreen(win.modelData)

        // Compute dynamic exclusive zone safe boundaries (scaled to physical screen)
        readonly property int borderThickness: Math.round(((win.contentItem.Config && win.contentItem.Config.border) ? win.contentItem.Config.border.thickness : 0) * win.uiScale)
        readonly property int barExclusion: {
            const barCfg = win.contentItem.Config.bar;
            const isPersistent = barCfg ? barCfg.persistent : true;
            const rawBorder = (win.contentItem.Config && win.contentItem.Config.border) ? win.contentItem.Config.border.thickness : 0;
            const barWidth = Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.smaller, rawBorder) * 2;
            return Math.round((isPersistent ? barWidth : rawBorder) * win.uiScale);
        }
        readonly property int bottomPanelExclusion: {
            const sec = win.contentItem.Config.bar ? win.contentItem.Config.bar.secondaryPanel : null;
            const enabled = sec ? sec.enabled : true;
            const mode = sec ? sec.visibilityMode : "always";
            const rawBorder = (win.contentItem.Config && win.contentItem.Config.border) ? win.contentItem.Config.border.thickness : 0;
            if (enabled && (mode === "always" || mode === "smarthide"))
                return Math.round(Math.max(rawBorder, 80) * win.uiScale);
            return Math.round(rawBorder * win.uiScale);
        }

        // Padding around clock including exclusion zones + comfortable margin (scaled)
        readonly property int safePadLeft: barExclusion + Math.round(24 * win.uiScale)
        readonly property int safePadRight: borderThickness + Math.round(24 * win.uiScale)
        readonly property int safePadTop: borderThickness + Math.round(24 * win.uiScale)
        readonly property int safePadBottom: bottomPanelExclusion + Math.round(24 * win.uiScale)

        function triggerAutoPlacement() {
            if (!isAutoPlacement || !analysisImagePath) return;
            regionAnalyser.findRegion(
                win.analysisImagePath,
                Math.round(win.width > 0 ? win.width : 1920),
                Math.round(win.height > 0 ? win.height : 1080),
                Math.round(clockLoader.width > 0 ? clockLoader.width : 320),
                Math.round(clockLoader.height > 0 ? clockLoader.height : 180),
                safePadLeft,
                safePadTop,
                safePadRight,
                safePadBottom,
                win.placementStrategy === "mostBusy"
            );
        }

        ImageAnalyser {
            id: regionAnalyser
            onRegionFound: (x, y, centerX, centerY, dominantColor, luminance, isDark) => {
                const targetClock = win.contentItem.Config.background ? win.contentItem.Config.background.desktopClock : null;
                if (targetClock) {
                    targetClock.autoX = x;
                    targetClock.autoY = y;
                    targetClock.dominantIsDark = isDark;
                }
            }
        }

        Item {
            id: behindClock

            anchors.fill: parent

            readonly property bool olvexLiveWallpaperEnabled: (GlobalConfig.background && GlobalConfig.background.liveWallpaper) ? GlobalConfig.background.liveWallpaper.enabled : false
            readonly property bool olvexPerMonitorWallpaper: GlobalConfig.background ? GlobalConfig.background.perMonitorWallpaper : false

            Loader {
                id: wallpaper

                asynchronous: true

                anchors.fill: parent
                active: Config.background.wallpaperEnabled

                sourceComponent: Olvex.BackgroundWallpaper {
                    screen: win.modelData
                    source: Wallpapers.getMonitorWallpaper(win.modelData.name)

                    Connections {
                        target: Wallpapers

                        function onActualCurrentChanged() {
                            source = Wallpapers.getMonitorWallpaper(win.modelData.name);
                        }

                        function onMonitorWallpapersChanged() {
                            source = Wallpapers.getMonitorWallpaper(win.modelData.name);
                        }

                        function onPerMonitorWallpaperChanged() {
                            source = Wallpapers.getMonitorWallpaper(win.modelData.name);
                        }
                    }
                }
            }


        }

        Loader {
            id: clockLoader

            asynchronous: true
            active: (win.contentItem.Config.background && win.contentItem.Config.background.desktopClock ? win.contentItem.Config.background.desktopClock.enabled : true) && !SetupFactory.active

            readonly property bool isAutoPlacement: win.isAutoPlacement
            readonly property real rawAutoX: (win.contentItem.Config.background && win.contentItem.Config.background.desktopClock) ? win.contentItem.Config.background.desktopClock.autoX : 100
            readonly property real rawAutoY: (win.contentItem.Config.background && win.contentItem.Config.background.desktopClock) ? win.contentItem.Config.background.desktopClock.autoY : 100
            readonly property real autoTargetX: {
                const maxX = Math.max(win.safePadLeft, (win.width > 0 ? win.width : 1920) - win.safePadRight - width);
                return Math.max(win.safePadLeft, Math.min(maxX, rawAutoX));
            }
            readonly property real autoTargetY: {
                const maxY = Math.max(win.safePadTop, (win.height > 0 ? win.height : 1080) - win.safePadBottom - height);
                return Math.max(win.safePadTop, Math.min(maxY, rawAutoY));
            }

            onStatusChanged: {
                if (status === Loader.Ready)
                    win.triggerAutoPlacement();
            }

            Binding {
                target: clockLoader
                property: "x"
                value: clockLoader.autoTargetX
                when: clockLoader.isAutoPlacement
                restoreMode: Binding.RestoreNone
            }
            Binding {
                target: clockLoader
                property: "y"
                value: clockLoader.autoTargetY
                when: clockLoader.isAutoPlacement
                restoreMode: Binding.RestoreNone
            }

            Behavior on x {
                id: clockXBehavior
                enabled: clockLoader.isAutoPlacement
                NumberAnimation {
                    id: clockXAnim
                    duration: 700
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1, 1]
                }
            }
            Behavior on y {
                id: clockYBehavior
                enabled: clockLoader.isAutoPlacement
                NumberAnimation {
                    id: clockYAnim
                    duration: 700
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1, 1]
                }
            }

            anchors.margins: 0
            anchors.leftMargin: 0
            anchors.rightMargin: 0
            anchors.topMargin: 0
            anchors.bottomMargin: 0

            transform: Translate {
                id: clockTranslate
                y: 0
            }

            // Bake into GPU texture while sliding — eliminates expensive shader re-render per frame
            layer.enabled: Boolean(clockYAnim.running || clockXAnim.running)
            layer.smooth: true
            
            state: isAutoPlacement ? "" : (win.contentItem.Config.background && win.contentItem.Config.background.desktopClock ? win.contentItem.Config.background.desktopClock.position : "middle-center")
            states: [
                State {
                    name: "top-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.left: parent.left
                    }
                    PropertyChanges {
                        target: clockLoader
                        anchors.margins: Tokens.padding.large * 2
                        anchors.topMargin: Tokens.padding.large * 2 + win.borderThickness
                        anchors.leftMargin: Tokens.padding.large * 2 + win.barExclusion
                    }
                },
                State {
                    name: "top-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    PropertyChanges {
                        target: clockLoader
                        anchors.margins: Tokens.padding.large * 2
                        anchors.topMargin: Tokens.padding.large * 2 + win.borderThickness
                    }
                },
                State {
                    name: "top-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.right: parent.right
                    }
                    PropertyChanges {
                        target: clockLoader
                        anchors.margins: Tokens.padding.large * 2
                        anchors.topMargin: Tokens.padding.large * 2 + win.borderThickness
                        anchors.rightMargin: Tokens.padding.large * 2 + win.borderThickness
                    }
                },
                State {
                    name: "middle-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                    }
                    PropertyChanges {
                        target: clockLoader
                        anchors.margins: Tokens.padding.large * 2
                        anchors.leftMargin: Tokens.padding.large * 2 + win.barExclusion
                    }
                },
                State {
                    name: "center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    PropertyChanges {
                        target: clockLoader
                        anchors.margins: Tokens.padding.large * 2
                    }
                },
                State {
                    name: "middle-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    PropertyChanges {
                        target: clockLoader
                        anchors.margins: Tokens.padding.large * 2
                    }
                },
                State {
                    name: "middle-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                    }
                    PropertyChanges {
                        target: clockLoader
                        anchors.margins: Tokens.padding.large * 2
                        anchors.rightMargin: Tokens.padding.large * 2 + win.borderThickness
                    }
                },
                State {
                    name: "bottom-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                    }
                    PropertyChanges {
                        target: clockLoader
                        anchors.margins: Tokens.padding.large * 2
                        anchors.leftMargin: Tokens.padding.large * 2 + win.barExclusion
                        anchors.bottomMargin: Tokens.padding.large * 2 + win.bottomPanelExclusion
                    }
                },
                State {
                    name: "bottom-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    PropertyChanges {
                        target: clockLoader
                        anchors.margins: Tokens.padding.large * 2
                        anchors.bottomMargin: Tokens.padding.large * 2 + win.bottomPanelExclusion
                    }
                },
                State {
                    name: "bottom-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                    }
                    PropertyChanges {
                        target: clockLoader
                        anchors.margins: Tokens.padding.large * 2
                        anchors.rightMargin: Tokens.padding.large * 2 + win.borderThickness
                        anchors.bottomMargin: Tokens.padding.large * 2 + win.bottomPanelExclusion
                    }
                }
            ]

            transitions: Transition {
                AnchorAnim { duration: 400; easing.type: Easing.OutCubic }
            }

            sourceComponent: DesktopClock {
                screenName: win.modelData ? win.modelData.name : ""
                wallpaper: behindClock
                absX: clockLoader.x
                absY: clockLoader.y + clockTranslate.y  // tracks real visual position
                uiScale: win.uiScale

                // Bake into GPU texture while sliding — eliminates expensive shader re-render per frame
                layer.enabled: clockYAnim.running || clockXAnim.running
            }
        }
    }
}
