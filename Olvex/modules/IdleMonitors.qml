
import "lock"
import QtQuick
import Quickshell
import Quickshell.Wayland
import Olvex.Config
import Olvex.Internal
import qs.services

Scope {
    id: root

    required property Lock lock
    readonly property bool audioIdleAllowed: !GlobalConfig.general.idle.inhibitWhenAudio || !Players.list.some(p => p.isPlaying)
    readonly property bool keepAwake: IdleInhibitor.enabled === true

    function idleActionKey(entry) {
        const action = entry?.idleAction
        if (action === "lock")
            return "lock"
        if (action === "dpms off")
            return "dpms"
        if (Array.isArray(action))
            return "suspend"
        return ""
    }

    function dedupeIdleTimeouts(list) {
        if (!list || !list.length)
            return []
        const seen = {}
        const out = []
        for (let i = 0; i < list.length; i++) {
            const key = idleActionKey(list[i])
            if (!key || seen[key])
                continue
            seen[key] = true
            out.push(list[i])
        }
        return out
    }

    function sanitizeIdleTimeouts() {
        const raw = GlobalConfig.general.idle.timeouts ?? []
        const deduped = dedupeIdleTimeouts(raw)
        if (deduped.length !== raw.length)
            GlobalConfig.general.idle.timeouts = deduped
    }

    readonly property var idleTimeoutModel: dedupeIdleTimeouts(GlobalConfig.general.idle.timeouts ?? [])

    Timer {
        interval: 0
        running: true
        repeat: false
        onTriggered: root.sanitizeIdleTimeouts()
    }

    function handleIdleAction(action: var): void {
        if (!action || root.keepAwake)
            return;

        if (action === "lock")
            lock.lock.locked = true;
        else if (action === "unlock")
            lock.lock.locked = false;
        else if (typeof action === "string")
            Hypr.dispatch(action);
        else
            Quickshell.execDetached(action);
    }

    LogindManager {
        onAboutToSleep: {
            if (root.keepAwake)
                return;
            if (GlobalConfig.general.idle.lockBeforeSleep)
                root.lock.lock.locked = true;
        }
        onLockRequested: {
            if (!root.keepAwake)
                root.lock.lock.locked = true;
        }
        onUnlockRequested: root.lock.lock.unlock()
    }

    Variants {
        model: root.idleTimeoutModel

        IdleMonitor {
            required property var modelData

            enabled: root.audioIdleAllowed && !root.keepAwake && (modelData.enabled !== false)
            timeout: modelData.timeout
            respectInhibitors: modelData.respectInhibitors ?? true
            onIsIdleChanged: root.handleIdleAction(isIdle ? modelData.idleAction : modelData.returnAction)
        }
    }
}
