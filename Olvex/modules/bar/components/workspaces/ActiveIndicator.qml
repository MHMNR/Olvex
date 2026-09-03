
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

    readonly property Workspace activeWsItem: (workspaces && workspaces.count > currentWsIdx && currentWsIdx >= 0)
        ? (workspaces.itemAt(currentWsIdx) as Workspace) : null

    // Live geometry — directly from the ColumnLayout's current frame
    readonly property real liveY: activeWsItem ? activeWsItem.y : 0
    readonly property real liveH: activeWsItem ? (activeWsItem.currentHeight > 0 ? activeWsItem.currentHeight : activeWsItem.height) : (Tokens.sizes.bar.innerWidth - Tokens.padding.small * 2)

    // ── Trail mode state ────────────────────────────────────────────
    property real leading: liveY
    property real trailing: liveY
    property real trailSize: liveH

    // ── Non-trail: explicit animation for workspace switches ────────
    // During expand/collapse, offset/size bind directly to live geometry
    // with no Behavior (zero lag). On workspace switch, switchAnim
    // interpolates from old position to new.
    property bool switching: false
    property real switchFromY: 0
    property real switchFromH: 0

    property int cWs
    property int lastWs

    onCurrentWsIdxChanged: {
        lastWs = cWs;
        cWs = currentWsIdx;

        if (!Config.bar.workspaces.activeTrail) {
            // Capture current animated values as start point
            switchFromY = root.y - mask.y;
            switchFromH = root.height;
            switching = true;
            switchAnim.restart();
        }
    }

    NumberAnimation {
        id: switchAnim
        target: root
        property: "_switchProgress"
        from: 0; to: 1
        duration: Tokens.anim.durations.expressiveDefaultSpatial
        easing: Tokens.anim.expressiveDefaultSpatial
        onFinished: root.switching = false
    }

    property real _switchProgress: 0

    // ── Final offset/size ───────────────────────────────────────────
    readonly property real offset: {
        if (Config.bar.workspaces.activeTrail)
            return Math.min(leading, trailing);
        if (switching)
            return switchFromY + (liveY - switchFromY) * _switchProgress;
        return liveY;
    }

    readonly property real size: {
        if (Config.bar.workspaces.activeTrail) {
            const s = Math.abs(leading - trailing) + trailSize;
            if (lastWs > currentWsIdx && workspaces.itemAt(lastWs)) {
                const lastItem = workspaces.itemAt(lastWs) as Workspace;
                const lastBottom = lastItem ? lastItem.y + (lastItem.currentHeight > 0 ? lastItem.currentHeight : lastItem.height) : 0;
                return Math.min(lastBottom - offset, s);
            }
            return s;
        }
        if (switching)
            return switchFromH + (liveH - switchFromH) * _switchProgress;
        return liveH;
    }

    clip: true
    y: offset + mask.y
    width: implicitWidth
    height: size
    implicitWidth: Tokens.sizes.bar.innerWidth - Tokens.padding.small * 2
    implicitHeight: size
    radius: Tokens.rounding.full
    color: Colours.light ? Colours.palette.m3primaryContainer : Colours.palette.m3primary

    Colouriser {
        source: root.mask
        sourceColor: Colours.light ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
        colorizationColor: Colours.light ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onPrimary

        y: -root.offset
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

    Behavior on trailSize {
        enabled: root.Config.bar.workspaces.activeTrail

        EAnim {}
    }

    component EAnim: Anim {
        type: Anim.DefaultSpatial
    }
}

