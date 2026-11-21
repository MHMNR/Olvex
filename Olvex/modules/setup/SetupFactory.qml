pragma Singleton

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Olvex.Config
import qs.components
import qs.components.containers
import qs.components.effects
import qs.modules.qspanel.toasts as Toasts
import qs.services
import qs.utils

// First-run setup wizard factory. Runs as a non-window Wayland Layer-Shell overlay
// with exclusive keyboard focus and an isolated empty workspace.
// Immune to Super+Q / killactive and suppresses standard shell chrome until completion.
Singleton {
    id: root

    property var currentInstance: null
    readonly property bool active: currentInstance !== null

    function hasAppliedWallpaper(): bool {
        return Boolean(typeof Wallpapers !== "undefined" && Wallpapers.actualCurrent && Wallpapers.actualCurrent.trim() !== "");
    }

    property bool wallpaperRevealed: hasAppliedWallpaper()
    property bool isCompleted: false
    property bool checkDone: false
    property bool shellAllowed: false
    readonly property bool _shouldAllowShell: checkDone && isCompleted && !active
    on_ShouldAllowShellChanged: {
        if (_shouldAllowShell && !shellAllowed)
            shellAllowed = true;
    }

    // First-boot detection: checks if ~/.local/state/olvex/setup_complete exists
    FileView {
        id: setupMarker
        printErrors: false
        path: `${Paths.state}/setup_complete`
        watchChanges: true
        onLoaded: {
            root.isCompleted = true;
            root.checkDone = true;
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.isCompleted = false;
                root.checkDone = true;
                // First boot detected: launch setup immediately before loading shell chrome
                Qt.callLater(() => {
                    if (!root.isCompleted && !root.currentInstance) {
                        root.open();
                    }
                });
            } else {
                root.isCompleted = true;
                root.checkDone = true;
            }
        }
    }

    Process {
        id: markCompleteProc
        command: ["sh", "-c", `mkdir -p "${Paths.state}" && touch "${Paths.state}/setup_complete"`]
    }

    function markComplete() {
        root.isCompleted = true;
        markCompleteProc.running = true;
    }

    function syncSetupBlur(blurEnabled, transparencyEnabled) {
        const shouldBlur = Boolean(blurEnabled && transparencyEnabled);
        const ignoreAlpha = transparencyEnabled ? Math.max(0.28, Colours.transparencyBase * 0.75) : 1.0;
        if (shouldBlur) {
            Hypr.extras.batchMessage([
                `eval hl.layer_rule({ match = { namespace = "olvex-setup-wizard" }, blur = true, ignore_alpha = ${ignoreAlpha.toFixed(3)} })`
            ]);
        } else {
            Hypr.extras.batchMessage([
                `eval hl.layer_rule({ match = { namespace = "olvex-setup-wizard" }, blur = false })`
            ]);
        }
    }

    function toggle() {
        if (currentInstance)
            close();
        else
            open();
    }

    function open() {
        if (currentInstance)
            return;

        // Dismiss all active drawers across all monitors
        if (Visibilities && Visibilities.screens) {
            for (let [monitor, v] of Visibilities.screens) {
                if (v) {
                    v.launcher = false;
                    v.dashboard = false;
                    v.qspanel = false;
                    v.powermenu = false;
                    v.notificationcenter = false;
                    v.secondaryPanel = false;
                    v.wallpaperLauncher = false;
                    v.osk = false;
                    v.help = false;
                    v.cheatsheet = false;
                }
            }
        }

        // Switch to a clean, empty workspace so no other application windows are behind setup
        Hypr.dispatch("workspace empty");

        wallpaperRevealed = hasAppliedWallpaper();
        currentInstance = windowComponent.createObject(dummy);
        syncSetupBlur(true, true);
    }

    function close() {
        if (currentInstance) {
            currentInstance.destroy();
            currentInstance = null;
            wallpaperRevealed = hasAppliedWallpaper();

            // Return to workspace 1
            Hypr.dispatch("workspace 1");
        }
    }

    QtObject {
        id: dummy
    }

    Component {
        id: windowComponent

        Scope {
            id: setupScope

            Variants {
                model: Screens.screens

                StyledWindow {
                    id: win
                    required property ShellScreen modelData

                    screen: modelData
                    name: "setup-wizard"
                    readonly property real uiScale: UiScale.forScreen(win.screen)
                    readonly property Item scaledContentRoot: setupScaledRoot

                    WlrLayershell.exclusionMode: ExclusionMode.Ignore
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

                    anchors.top: true
                    anchors.bottom: true
                    anchors.left: true
                    anchors.right: true

                    readonly property bool isPrimaryScreen: modelData === (Screens.screens.find(s => s.focused) ?? Screens.screens[0])

                    // Fullscreen solid neutral backdrop (macOS OOBE default)
                    Rectangle {
                        anchors.fill: parent
                        color: Colours.light ? "#F5F5F7" : "#0E0E11"

                        Behavior on color {
                            CAnim {}
                        }

                        // Seamlessly dissolves out when user selects a wallpaper in Step 2
                        opacity: root.wallpaperRevealed ? 0.0 : 1.0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 650
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    // Only render the interactive setup wizard card on the primary/focused display
                    Item {
                        id: setupScaledRoot
                        x: 0
                        y: 0
                        transformOrigin: Item.TopLeft
                        scale: win.uiScale
                        width: UiScale.virtualWidth(win.width, win.uiScale)
                        height: UiScale.virtualHeight(win.height, win.uiScale)
                        visible: win.isPrimaryScreen

                        // Inverted-masked shadow: shadow is strictly OUTSIDE the 28px card area.
                        // Zero shadow pixels inside the card bounds -> zero bleed, zero edge gradient through glass.
                        Item {
                            id: shadowCutoutMask
                            anchors.fill: shadowLayer
                            visible: false
                            layer.enabled: true

                            Rectangle {
                                anchors.centerIn: parent
                                width: cardContainer.width
                                height: cardContainer.height
                                radius: 28
                                color: "black"
                            }
                        }

                        Item {
                            id: shadowLayer
                            anchors.fill: cardContainer
                            anchors.margins: -80
                            visible: false
                            layer.enabled: true

                            RectangularShadow {
                                anchors.centerIn: parent
                                width: cardContainer.width
                                height: cardContainer.height
                                radius: 28
                                blur: 64
                                offset.y: 16
                                color: Qt.alpha(Colours.palette.m3shadow, Colours.light ? 0.16 : 0.32)
                            }

                            RectangularShadow {
                                anchors.centerIn: parent
                                width: cardContainer.width
                                height: cardContainer.height
                                radius: 28
                                blur: 24
                                spread: -4
                                offset.y: 8
                                color: Qt.alpha(Colours.palette.m3shadow, Colours.light ? 0.10 : 0.20)
                            }
                        }

                        MultiEffect {
                            anchors.fill: shadowLayer
                            source: shadowLayer
                            maskEnabled: true
                            maskInverted: true
                            maskSource: shadowCutoutMask
                            opacity: setupWin.windowRevealProgress
                            scale: 0.94 + (0.06 * setupWin.windowRevealProgress)
                        }

                        Item {
                            id: cardContainer
                            anchors.centerIn: parent
                            width: Math.round(Math.min(900, Math.max(520, parent.width - 48)))
                            height: Math.round(Math.min(660, Math.max(420, parent.height - 48)))

                            SetupWindow {
                                id: setupWin
                                anchors.fill: parent
                                onCloseRequested: {
                                    root.close();
                                }
                            }
                        }

                        // Native Olvex Toast renderer floating above the setup overlay
                        Toasts.Toasts {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Tokens.padding.large + 24
                            z: 100
                        }
                    }
                }
            }
        }
    }
}
