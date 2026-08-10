import QtQuick
import QtQuick.Layouts
import QtQuick.Templates
import Olvex.Config
import qs.components
import qs.services

// M3 sliding switch — same language as standalone clipboard FilterButtonGroup:
// solid track + primary sliding thumb with spring travel.
Switch {
    id: root

    property int cLayer: 1

    // Track scales with type size so UI scale / large fonts stay proportional
    readonly property real trackH: Math.max(28, Math.round((Tokens.font?.size?.normal ?? 13) * 2.15))
    readonly property real trackW: Math.round(trackH * 52 / 32)
    readonly property real thumbOn: Math.round(trackH * 24 / 32)
    readonly property real thumbOff: Math.round(trackH * 16 / 32)
    readonly property real trackInset: 4

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
        // Clipboard filter track: secondaryContainer off / primary on
        color: {
            if (!root.enabled)
                return Qt.alpha(Colours.palette.m3onSurface, 0.12);
            return root.checked ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer;
        }

        Behavior on color {
            ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        // Hover / press wash (ClipboardStandalone pattern: fades out when active/checked)
        StyledRect {
            anchors.fill: parent
            radius: parent.radius
            color: Colours.palette.m3onSurface
            opacity: !root.enabled ? 0 : root.pressed ? 0.1 : (root.hovered && !root.checked) ? 0.08 : 0

            Behavior on opacity {
                NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
            }
        }

        // Sliding thumb
        StyledRect {
            id: thumb

            readonly property real baseSize: root.checked ? root.thumbOn : root.thumbOff
            readonly property real targetSize: root.pressed ? Math.min(baseSize * 1.12, track.height - root.trackInset * 2) : baseSize
            readonly property real margin: Math.max(root.trackInset, (track.height - targetSize) / 2)

            width: targetSize
            height: targetSize
            implicitWidth: targetSize
            implicitHeight: targetSize
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? track.width - width - margin : margin
            color: {
                if (!root.enabled)
                    return Qt.alpha(Colours.palette.m3onSurface, 0.38);
                // On: onPrimary; off: solid outline on secondary track (readable)
                return root.checked ? Colours.palette.m3onPrimary : Colours.palette.m3outline;
            }

            Behavior on x {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
            Behavior on width {
                NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
            }
            Behavior on height {
                NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: "check"
                visible: root.checked && thumb.width >= Math.max(16, root.thumbOn * 0.8)
                color: Colours.palette.m3primary
                fill: 1
                iconPointSize: Math.max(10, thumb.width * 0.5)
                opacity: root.enabled ? 0.9 : 0.38

                Behavior on color {
                    ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }
        }



        HoverHandler {
            enabled: root.enabled
            cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
    }
}
