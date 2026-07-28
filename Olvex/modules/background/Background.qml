pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Olvex.Config
import "../olvex" as Olvex
import qs.components
import qs.components.containers
import qs.services

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
        surfaceFormat.opaque: false

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        Item {
            id: behindClock

            anchors.fill: parent

            readonly property bool olvexLiveWallpaperEnabled: GlobalConfig.background?.liveWallpaper?.enabled ?? false
            readonly property bool olvexPerMonitorWallpaper: GlobalConfig.background?.perMonitorWallpaper ?? false

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

                        function onActualCurrentChanged(): void {
                            source = Wallpapers.getMonitorWallpaper(win.modelData.name);
                        }

                        function onMonitorWallpapersChanged(): void {
                            source = Wallpapers.getMonitorWallpaper(win.modelData.name);
                        }

                        function onPerMonitorWallpaperChanged(): void {
                            source = Wallpapers.getMonitorWallpaper(win.modelData.name);
                        }
                    }
                }
            }


        }

        Loader {
            id: clockLoader

            asynchronous: true
            active: Config.background.desktopClock.enabled && !LockState.locked

            anchors.margins: Tokens.padding.large * 2
            anchors.leftMargin: Tokens.padding.large * 2 + Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.smaller, ((Config && ((typeof Config !== "undefined" && Config && Config.border) ? Config.border : {thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0})) ? ((typeof Config !== "undefined" && Config && Config.border) ? Config.border : {thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0}) : ({thickness:0,rounding:0,minThickness:0,floating:false,smoothing:0,clampedThickness:0})).thickness)

            // In always/smarthide mode the panel is always visible — push clock 40px above it
            readonly property string _bottomMode: Config.bar.bottomPanel ? Config.bar.bottomPanel.visibilityMode : "always"
            readonly property real _panelOffset: (_bottomMode === "always" || _bottomMode === "smarthide") ? 40 : 0
            readonly property real _baseMargin: Tokens.padding.large * 2

            readonly property bool _isBottom: Config.background.desktopClock.position.startsWith("bottom")
            
            anchors.bottomMargin: _baseMargin

            transform: Translate {
                id: clockTranslate
                y: clockLoader._isBottom ? -clockLoader._panelOffset : 0
                Behavior on y {
                    SmoothedAnimation {
                        id: clockYAnim
                        velocity: 160
                        easing.type: Easing.InOutCubic
                    }
                }
            }
            
            state: Config.background.desktopClock.position
            states: [
                State {
                    name: "top-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "top-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "top-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.right: parent.right
                    }
                },
                State {
                    name: "middle-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "middle-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "middle-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                    }
                },
                State {
                    name: "bottom-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "bottom-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "bottom-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
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

                // Bake into GPU texture while sliding — eliminates shader re-render per frame
                layer.enabled: clockYAnim.running
            }
        }
    }
}
