pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Olvex
import Olvex.Config
import qs.components.misc
import qs.services
import qs.utils

Singleton {
    id: root

    property list<NotifData> list: []
    readonly property list<NotifData> notClosed: list.filter(n => !n.closed)
    readonly property list<NotifData> popups: list.filter(n => n.popup)
    property alias dnd: props.dnd

    // ── Bar Notification Pill State ──
    property NotifData currentBarNotif: null
    readonly property bool hasBarNotif: currentBarNotif !== null && !currentBarNotif.closed
    property list<NotifData> barQueue: []
    readonly property var allBarNotifs: {
        let res = [];
        if (root.currentBarNotif && !root.currentBarNotif.closed)
            res.push(root.currentBarNotif);
        for (let i = 0; i < root.barQueue.length; i++) {
            const n = root.barQueue[i];
            if (n && !n.closed && !res.includes(n))
                res.push(n);
        }
        return res;
    }
    readonly property int barNotifCount: allBarNotifs.length
    property var _notifMorphByScreen: ({})
    property var notifMorph: null
    property bool notifMorphActive: false
    property bool notifMorphAnimating: false
    property var activeMorphNotif: null
    readonly property bool notifMorphRendering: notifMorphActive || notifMorphAnimating

    function registerNotifMorph(screenName: string, overlay: var): void {
        if (!screenName || !overlay)
            return;
        const map = Object.assign({}, root._notifMorphByScreen);
        map[screenName] = overlay;
        root._notifMorphByScreen = map;
        root.notifMorph = overlay;
    }

    function unregisterNotifMorph(screenName: string, overlay: var): void {
        if (!screenName)
            return;
        const map = Object.assign({}, root._notifMorphByScreen);
        if (map[screenName] === overlay) {
            delete map[screenName];
            root._notifMorphByScreen = map;
            if (root.notifMorph === overlay)
                root.notifMorph = Object.values(map)[0] ?? null;
        }
    }

    function notifMorphForScreen(screenName: string): var {
        if (!screenName)
            return root.notifMorph;
        return root._notifMorphByScreen[screenName] ?? root.notifMorph;
    }

    signal notificationPushed(var newNotif, var oldNotif)
    signal notificationPopped(var poppedNotif, var newTopNotif)

    function showInBar(comp: NotifData): void {
        if (!comp || comp.closed)
            return;
        const prev = (root.currentBarNotif && !root.currentBarNotif.closed) ? root.currentBarNotif : null;
        if (prev === null) {
            root.currentBarNotif = comp;
            root.notificationPushed(comp, null);
        } else if (prev !== comp) {
            root.barQueue = [prev, ...root.barQueue.filter(n => !n.closed && n !== comp && n !== prev)];
            root.currentBarNotif = comp;
            root.notificationPushed(comp, prev);
        }
        barExpireTimer.interval = Math.max(7000, comp.expireTimeout > 0 ? comp.expireTimeout : 8000);
        barExpireTimer.restart();
    }

    function dismissNotif(notif: var): void {
        if (!notif) {
            dismissBarNotif();
            return;
        }
        if (root.currentBarNotif === notif) {
            dismissBarNotif();
        } else {
            root.barQueue = root.barQueue.filter(n => n !== notif && !n.closed);
        }
    }

    function dismissBarNotif(): void {
        barExpireTimer.stop();
        const popped = root.currentBarNotif;
        const nextQueue = root.barQueue.filter(n => !n.closed && n !== root.currentBarNotif);
        if (nextQueue.length > 0) {
            const next = nextQueue[0];
            root.barQueue = nextQueue.slice(1);
            root.currentBarNotif = next;
            root.notificationPopped(popped, next);
            barExpireTimer.interval = Math.max(7000, next.expireTimeout > 0 ? next.expireTimeout : 8000);
            barExpireTimer.restart();
        } else {
            root.barQueue = [];
            root.currentBarNotif = null;
            root.notificationPopped(popped, null);
        }
    }

    Timer {
        id: barExpireTimer
        repeat: false
        onTriggered: {
            if (root.notifMorph?.active) {
                // Don't auto-dismiss while overlay card is open
                return;
            }
            root.dismissBarNotif();
        }
    }

    property bool loaded

    function hasFullscreen(): bool {
        for (const monitor of Hypr.monitors.values) {
            if (monitor?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1))
                return true;
        }
        return false;
    }

    function shouldShowPopup(): bool {
        if (props.dnd || [...Visibilities.screens.values()].some(v => v.sidebar))
            return false;
        if (GlobalConfig.notifs.fullscreen === "off" && hasFullscreen())
            return false;
        return true;
    }

    onDndChanged: {
        if (!GlobalConfig.qspanel.toasts.dndChanged)
            return;

        if (dnd)
            Toaster.toast(qsTr("Do not disturb on"), "", "do_not_disturb_on");
        else
            Toaster.toast(qsTr("Do not disturb off"), "", "do_not_disturb_off");
    }

    onListChanged: {
        if (loaded)
            saveTimer.restart();
    }

    Timer {
        id: saveTimer

        interval: 1000
        onTriggered: storage.setText(JSON.stringify(root.notClosed.map(n => ({
                    time: n.time,
                    id: n.id,
                    summary: n.summary,
                    body: n.body,
                    appIcon: n.appIcon,
                    appName: n.appName,
                    image: n.image,
                    expireTimeout: n.expireTimeout,
                    urgency: n.urgency,
                    resident: n.resident,
                    hasActionIcons: n.hasActionIcons,
                    actions: n.actions
                }))))
    }

    PersistentProperties {
        id: props

        property bool dnd

        reloadableId: "notifs"
    }

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notif => {
            notif.tracked = true;

            const comp = notifComp.createObject(root, {
                popup: false, // Disabling top-right popup in favor of bar notification pill
                notification: notif
            });
            root.list = [comp, ...root.list];
            if (root.shouldShowPopup()) {
                root.showInBar(comp);
            }
        }
    }

    FileView {
        id: storage

        printErrors: false
        path: `${Paths.state}/notifs.json`
        onLoaded: {
            const data = JSON.parse(text());
            for (const notif of data)
                root.list.push(notifComp.createObject(root, notif));
            root.list.sort((a, b) => b.time - a.time);
            root.loaded = true;
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.loaded = true;
                Qt.callLater(() => setText("[]"));
            }
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "clearNotifs"
        description: "Clear all notifications"
        onPressed: {
            for (const notif of root.list.slice())
                notif.close();
        }
    }

    IpcHandler {
        function clear(): void {
            for (const notif of root.list.slice())
                notif.close();
        }

        function isDndEnabled(): bool {
            return props.dnd;
        }

        function toggleDnd(): void {
            props.dnd = !props.dnd;
        }

        function enableDnd(): void {
            props.dnd = true;
        }

        function disableDnd(): void {
            props.dnd = false;
        }

        target: "notifs"
    }

    Component {
        id: notifComp

        NotifData {}
    }
}
