import QtQuick
import QtQuick.Layouts
import QtQuick.Templates
import Olvex.Config
import qs.components
import qs.services

// M3 sliding switch — authentic Material 3 Expressive morph & spring physics:
// High-contrast track + morphing sliding thumb with checkmark scale transition.
Switch {
    id: root

    property int cLayer: 1
    property bool isReady: false
    Component.onCompleted: isReady = true

    // Track scales with type size so UI scale / large fonts stay proportional
    readonly property real trackH: Math.max(28, Math.round((Tokens.font?.size?.normal ?? 13) * 2.15))
    readonly property real trackW: Math.round(trackH * 52 / 32)
    readonly property real thumbOn: Math.round(trackH * 24 / 32)
    readonly property real thumbOff: Math.round(trackH * 16 / 32)
    readonly property real trackInset: Math.max(4, Math.round((trackH - thumbOn) / 2))

    // Expressive morphing states (elongates when pressed/moving)
    readonly property real thumbMorphW: root.pressed ? Math.round(trackH * 28 / 32) : (root.checked ? root.thumbOn : root.thumbOff)
    readonly property real thumbMorphH: root.pressed ? Math.round(trackH * 22 / 32) : (root.checked ? root.thumbOn : root.thumbOff)

    implicitWidth: trackW
    implicitHeight: trackH
    width: trackW
    height: trackH
    padding: 0
    spacing: 0
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

    Layout.preferredWidth: trackW
    Layout.preferredHeight: trackH
    Layout.maximumWidth: trackW
    Layout.maximumHeight: trackH
    Layout.fillWidth: false
    Layout.fillHeight: false
    Layout.alignment: Qt.AlignVCenter

    hoverEnabled: true

    contentItem: Item {
        implicitWidth: 0
        implicitHeight: 0
        width: 0
        height: 0
    }

    indicator: StyledRect {
        id: track

        width: root.trackW
        height: root.trackH
        implicitWidth: root.trackW
        implicitHeight: root.trackH
        radius: height / 2

        color: {
            if (!root.enabled)
                return Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.38);
            return root.checked ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest;
        }
        border.width: root.checked ? 0 : 2
        border.color: {
            if (!root.enabled)
                return Qt.alpha(Colours.palette.m3outline, 0.38);
            if (root.checked)
                return "transparent";
            return root.hovered ? Colours.palette.m3onSurface : Colours.palette.m3outline;
        }

        Behavior on color {
            enabled: root.isReady
            ColorAnimation { duration: Tokens?.anim?.durations?.normal ?? 220; easing.type: Easing.OutCubic }
        }
        Behavior on border.color {
            enabled: root.isReady
            ColorAnimation { duration: Tokens?.anim?.durations?.normal ?? 220; easing.type: Easing.OutCubic }
        }
        Behavior on border.width {
            enabled: root.isReady
            NumberAnimation { duration: Tokens?.anim?.durations?.fast ?? 160; easing.type: Easing.OutCubic }
        }

        // State layer halo around thumb
        StyledRect {
            id: stateHalo
            anchors.centerIn: thumb
            width: Math.round(track.height * 38 / 32)
            height: width
            radius: width / 2
            color: root.checked ? Colours.palette.m3primary : Colours.palette.m3onSurface
            opacity: !root.enabled ? 0 : root.pressed ? 0.14 : (root.hovered ? 0.08 : 0)
            z: 0

            Behavior on opacity {
                enabled: root.isReady
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                enabled: root.isReady
                ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
        }

        // Sliding & Morphing Thumb
        StyledRect {
            id: thumb

            width: root.thumbMorphW
            height: root.thumbMorphH
            implicitWidth: width
            implicitHeight: height
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter
            z: 1

            x: root.checked ? (track.width - width - Math.round((track.height - width) / 2)) : Math.round((track.height - width) / 2)

            color: {
                if (!root.enabled)
                    return Qt.alpha(Colours.palette.m3onSurface, 0.38);
                return root.checked ? Colours.palette.m3onPrimary : (root.hovered ? Colours.palette.m3onSurface : Colours.palette.m3outline);
            }

            Behavior on x {
                enabled: root.isReady
                NumberAnimation {
                    duration: Tokens?.anim?.durations?.normal ?? 260
                    easing: Tokens?.anim?.emphasized ?? Easing.bezierCurve(0.2, 0.0, 0.0, 1.0)
                }
            }
            Behavior on width {
                enabled: root.isReady
                NumberAnimation {
                    duration: Tokens?.anim?.durations?.fast ?? 180
                    easing: Tokens?.anim?.emphasizedDecel ?? Easing.OutBack
                }
            }
            Behavior on height {
                enabled: root.isReady
                NumberAnimation {
                    duration: Tokens?.anim?.durations?.fast ?? 180
                    easing: Tokens?.anim?.emphasizedDecel ?? Easing.OutBack
                }
            }
            Behavior on color {
                enabled: root.isReady
                ColorAnimation {
                    duration: Tokens?.anim?.durations?.normal ?? 220
                    easing.type: Easing.OutCubic
                }
            }

            // Morphing Checkmark (smooth scale & fade)
            MaterialIcon {
                id: checkIcon
                anchors.centerIn: parent
                text: "check"
                fill: 1
                color: Colours.palette.m3primary
                iconPointSize: Math.max(10, Math.round(thumb.height * 0.55))
                opacity: root.checked && root.enabled && thumb.width >= (root.thumbOn * 0.75) ? 1.0 : 0.0
                scale: root.checked ? 1.0 : 0.2
                visible: opacity > 0.01

                Behavior on opacity {
                    enabled: root.isReady
                    NumberAnimation { duration: Tokens?.anim?.durations?.fast ?? 160; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    enabled: root.isReady
                    NumberAnimation { duration: Tokens?.anim?.durations?.normal ?? 220; easing: Tokens?.anim?.emphasizedDecel ?? Easing.OutBack }
                }
                Behavior on color {
                    enabled: root.isReady
                    ColorAnimation { duration: Tokens?.anim?.durations?.normal ?? 220; easing.type: Easing.OutCubic }
                }
            }
        }

        HoverHandler {
            enabled: root.enabled
            cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
    }
}
