

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

    readonly property int contentPad: 15
    readonly property int iconSize: root.tall ? 44 : 32
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

        // Tonal wash (hover lifts surface, no shape morph)
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            // Refined subtle accent wash — balanced professional grade
            color: Qt.alpha(root.accent, root.hovered ? 0.045 : 0.012)

            Behavior on color {
                enabled: !root.animsFrozen
                CAnim {}
            }
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

            visible: !root.compact
            anchors.fill: parent
            anchors.margins: root.contentPad

            // Preview zone — right (or top-left for sound/power meters)
            CardPreview {
                id: preview

                z: 0
                anchors.left: (root.kind === "sound" || root.kind === "power") ? parent.left : undefined
                anchors.right: (root.kind === "sound" || root.kind === "power") ? undefined : parent.right
                anchors.top: parent.top
                anchors.bottom: (root.kind === "sound" || root.kind === "power") ? undefined : parent.bottom
                width: (root.kind === "sound" || root.kind === "power") ? 38 : root.previewW
                height: (root.kind === "sound" || root.kind === "power") ? 38 : undefined
                kind: root.kind
                accent: root.accent
                hovered: root.hovered
                visible: true
            }

            // Circular icon chip — top-left (hidden on sound/power which have top progress ring)
            Rectangle {
                id: plate

                visible: root.kind !== "sound" && root.kind !== "power"
                z: 2
                width: 32
                height: 32
                radius: 16
                color: Qt.alpha(Colours.palette.m3onSurface, 0.08)

                anchors.left: parent.left
                anchors.top: parent.top

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.icon
                    fill: 1
                    color: root.accent
                    iconPointSize: 16
                }
            }

            // Labels — bottom-left
            Column {
                id: labels

                readonly property bool fullWidthLabels: root.kind === "sound" || root.kind === "power" || root.kind === "notifications" || root.kind === "panels"

                z: 2
                spacing: 2
                anchors.left: parent.left
                anchors.right: (fullWidthLabels || root.kind === "appearance") ? parent.right : preview.left
                anchors.rightMargin: root.kind === "appearance" ? 72 : (fullWidthLabels ? 0 : Tokens.spacing.normal)
                anchors.bottom: parent.bottom

                StyledText {
                    width: parent.width
                    text: root.title
                    elide: Text.ElideRight
                    font.weight: Font.Medium
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
                    font.letterSpacing: 0.1
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
