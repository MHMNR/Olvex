
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Olvex.Config
import qs.components
import qs.services

StyledClippingRect {
    id: root

    required property ShellScreen screen
    required property bool fullscreen

    readonly property bool onSpecial: (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? Hypr.monitorFor(screen) : Hypr.focusedMonitor)?.lastIpcObject.specialWorkspace?.name !== ""
    readonly property int activeWsId: GlobalConfig.bar.workspaces.perMonitorWorkspaces ? (Hypr.monitorFor(screen).activeWorkspace?.id ?? 1) : Hypr.activeWsId

    property var occupied: ({})

    function updateOccupied(): void {
        let changed = false;
        const next = {};
        const values = Hypr.workspaces.values || [];
        for (let i = 0; i < values.length; i++) {
            const ws = values[i];
            const hasWin = (ws.lastIpcObject?.windows ?? 0) > 0;
            next[ws.id] = hasWin;
            if (root.occupied[ws.id] !== hasWin)
                changed = true;
        }
        if (changed || Object.keys(next).length !== Object.keys(root.occupied).length) {
            root.occupied = next;
        }
    }

    Connections {
        target: Hypr.workspaces
        function onValuesChanged(): void {
            root.updateOccupied();
        }
    }

    Component.onCompleted: root.updateOccupied()
    readonly property int groupOffset: Math.floor((activeWsId - 1) / Config.bar.workspaces.shown) * Config.bar.workspaces.shown

    // Debounced rather than a direct binding to hoverArea.containsMouse —
    // tolerates brief hover-loss blips (edge of the hit-region, a frame where
    // the animating layout hasn't quite caught up yet) instead of instantly
    // snapping collapsed the moment the cursor grazes outside.
    property bool expanded: false
    onExpandedChanged: if (!expanded) collapseTimer.stop()

    Timer {
        id: collapseTimer
        interval: 220
        onTriggered: root.expanded = false
    }

    // Full potential height if every slot were showing detail right now —
    // NOT the animated/springy visual height. The hover hit-region below is
    // sized off this (not off the lagging animated height) so moving the
    // cursor toward not-yet-expanded slots never outruns the hit-test area
    // mid-animation and snaps back collapsed.
    readonly property int expandedContentHeight: {
        let h = 0;
        for (let i = 0; i < wsRepeater.count; i++) {
            const item = wsRepeater.itemAt(i);
            h += item ? item.detailHeight : 0;
        }
        return h + Math.max(0, wsRepeater.count - 1) * layout.spacing;
    }

    property real blur: onSpecial ? 1 : 0

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: layout.implicitHeight + Tokens.padding.small * 2

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    Behavior on implicitHeight {
        Anim {
            type: Anim.DefaultSpatial
        }
    }



    MouseArea {
        id: hoverArea
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: Math.max(parent.height, root.expandedContentHeight + Tokens.padding.small * 2)
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true

        onContainsMouseChanged: {
            if (containsMouse) {
                collapseTimer.stop();
                root.expanded = true;
            } else {
                collapseTimer.restart();
            }
        }
    }

    Item {
        anchors.fill: parent
        scale: root.onSpecial ? 0.8 : 1
        opacity: root.onSpecial ? 0.5 : 1
        visible: !root.fullscreen

        layer.enabled: root.blur > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.blur
            blurMax: 32
        }

        ColumnLayout {
            id: layout

            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            Repeater {
                id: wsRepeater

                model: Config.bar.workspaces.shown

                Workspace {
                    activeWsId: root.activeWsId
                    occupied: root.occupied
                    groupOffset: root.groupOffset
                    expanded: root.expanded
                }
            }
        }

        Loader {
            asynchronous: true
            anchors.horizontalCenter: parent.horizontalCenter
            active: Config.bar.workspaces.activeIndicator

            sourceComponent: ActiveIndicator {
                activeWsId: root.activeWsId
                workspaces: wsRepeater
                mask: layout
                fullscreen: root.fullscreen
            }
        }

        MouseArea {
            anchors.fill: layout
            onClicked: event => {
                const ws = (layout.childAt(event.x, event.y) as Workspace)?.ws;
                if (Hypr.activeWsId !== ws)
                    Hypr.dispatch(`workspace ${ws}`);
                else
                    Hypr.dispatch("togglespecialworkspace special");
            }
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {}
        }
    }

    Loader {
        id: specialWs

        asynchronous: true

        anchors.fill: parent
        anchors.margins: Tokens.padding.small

        active: opacity > 0

        scale: root.onSpecial ? 1 : 0.5
        opacity: root.onSpecial ? 1 : 0

        sourceComponent: SpecialWorkspaces {
            screen: root.screen
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {}
        }
    }

    Behavior on blur {
        Anim {
            type: Anim.StandardSmall
        }
    }
}
