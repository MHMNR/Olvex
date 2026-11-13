

import ".."
import "."
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import M3Shapes
import Olvex.Config
import qs.services

// Premium M3 bento tile — icon top-left, labels bottom-left, preview right.
// No free-float overlap; no hover shape morph on the icon chip.
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property string icon: "settings"
    property string kind: ""
    property color accent: Colours.palette.m3primary
    property int index: 0
    property bool compact: false
    property bool tall: false
    property bool containerHidden: false
    property bool animsFrozen: false

    signal clicked

    // Coerce: hover.containsMouse can be undefined before StateLayer is ready
    // (`true && undefined` → undefined → "Unable to assign to bool")
    readonly property bool hovered: !root.animsFrozen && !!(hover && hover.containsMouse)

    readonly property int contentPad: 15
    readonly property int iconSize: root.tall ? 44 : 32

    property real liquidProgress: 0.0
    property real liquidVelocity: 0.0
    property real liquidTime: 0.0

    // High-refresh-rate VSync FrameAnimation (60Hz/120Hz/144Hz/240Hz+)
    // Uses exact analytical critically-damped spring integration with C2 velocity continuity on interrupt
    // and auto-suspends once settled at 0.0 or 1.0 for zero idle/settled GPU cost.
    FrameAnimation {
        id: liquidFrameAnim

        running: !root.compact && !root.animsFrozen && root.visible && (
            (root.hovered && root.liquidProgress < 0.9995) ||
            (!root.hovered && root.liquidProgress > 0.0005) ||
            Math.abs(root.liquidVelocity) > 0.001
        )

        onTriggered: {
            const dt = Math.min(Math.max(smoothFrameTime, 0.001), 0.033);
            const target = root.hovered ? 1.0 : 0.0;
            // Critically damped (zeta = 1.0): fast initial surge out of icon badge, silky settle, zero bounce
            const omega = root.hovered ? 8.2 : 9.6;
            const expTerm = Math.exp(-omega * dt);
            const x0 = root.liquidProgress - target;
            const v0 = root.liquidVelocity;

            const x1 = (x0 * (1.0 + omega * dt) + v0 * dt) * expTerm;
            const v1 = (v0 * (1.0 - omega * dt) - x0 * omega * omega * dt) * expTerm;

            let nextP = target + x1;
            if (Math.abs(target - nextP) < 0.0008 && Math.abs(v1) < 0.015) {
                root.liquidProgress = target;
                root.liquidVelocity = 0.0;
            } else {
                root.liquidProgress = Math.max(0.0, Math.min(1.0, nextP));
                root.liquidVelocity = v1;
                root.liquidTime = (root.liquidTime + dt) % 1000.0;
            }
        }
    }

    onCompactChanged: {
        if (root.compact) {
            root.liquidProgress = 0.0;
            root.liquidVelocity = 0.0;
        }
    }

    onAnimsFrozenChanged: {
        if (root.animsFrozen) {
            root.liquidProgress = 0.0;
            root.liquidVelocity = 0.0;
        }
    }

    function iconShapeFor(cardKind) {
        switch (cardKind) {
        case "appearance":
            return MaterialShape.Flower;
        case "network":
            return MaterialShape.Arch;
        case "sound":
            return MaterialShape.Fan;
        case "power":
            return MaterialShape.Pentagon;
        case "bar":
        case "taskbar":
            return MaterialShape.Square;
        case "notifications":
        case "notifs":
            return MaterialShape.Ghostish;
        case "panels":
            return MaterialShape.Cookie4Sided;
        case "system":
            return MaterialShape.Slanted;
        case "about":
            return MaterialShape.Gem;
        case "wallpaper":
            return MaterialShape.Clover4Leaf;
        case "display":
            return MaterialShape.Puffy;
        case "lock":
            return MaterialShape.Diamond;
        default:
            return MaterialShape.Square;
        }
    }
    // Preview zone widths tailored to domain preview content
    readonly property int previewW: {
        if (root.kind === "appearance")
            return Math.round(width * 0.58);
        if (root.kind === "taskbar" || root.kind === "bar" || root.kind === "system" || root.kind === "about")
            return Math.min(Math.round(width * 0.52), 196);
        if (root.kind === "notifications")
            return Math.min(Math.round(width * 0.55), 140);
        if (root.kind === "panels")
            return 76;
        if (root.kind === "network")
            return 80;
        return 90;
    }

    property real enterOpacity: 0
    opacity: containerHidden ? 0 : enterOpacity
    scale: 1

    onContainerHiddenChanged: {
        if (!containerHidden && enterOpacity < 1)
            enterOpacity = 1;
    }

    Component.onCompleted: entrance.start()

    SequentialAnimation {
        id: entrance

        PauseAnimation {
            duration: Math.round(Tokens.anim.durations.small * 0.08 * root.index)
        }
        Anim {
            type: Anim.FastEffects
            target: root
            property: "enterOpacity"
            to: 1
        }
    }

    Rectangle {
        id: card

        anchors.fill: parent
        radius: 26
        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
        // Clip card chrome only — inner content uses its own safe insets
        clip: true

        // Base tonal wash (flat subtle tint for bento cards; compact rows keep hover lift)
        Rectangle {
            z: 0
            anchors.fill: parent
            radius: parent.radius
            color: Qt.alpha(root.accent, (root.compact && root.hovered) ? 0.045 : 0.012)

            Behavior on color {
                enabled: !root.animsFrozen
                CAnim {}
            }
        }

        // Liquid ink-in-water dispersion of badge m3primary color from icon origin
        ShaderEffect {
            id: liquidShader

            readonly property real uProgress: root.liquidProgress
            readonly property real uTime: root.liquidTime
            readonly property real uRadius: card.radius
            readonly property color uPrimaryColor: Colours.palette.m3primary
            readonly property vector2d uOrigin: Qt.vector2d(root.contentPad + 18, root.contentPad + 18)
            readonly property vector2d uSize: Qt.vector2d(width, height)
            readonly property real uSeed: root.index

            z: 1
            anchors.fill: parent
            supportsAtlasTextures: true
            visible: !root.compact && !root.animsFrozen && root.liquidProgress > 0.0005
            fragmentShader: Qt.resolvedUrl("../../../assets/shaders/liquid_spread.frag.qsb")
        }

        // Clean fallback fill if shader asset fails to load
        Rectangle {
            z: 1
            anchors.fill: parent
            radius: card.radius
            visible: !root.compact && !root.animsFrozen && root.liquidProgress > 0.002 && liquidShader.status === ShaderEffect.Error
            color: Colours.palette.m3primary
            opacity: root.liquidProgress
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 0
            border.color: "transparent"
        }

        // ── Compact (search row) ──
        Row {
            visible: root.compact
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.padding.large
            anchors.rightMargin: Tokens.padding.large
            spacing: Tokens.spacing.normal
            z: 2

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                radius: Tokens.rounding.normal
                color: Colours.palette.m3primaryContainer

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.icon
                    fill: 1
                    color: Colours.palette.m3onPrimaryContainer
                    iconPointSize: Tokens.font.size.large
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                width: parent.width - 44 - parent.spacing

                StyledText {
                    width: parent.width
                    text: root.title
                    elide: Text.ElideRight
                    font.weight: Font.Normal
                    color: Colours.palette.m3onSurface
                    textPointSize: Tokens.font.size.larger
                }

                StyledText {
                    width: parent.width
                    visible: !!root.subtitle
                    text: root.subtitle
                    elide: Text.ElideRight
                    color: Colours.palette.m3onSurfaceVariant
                    textPointSize: Tokens.font.size.small
                }
            }
        }

        // ── Standard bento ──
        Item {
            id: body

            z: 2
            visible: !root.compact
            anchors.fill: parent
            anchors.margins: root.contentPad

            // Preview zone — right (sound & power use unified top-left M3Shape icon badge)
            CardPreview {
                id: preview

                z: 1
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: root.previewW
                kind: root.kind
                accent: root.accent
                hovered: root.hovered
                visible: root.kind !== "sound" && root.kind !== "power"
            }

            // M3 Expressive shape icon badge — top-left (uniform across all cards)
            Item {
                id: plate

                z: 2
                width: 36
                height: 36
                anchors.left: parent.left
                anchors.top: parent.top

                MaterialShape {
                    anchors.fill: parent
                    implicitSize: 36
                    shape: root.iconShapeFor(root.kind)
                    color: Colours.palette.m3primary
                    strokeWidth: 0
                    strokeColor: "transparent"

                    Behavior on color {
                        enabled: !root.animsFrozen
                        CAnim {}
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.icon
                    fill: 1
                    color: Colours.palette.m3onPrimary
                    iconPointSize: 15
                }
            }

            // Labels — bottom-left
            Column {
                id: labels

                readonly property bool fullWidthLabels: root.kind === "sound" || root.kind === "power" || root.kind === "notifications" || root.kind === "panels"

                z: 2
                spacing: 3
                anchors.left: parent.left
                anchors.right: (fullWidthLabels || root.kind === "appearance") ? parent.right : preview.left
                anchors.rightMargin: root.kind === "appearance" ? 72 : (fullWidthLabels ? 0 : Tokens.spacing.normal)
                anchors.bottom: parent.bottom

                StyledText {
                    width: parent.width
                    text: root.title
                    elide: Text.ElideRight
                    font.weight: Font.DemiBold
                    font.letterSpacing: -0.2
                    lineHeight: 1.12
                    lineHeightMode: Text.ProportionalHeight
                    color: root.hovered ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                    textPointSize: Tokens.font.size.larger

                    Behavior on color {
                        enabled: !root.animsFrozen
                        CAnim {}
                    }
                }

                StyledText {
                    width: parent.width
                    visible: !!root.subtitle
                    text: root.subtitle
                    elide: Text.ElideRight
                    color: root.hovered ? Qt.alpha(Colours.palette.m3onPrimary, 0.84) : Colours.palette.m3onSurfaceVariant
                    font.weight: Font.Medium
                    font.letterSpacing: 0.05
                    font.features: ({ "tnum": 1 })
                    lineHeight: 1.25
                    lineHeightMode: Text.ProportionalHeight
                    textPointSize: Tokens.font.size.small

                    Behavior on color {
                        enabled: !root.animsFrozen
                        CAnim {}
                    }
                }
            }
        }

        StateLayer {
            id: hover

            z: 3
            anchors.fill: parent
            radius: card.radius
            color: root.hovered ? Colours.palette.m3onPrimary : root.accent
            showHoverBackground: false
            showRipple: true
            onClicked: root.clicked()
        }
    }
}
