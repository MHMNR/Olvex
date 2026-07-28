pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import Quickshell
import Olvex.Config
import Olvex.Services
import qs.services

Singleton {
    id: root

    property var values: []
    property string visibleOwner: ""
    property bool isActive: visibleOwner !== ""
    property bool isSettled: true
    readonly property bool publishesValues: visibleOwner.indexOf("background:") === 0
    // Experiment: match the monitor's native refresh rate instead of a fixed
    // 60fps cap, now that the infinite-animation window-pinning sources
    // (spinning play button, wavy seek bar) are gone. Screen.refreshRate can
    // report -1 before a window is realized, hence the fallback.
    readonly property real _screenHz: Screen.refreshRate > 0 ? Screen.refreshRate : 60
    readonly property int frameFps: Math.max(1, Math.round(root._screenHz))
    readonly property int frameInterval: Math.max(1, Math.round(1000 / frameFps))
    readonly property real publishThreshold: 0.006

    // Handoff buffer for visual continuity across ownership transfers (e.g. the
    // bar pill <-> expanded card morph). Each NeonWaveVisualizer Canvas is its
    // own independent instance with its own local smoothValues — without this,
    // morphing destroys the outgoing Canvas and creates a new one that always
    // starts flat at rest and has to ramp up from zero, a visible pop instead
    // of a seamless handoff. The newly-active Canvas seeds from this buffer;
    // whichever Canvas currently owns rendering keeps it updated every tick.
    property var lastBarValues: []

    property var _requests: ({})
    property var _pendingValues: []
    property double _lastPublishMs: 0

    Binding {
        target: Audio.cava
        property: "qmlValuePublishing"
        value: root.publishesValues
    }

    function request(owner: string, priority: int, active: bool): void {
        const next = Object.assign({}, _requests);
        if (active)
            next[owner] = priority;
        else
            delete next[owner];
        _requests = next;
        syncOwner();
    }

    function release(owner: string): void {
        request(owner, 0, false);
    }

    function syncOwner(): void {
        let bestOwner = "";
        let bestPriority = -1;
        const keys = Object.keys(_requests);
        for (let i = 0; i < keys.length; i++) {
            const owner = keys[i];
            const priority = _requests[owner] || 0;
            if (priority > bestPriority || (priority === bestPriority && owner < bestOwner)) {
                bestOwner = owner;
                bestPriority = priority;
            }
        }
        visibleOwner = bestOwner;
        if (!visibleOwner || !publishesValues) {
            publishTimer.stop();
            _pendingValues = [];
            _lastPublishMs = 0;
            values = [];
            isSettled = true;
        }
    }

    function hasMeaningfulDelta(nextValues: var): bool {
        if (!nextValues || nextValues.length === 0)
            return values.length !== 0;
        if (values.length !== nextValues.length)
            return true;

        let maxDelta = 0;
        for (let i = 0; i < nextValues.length; i++) {
            const delta = Math.abs((nextValues[i] || 0) - (values[i] || 0));
            if (delta > maxDelta)
                maxDelta = delta;
            if (maxDelta >= publishThreshold)
                return true;
        }
        return false;
    }

    function publishPending(force: bool): void {
        if (!isActive)
            return;

        const nextValues = _pendingValues || [];
        if (!force && !hasMeaningfulDelta(nextValues))
            return;

        values = nextValues;
        _lastPublishMs = Date.now();
        isSettled = false;
    }

    Connections {
        target: Audio.cava
        enabled: root.publishesValues

        function onValuesChanged(): void {
            root._pendingValues = Audio.cava.values;

            const now = Date.now();
            const shouldPublishImmediately = root.values.length === 0
                || root.isSettled
                || now - root._lastPublishMs >= root.frameInterval;

            if (shouldPublishImmediately) {
                root.publishPending(true);
            } else if (!publishTimer.running) {
                publishTimer.restart();
            }
        }
    }

    Timer {
        id: publishTimer
        interval: root.frameInterval
        repeat: false
        onTriggered: root.publishPending(false)
    }

    Loader {
        active: root.isActive
        sourceComponent: Item {
            ServiceRef {
                service: Audio.cava
            }
        }
    }
}
