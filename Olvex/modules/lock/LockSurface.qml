pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Wayland
import Olvex.Config
import "../olvex" as Olvex
import qs.components
import qs.services

WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    required property Pam pam

    readonly property alias unlocking: unlockAnim.running
    readonly property string configuredStyle: GlobalConfig.lock.style === "minimal" ? "minimal" : "card"
    property string effectiveStyle: configuredStyle
    // Triggers directional slides in Content.qml and Center.qml
    property bool contentReady: false

    // screen can briefly be null right at lock-surface creation, before the
    // compositor assigns it — guard instead of dereferencing .name directly.
    contentItem.Config.screen: screen ? screen.name : ""
    contentItem.Tokens.screen: screen ? screen.name : ""

    // Transparent — wallpaper renders directly, no flash
    color: "transparent"

    // Fades in shortly after load to prevent desktop bleed-through under the blur
    Rectangle {
        id: solidBackdrop
        anchors.fill: parent
        color: "black"
        z: -2
        opacity: 0
    }

    // ── Wallpaper with optional blur/dim ─────────────────────────────────────
    Olvex.BackgroundWallpaper {
        id: wallpaper
        anchors.fill: parent
        screen: root.screen
        z: -1
        scale: 1.0

        layer.enabled: GlobalConfig.lock.blurBackground || GlobalConfig.lock.dimWallpaper
        layer.effect: MultiEffect {
            id: wallEffect
            autoPaddingEnabled: false
            blurEnabled: GlobalConfig.lock.blurBackground
            blur: GlobalConfig.lock.blurBackground ? 1.0 : 0.0
            blurMax: 48
            
            // Premium acrylic glass tweaks
            saturation: GlobalConfig.lock.blurBackground ? -0.15 : 0.0
            contrast: GlobalConfig.lock.blurBackground ? 0.05 : 0.0
            
            colorizationColor: "black"
            colorization: GlobalConfig.lock.dimWallpaper ? 0.40 : 0.0
        }
    }

    // ── Appear instantly, signal inner slides, fade in backdrop ───────────────
    Component.onCompleted: {
        lockContent.opacity = 1
        statusBar.opacity = 1
        root.contentReady = true
        backdropFadeIn.start()
    }

    NumberAnimation {
        id: backdropFadeIn
        target: solidBackdrop; property: "opacity"
        from: 0; to: 1
        duration: 400
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: backdropFadeOut
        target: solidBackdrop; property: "opacity"
        from: 1; to: 0
        duration: 400
        easing.type: Easing.InCubic
    }

    function useCardFallback(): void {
        if (effectiveStyle !== "card")
            effectiveStyle = "card";
    }

    Connections {
        target: root.lock
        function onUnlock(): void { unlockAnim.start() }
    }

    Connections {
        target: GlobalConfig.lock
        function onStyleChanged(): void { root.effectiveStyle = root.configuredStyle }
    }

    // ── EXIT: fire wallpaper zoom-out, wait for cards+zoom to finish, unlock ──
    SequentialAnimation {
        id: unlockAnim

        ScriptAction { script: backdropFadeOut.start() }

        // Wait for all staggered card exits to finish (5×70ms stagger + 650ms exit)
        PauseAnimation { duration: 1050 }

        PropertyAction {
            target: root.lock
            property: "locked"
            value: false
        }
    }

    // ── Content ───────────────────────────────────────────────────────────────
    Item {
        id: lockContent
        anchors.fill: parent
        opacity: 0  // set to 1 in onCompleted

        Loader {
            id: content
            anchors.fill: parent
            asynchronous: false
            sourceComponent: root.effectiveStyle === "minimal" ? minimalContentComponent : cardContentComponent

            onStatusChanged: {
                if (status === Loader.Error) root.useCardFallback()
                if (status === Loader.Ready) item.forceActiveFocus()
            }
        }
    }

    // ── Bottom status bar ─────────────────────────────────────────────────────
    Item {
        id: statusBar

        anchors {
            left: parent.left; right: parent.right; bottom: parent.bottom
            leftMargin: Tokens.padding.large * 3
            rightMargin: Tokens.padding.large * 3
            bottomMargin: Tokens.padding.large * 2
        }
        implicitHeight: leftRow.implicitHeight
        visible: false
        opacity: 0  // set to 1 in onCompleted

        Row {
            id: leftRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.large * 2

            Row {
                spacing: Tokens.spacing.small
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: Colours.palette.m3secondary
                    anchors.verticalCenter: parent.verticalCenter

                    // Only run while the status bar is actually shown (card style).
                    // In minimal style statusBar is invisible, so this infinite blink
                    // would otherwise keep the animation driver awake for nothing.
                    SequentialAnimation on opacity {
                        running: statusBar.visible; loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 800 }
                        NumberAnimation { to: 1.0; duration: 800 }
                    }
                }

                StyledText {
                    text: qsTr("Network Active")
                    color: Colours.palette.m3outline
                    font.family: Tokens.font.family.mono
                    textPointSize: Tokens.font.size.smaller
                    font.weight: 500
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        StyledText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Olvex v1.0"
            color: Qt.alpha(Colours.palette.m3outline, 0.5)
            font.family: Tokens.font.family.mono
            textPointSize: Tokens.font.size.smaller
        }
    }

    Component {
        id: cardContentComponent
        Content { lock: root }
    }

    Component {
        id: minimalContentComponent
        Olvex.MinimalLockContent {
            lock: root
            pam: root.pam
            screen: root.screen
        }
    }
}
