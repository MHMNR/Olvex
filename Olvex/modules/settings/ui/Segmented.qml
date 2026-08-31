pragma ComponentBehavior: Bound


import ".."
import "."
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.services

// Sliding-pill segmented control — same language as standalone clipboard FilterButtonGroup:
// solid secondaryContainer track + primary sliding indicator.
Item {
    id: root

    // model: list of { label: string, icon?: string } or plain strings
    property var model: []
    property int currentIndex: 0
    property real minSegmentWidth: 0

    signal selected(int index)

    readonly property int count: model ? model.length : 0
    readonly property real inset: 4

    function labelOf(entry): string {
        if (typeof entry === "string")
            return entry;
        return entry?.label ?? "";
    }

    function iconOf(entry): string {
        if (typeof entry === "string")
            return "";
        return entry?.icon ?? "";
    }
    
    function isDisabled(entry): bool {
        if (typeof entry === "string")
            return false;
        return !!entry?.disabled;
    }

    readonly property bool hasIcons: {
        if (!model || model.length === 0)
            return false;
        for (let i = 0; i < model.length; i++) {
            if (iconOf(model[i]).length > 0)
                return true;
        }
        return false;
    }

    // Content-based slot width (no TextMetrics — Tokens needs a screen there)
    readonly property real contentSlotW: {
        let maxChars = 1;
        if (root.model) {
            for (let i = 0; i < root.model.length; i++) {
                const n = root.labelOf(root.model[i]).length;
                if (n > maxChars)
                    maxChars = n;
            }
        }
        const pad = 28;
        const icon = root.hasIcons ? 22 : 0;
        const text = maxChars * 7.5 + 6;
        return Math.ceil(pad + icon + text);
    }

    readonly property real resolvedSegmentWidth: Math.max(root.minSegmentWidth, root.contentSlotW, root.hasIcons ? 88 : 72)

    implicitWidth: resolvedSegmentWidth * Math.max(count, 1)
    implicitHeight: 40

    // Outer track — solid, always visible (not tileFill glass)
    StyledRect {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: Qt.alpha(Colours.palette.m3onSurface, 0.12)

        // Sliding primary pill
        StyledRect {
            id: indicator

            readonly property int safeIndex: Math.max(0, Math.min(root.currentIndex, Math.max(root.count - 1, 0)))
            readonly property real slotW: root.count > 0 ? (track.width - root.inset * 2) / root.count : 0

            x: root.inset + safeIndex * slotW
            y: root.inset
            width: Math.max(0, slotW)
            height: track.height - root.inset * 2
            radius: height / 2
            color: Colours.palette.m3primary
            z: 0

            Behavior on x {
                Anim { type: Anim.FastSpatial }
            }
            Behavior on width {
                Anim { type: Anim.FastSpatial }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: root.inset
            spacing: 0
            z: 1

            Repeater {
                model: root.model

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index

                    readonly property bool active: root.currentIndex === index
                    readonly property string label: root.labelOf(modelData)
                    readonly property string icon: root.iconOf(modelData)
                    readonly property bool isDisabled: root.isDisabled(modelData)

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: root.resolvedSegmentWidth - root.inset
                    opacity: isDisabled ? 0.35 : 1.0

                    Row {
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.extraSmall

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !!cell.icon
                            text: cell.icon
                            fill: cell.active ? 1 : 0
                            color: cell.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                            iconPointSize: Tokens.font.size.normal

                            Behavior on color {
                                CAnim {}
                            }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: cell.label
                            font.weight: cell.active ? Font.Medium : Font.Normal
                            font.letterSpacing: 0.15
                            color: cell.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                            textPointSize: Tokens.font.size.smaller
                            elide: Text.ElideNone

                            Behavior on color {
                                CAnim {}
                            }
                        }
                    }
                    StyledRect {
                        anchors.fill: parent
                        radius: height / 2
                        color: Colours.palette.m3onSurface
                        opacity: segMa.pressed ? 0.1 : (segMa.containsMouse && !cell.active ? 0.08 : 0)

                        Behavior on opacity {
                            Anim { type: Anim.FastEffects }
                        }
                    }

                    MouseArea {
                        id: segMa
                        anchors.fill: parent
                        enabled: !cell.isDisabled && root.enabled
                        hoverEnabled: !cell.isDisabled && root.enabled
                        cursorShape: (cell.isDisabled || !root.enabled) ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (cell.isDisabled || !root.enabled) return;
                            if (root.currentIndex !== cell.index)
                                root.selected(cell.index);
                        }
                    }
                }
            }
        }
    }
}
