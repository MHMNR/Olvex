pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Olvex.Config
import Olvex.Internal
import Olvex.Services
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property Item wallpaper

    readonly property bool shouldBeActive: Config.background.visualiser.enabled && Players.activeIsPlaying && !(wallpaper.item?.liveWallpaperActive ?? false) && (!Config.background.visualiser.autoHide || (Hypr.monitorFor(screen)?.activeWorkspace?.toplevels?.values.every(t => t.lastIpcObject?.floating) ?? true))
    readonly property bool ownsVisualizer: VisualizerState.visibleOwner === ("background:" + root.screen.name)
    readonly property bool renderActive: root.shouldBeActive && root.ownsVisualizer
    // A non-background owner (lock pill / overlay / bar) holds the single visualizer
    // slot — its surface is opaque and covers us, so we are fully occluded. Snap off
    // instantly instead of fading, so the full-screen blur stops competing for the
    // GPU immediately (e.g. during the lock-screen entrance) rather than lingering
    // for the fade duration behind something the user can't see.
    readonly property bool supersededByForeground: {
        const owner = VisualizerState.visibleOwner;
        return owner !== "" && owner !== ("background:" + root.screen.name) && owner.indexOf("background:") !== 0;
    }
    readonly property int frameFps: Math.max(1, Math.min(GlobalConfig.services["visualiserFps"] || 60, 60))
    readonly property int frameInterval: Math.max(16, Math.round(1000 / frameFps))
    property real offset: renderActive ? 0 : screen.height * 0.2

    opacity: renderActive ? 1 : 0

    function syncVisualizerOwner(): void {
        VisualizerState.request("background:" + root.screen.name, 10, root.shouldBeActive);
    }

    onShouldBeActiveChanged: root.syncVisualizerOwner()
    Component.onCompleted: root.syncVisualizerOwner()
    Component.onDestruction: VisualizerState.release("background:" + root.screen.name)

    Loader {
        asynchronous: true
        anchors.fill: parent
        active: root.renderActive && root.opacity > 0 && Config.background.visualiser.blur

        sourceComponent: MultiEffect {
            source: root.wallpaper
            maskSource: wrapper
            maskEnabled: true
            blurEnabled: true
            blur: 1
            blurMax: 32
            autoPaddingEnabled: false
        }
    }

    Item {
        id: wrapper

        anchors.fill: parent
        visible: root.renderActive || root.opacity > 0
        layer.enabled: Config.background.visualiser.blur && (root.renderActive || root.opacity > 0)

        Loader {
            asynchronous: true
            anchors.fill: parent
            anchors.topMargin: root.offset
            anchors.bottomMargin: -root.offset

            active: root.renderActive || root.opacity > 0

            sourceComponent: Item {
                VisualiserBars {
                    id: bars

                    anchors.fill: parent
                    anchors.margins: ((Config && ((typeof Config !== "undefined" && Config && Config.border) ? Config.border : {
                                    thickness: 0,
                                    rounding: 0,
                                    minThickness: 0,
                                    floating: false,
                                    smoothing: 0,
                                    clampedThickness: 0
                                })) ? ((typeof Config !== "undefined" && Config && Config.border) ? Config.border : {
                                thickness: 0,
                                rounding: 0,
                                minThickness: 0,
                                floating: false,
                                smoothing: 0,
                                clampedThickness: 0
                            }) : ({
                                thickness: 0,
                                rounding: 0,
                                minThickness: 0,
                                floating: false,
                                smoothing: 0,
                                clampedThickness: 0
                            })).thickness
                    anchors.leftMargin: Visibilities.bars.get(root.screen).exclusiveZone + Tokens.spacing.small * Config.background.visualiser.spacing

                    values: root.renderActive ? VisualizerState.values : []
                    active: root.renderActive || root.opacity > 0
                    frameInterval: root.frameInterval
                    primaryColor: Qt.alpha(Colours.palette.m3primary, 0.7)
                    secondaryColor: Qt.alpha(Colours.palette.m3inversePrimary, 0.7)
                    rounding: Tokens.rounding.small * Config.background.visualiser.rounding
                    spacing: Tokens.spacing.small * Config.background.visualiser.spacing
                    animationDuration: Math.max(root.frameInterval * 3, 90)

                    onSettledChanged: {
                        if (root.ownsVisualizer)
                            VisualizerState.isSettled = settled;
                    }

                    Behavior on anchors.leftMargin {
                        Anim {}
                    }
                }

            }
        }
    }

    Behavior on offset {
        Anim {}
    }

    Behavior on opacity {
        enabled: !root.supersededByForeground
        Anim {}
    }
}
