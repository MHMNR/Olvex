
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

        // Compute dynamic exclusive zone safe boundaries
        readonly property int borderThickness: ((win.contentItem.Config && win.contentItem.Config.border) ? win.contentItem.Config.border.thickness : 0)
        readonly property int barExclusion: {
            const barCfg = win.contentItem.Config.bar;
            const isPersistent = barCfg ? barCfg.persistent : true;
            const barWidth = Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.smaller, borderThickness) * 2;
            return isPersistent ? barWidth : borderThickness;
        }
        readonly property int bottomPanelExclusion: {
            const sec = win.contentItem.Config.bar ? win.contentItem.Config.bar.secondaryPanel : null;
            const enabled = sec ? sec.enabled : true;
            const mode = sec ? sec.visibilityMode : "always";
            if (enabled && mode === "always")
                return 80;
            return borderThickness;
        }

        // Padding around clock including exclusion zones + comfortable margin (32px)
        readonly property int safePadLeft: barExclusion + 32
        readonly property int safePadRight: borderThickness + 32
        readonly property int safePadTop: borderThickness + 32
        readonly property int safePadBottom: bottomPanelExclusion + 32

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
            readonly property real autoTargetX: (win.contentItem.Config.background && win.contentItem.Config.background.desktopClock) ? win.contentItem.Config.background.desktopClock.autoX : 100
            readonly property real autoTargetY: (win.contentItem.Config.background && win.contentItem.Config.background.desktopClock) ? win.contentItem.Config.background.desktopClock.autoY : 100

            x: isAutoPlacement ? autoTargetX : undefined
            y: isAutoPlacement ? autoTargetY : undefined

            Behavior on x {
                id: clockXBehavior
                enabled: clockLoader.isAutoPlacement
                NumberAnimation { id: clockXAnim; duration: 600; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                id: clockYBehavior
                enabled: clockLoader.isAutoPlacement
                NumberAnimation { id: clockYAnim; duration: 600; easing.type: Easing.OutCubic }
            }

            anchors.margins: 0
            anchors.leftMargin: 0
            anchors.rightMargin: 0
            anchors.topMargin: 0
            anchors.bottomMargin: 0

            transform: Translate {
                id: clockTranslate
                y: clockLoader._isBottom ? -clockLoader._panelOffset : 0
                Behavior on y {
                    SmoothedAnimation {
                        id: clockTranslateAnim
                        velocity: 160
                        easing.type: Easing.InOutCubic
                    }
                }
            }

            // Bake into GPU texture while sliding — eliminates expensive shader re-render per frame
            layer.enabled: Boolean(clockYAnim.running || clockXAnim.running || clockTranslateAnim.running)
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
                    }
                }
            ]

            transitions: Transition {
                AnchorAnim { duration: 400; easing.type: Easing.OutCubic }
            }

            sourceComponent: DesktopClock {
                wallpaper: behindClock
                absX: clockLoader.x
                absY: clockLoader.y + clockTranslate.y  // tracks real visual position

                // Bake into GPU texture while sliding — eliminates expensive shader re-render per frame
                layer.enabled: clockYAnim.running || clockXAnim.running || clockTranslateAnim.running
            }
        }
    }
}
