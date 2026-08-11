pragma ComponentBehavior: Bound


import ".."
import "."
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
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

    // Geometry tokens (8px grid) — guard Tokens before screen attach
    readonly property int contentPad: Tokens?.padding?.large ?? 16
    readonly property int iconSize: root.tall ? 44 : 36
    // Tall heroes: preview owns most of the card (alive stage). Short: right strip.
    readonly property int previewW: {
        if (root.tall)
            return Math.round(width * (root.kind === "wallpaper" ? 0.62 : 0.48));
        return Math.max(112, Math.min(Math.round(width * 0.42), 128));
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
        radius: Tokens.rounding.large
        color: Colours.palette.m3surfaceContainer
        // Clip card chrome only — inner content uses its own safe insets
        clip: true

        // Tonal wash (hover lifts surface, no shape morph)
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            // Light wash only — strong accent (was error/red) made tiles look off-palette
            color: Qt.alpha(root.accent, root.hovered ? 0.08 : 0.04)

            Behavior on color {
                enabled: !root.animsFrozen
                CAnim {}
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(root.hovered ? root.accent : Colours.palette.m3outlineVariant, root.hovered ? 0.35 : 0.22)

            Behavior on border.color {
                enabled: !root.animsFrozen
                CAnim {}
            }
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

            visible: !root.compact
            anchors.fill: parent
            anchors.margins: root.contentPad

            // Preview zone — right, fully inset so pills never kiss the card edge
            CardPreview {
                id: preview

                z: 0
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: root.previewW
                kind: root.kind
                accent: root.accent
                hovered: root.hovered
                visible: true
            }

            // Icon chip — top-left, fixed M3 container (no hover radius morph)
            Rectangle {
                id: plate

                z: 2
                width: root.iconSize
                height: root.iconSize
                radius: Tokens.rounding.normal
                // Per-tile accent container (more alive than flat primaryContainer)
                color: Qt.alpha(root.accent, 0.22)

                anchors.left: parent.left
                anchors.top: parent.top

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.icon
                    fill: 1
                    color: root.accent
                    iconPointSize: root.tall ? Tokens.font.size.large : Tokens.font.size.larger
                }
            }

            // Soft ambient blob behind preview — skip for wallpaper (no grey/underlay behind image)
            Rectangle {
                visible: root.tall && root.kind !== "wallpaper"
                z: 0
                anchors.right: parent.right
                anchors.rightMargin: -root.contentPad * 0.3
                anchors.verticalCenter: parent.verticalCenter
                width: root.previewW * 1.15
                height: width * 0.75
                radius: width / 2
                rotation: -12
                color: Qt.alpha(root.accent, root.hovered ? 0.1 : 0.06)
                opacity: 0.9

                Behavior on color {
                    enabled: !root.animsFrozen
                    CAnim {}
                }
            }

            // Labels — bottom-left. Icon is 36/44 + short tiles leave ≥8px gap.
            Column {
                id: labels

                z: 2
                spacing: 2
                anchors.left: parent.left
                anchors.right: preview.left
                anchors.rightMargin: Tokens.spacing.normal
                anchors.bottom: parent.bottom

                StyledText {
                    width: parent.width
                    text: root.title
                    elide: Text.ElideRight
                    font.weight: Font.Normal
                    font.letterSpacing: -0.1
                    lineHeight: 1.15
                    lineHeightMode: Text.ProportionalHeight
                    color: Colours.palette.m3onSurface
                    textPointSize: Tokens.font.size.larger
                }

                StyledText {
                    width: parent.width
                    visible: !!root.subtitle
                    text: root.subtitle
                    elide: Text.ElideRight
                    color: Colours.palette.m3onSurfaceVariant
                    font.weight: Font.Normal
                    font.letterSpacing: 0.15
                    lineHeight: 1.25
                    lineHeightMode: Text.ProportionalHeight
                    textPointSize: Tokens.font.size.small
                }
            }
        }

        StateLayer {
            id: hover

            anchors.fill: parent
            radius: card.radius
            color: root.accent
            showHoverBackground: false
            showRipple: true
            onClicked: root.clicked()
        }
    }
}
