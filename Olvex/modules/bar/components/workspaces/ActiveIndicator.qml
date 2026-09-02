
import QtQuick
import Olvex.Config
import qs.components
import qs.components.effects
import qs.services

StyledRect {
    id: root

    required property int activeWsId
    required property Repeater workspaces
    required property Item mask
    required property bool fullscreen

    readonly property int currentWsIdx: {
        let i = activeWsId - 1;
        while (i < 0)
            i += Config.bar.workspaces.shown;
        return i % Config.bar.workspaces.shown;
    }

    property var _occupiedTrack: mask.parent.occupied
    property bool _expandedTrack: mask.parent.expanded

    function getTargetY(idx) {
        let _ = _occupiedTrack;
        let _2 = _expandedTrack;
        if (!workspaces || workspaces.count === 0 || workspaces.count <= idx || idx < 0) return 0;

        let targetY = 0;
        const firstWs = workspaces.itemAt(0) as Workspace;
        if (firstWs) {
            targetY += Math.max(0, (Tokens.sizes.bar.innerWidth / 2) - (firstWs.size / 2) - Tokens.padding.small);
        }

        for (let i = 0; i < idx; i++) {
            const ws = workspaces.itemAt(i) as Workspace;
            if (ws) {
                targetY += ws.size + Tokens.spacing.small;
            }
        }
        return targetY;
    }

    property real leading: getTargetY(currentWsIdx)
    property real trailing: getTargetY(currentWsIdx)
    property real currentSize: {
        let _ = _occupiedTrack;
        let _2 = _expandedTrack;
        return workspaces.count > 0 && currentWsIdx >= 0 && currentWsIdx < workspaces.count ? (workspaces.itemAt(currentWsIdx) ? (workspaces.itemAt(currentWsIdx) as Workspace).size : 0) : 0;
    }
    property real offset: Math.min(leading, trailing)
    property real size: {
        const s = Math.abs(leading - trailing) + currentSize;
        if (Config.bar.workspaces.activeTrail && lastWs > currentWsIdx) {
            return Math.min(getTargetY(lastWs) + (workspaces.itemAt(lastWs) ? (workspaces.itemAt(lastWs) as Workspace).size : 0) - offset, s);
        }
        return s;
    }

    property int cWs
    property int lastWs

    onCurrentWsIdxChanged: {
        lastWs = cWs;
        cWs = currentWsIdx;
    }

    clip: true
    y: offset + mask.y
    width: implicitWidth
    height: size
    implicitWidth: Tokens.sizes.bar.innerWidth - Tokens.padding.small * 2
    implicitHeight: size
    radius: Tokens.rounding.full
    color: Colours.palette.m3primary

    Colouriser {
        source: root.mask
        sourceColor: Colours.palette.m3onSurface
        colorizationColor: Colours.palette.m3onPrimary

        y: -parent.offset
        width: root.mask.width
        height: root.mask.height
        implicitWidth: root.mask.implicitWidth
        implicitHeight: root.mask.implicitHeight

        anchors.horizontalCenter: parent.horizontalCenter
    }

    Behavior on leading {
        enabled: root.Config.bar.workspaces.activeTrail

        EAnim {}
    }

    Behavior on trailing {
        enabled: root.Config.bar.workspaces.activeTrail

        EAnim {
            duration: Tokens.anim.durations.normal * 2
        }
    }

    Behavior on currentSize {
        enabled: root.Config.bar.workspaces.activeTrail

        EAnim {}
    }

    Behavior on offset {
        enabled: !root.Config.bar.workspaces.activeTrail

        EAnim {}
    }

    Behavior on size {
        enabled: !root.Config.bar.workspaces.activeTrail

        EAnim {}
    }

    component EAnim: Anim {
        type: Anim.DefaultSpatial
    }
}
