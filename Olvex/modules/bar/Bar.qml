
import "popouts" as BarPopouts
import "components"
import "components/workspaces"
import "../olvex/bar" as OlvexBar
import QtQuick
import QtQuick.Layouts
import Quickshell
import Olvex.Config
import qs.components
import qs.services

ColumnLayout {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen
    property var mediaMorph
    property var notificationMorph
    readonly property int vPadding: Tokens.padding.large
    readonly property alias osIcon: osIconWrapper

    function expandMediaMorphFromPill(pill: Item, art: Item, controls: Item,
                                      accent: color, buttonSize: int): void {
        const morph = root.mediaMorph;
        if (!morph || !pill || pill.width <= 0 || pill.height <= 0)
            return;

        const anchor = morph.parent ?? morph;
        const pos = pill.mapToItem(anchor, 0, 0);
        const artPos = art.mapToItem(anchor, 0, 0);
        const b1 = controls.children[0].mapToItem(anchor, 0, 0);
        const b2 = controls.children[1].mapToItem(anchor, 0, 0);
        const b3 = controls.children[2].mapToItem(anchor, 0, 0);

        morph.start(
            pos.x, pos.y, pill.width, pill.height, accent,
            artPos.x - pos.x, artPos.y - pos.y, art.width, art.height,
            b1.x - pos.x, b1.y - pos.y,
            b2.x - pos.x, b2.y - pos.y,
            b3.x - pos.x, b3.y - pos.y,
            buttonSize
        );
    }

    function expandNotificationMorphFromPill(pill: Item, iconItem: Item, contentItem: Item, notifData: var): void {
        const morph = root.notificationMorph;
        if (!morph || !pill || pill.width <= 0 || pill.height <= 0)
            return;

        const anchor = morph.parent ?? morph;
        const pos = pill.mapToItem(anchor, 0, 0);
        const iconPos = iconItem ? iconItem.mapToItem(anchor, 0, 0) : pos;
        const iW = iconItem ? iconItem.width : pill.width;
        const iH = iconItem ? iconItem.height : pill.height;

        morph.start(
            pos.x, pos.y, pill.width, pill.height,
            iconPos.x - pos.x, iconPos.y - pos.y, iW, iH,
            notifData
        );
    }
    // OS/launcher icon is pinned to the bar bottom — never part of reorderable entries.
    readonly property var barEntries: (Config.bar.entries ?? []).filter(entry => entry.id !== "logo")

    readonly property bool isMusicMode: {
        if (Notifs.hasBarNotif)
            return false;
        for (let i = 0; i < repeater.count; i++) {
            const loader = repeater.itemAt(i);
            if (loader?.enabled && loader.id === "activeWindow") {
                const aw = loader.item;
                return aw ? (aw.playerActive || aw.isMusicClosing) : false;
            }
        }
        return false;
    }

    function closeTray(): void {
        if (!Config.bar.tray.compact)
            return;

        for (let i = 0; i < repeater.count; i++) {
            const loader = repeater.itemAt(i);
            if (!loader?.enabled || loader.id !== "tray")
                continue;
            const tray = loader.item;
            if (tray)
                tray.expanded = false;
        }
    }

    function checkPopout(y: real): void {
        const ch = childAt(width / 2, y) as WrappedLoader;

        if (ch?.id !== "tray")
            closeTray();

        if (!ch) {
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.id;
        const top = ch.y;

        if (id === "systemPill" && Config.bar.popouts.systemPill) {
            const systemPill = ch.item;
            if (!systemPill) {
                popouts.hasCurrent = false;
                return;
            }
            const items = systemPill.item;
            if (!items) {
                popouts.hasCurrent = false;
                return;
            }
            const localY = mapToItem(items, 0, y).y;
            let icon = items.childAt(items.width / 2, localY);
            // Walk into group hosts if needed; only use nodes with a popout `name`
            if (icon && (!icon.name || icon.name.length === 0) && icon.children) {
                const nested = icon.childAt(icon.width / 2, localY - icon.y);
                if (nested && nested.name && nested.name.length)
                    icon = nested;
            }
            if (icon && icon.name && icon.name.length) {
                popouts.currentName = icon.name;
                popouts.currentCenter = Qt.binding(() => icon.mapToItem(root, 0, icon.implicitHeight / 2).y);
                popouts.hasCurrent = true;
            } else {
                popouts.hasCurrent = false;
            }
        } else if (id === "tray" && Config.bar.popouts.tray) {
            const tray = ch.item;
            if (!tray) {
                popouts.hasCurrent = false;
                return;
            }
            if (!Config.bar.tray.compact || (tray.expanded && !tray.expandIcon.contains(mapToItem(tray.expandIcon, tray.implicitWidth / 2, y)))) {
                const index = Math.floor(((y - top - tray.padding * 2 + tray.spacing) / tray.layout.implicitHeight) * tray.items.count);
                const trayItem = tray.items.itemAt(index);
                if (trayItem) {
                    popouts.currentName = `traymenu${index}`;
                    popouts.currentCenter = Qt.binding(() => trayItem.mapToItem(root, 0, trayItem.implicitHeight / 2).y);
                    popouts.hasCurrent = true;
                } else {
                    popouts.hasCurrent = false;
                }
            } else {
                popouts.hasCurrent = false;
                tray.expanded = true;
            }
        }
    }

    function handleWheel(y: real, angleDelta: point): void {
        const ch = childAt(width / 2, y) as WrappedLoader;
        if (ch?.id === "workspaces" && Config.bar.scrollActions.workspaces) {
            // Workspace scroll
            const mon = (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? Hypr.monitorFor(screen) : Hypr.focusedMonitor);
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hypr.dispatch(`togglespecialworkspace ${specialWs.slice(8)}`);
            else if (angleDelta.y < 0 || (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? mon.activeWorkspace?.id : Hypr.activeWsId) > 1)
                Hypr.dispatch(`workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
        } else if (y < screen.height / 2 && Config.bar.scrollActions.volume) {
            // Volume scroll on top half
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            // Brightness scroll on bottom half
            const monitor = Brightness.getMonitorForScreen(screen);
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
        }
    }

    spacing: Tokens.spacing.normal

    Repeater {
        id: repeater

        model: root.barEntries

        DelegateChooser {
            role: "id"

            DelegateChoice {
                roleValue: "spacer"
                delegate: WrappedLoader {
                    visible: false
                    Layout.fillHeight: false
                }
            }
            DelegateChoice {
                roleValue: "workspaces"
                delegate: WrappedLoader {
                    sourceComponent: Workspaces {
                        screen: root.screen
                        fullscreen: root.fullscreen
                    }
                }
            }
            DelegateChoice {
                roleValue: "activeWindow"
                delegate: WrappedLoader {
                    visible: !root.fullscreen

                    // Music pill keeps its fixed musicPillHeight (don't stretch
                    // the controls). Non-music pill flexes: the ColumnLayout
                    // hands it whatever's left, and compresses it when the
                    // workspace pill above expands — pills below stay put.
                    Layout.fillHeight: true
                    Layout.minimumHeight: item ? (item.isNotificationPushed ? (item.musicPillWidth * 2 + Tokens.spacing.small) : 64) : 64
                    Layout.maximumHeight: item ? item.animatedMaxHeight : 0
                    sourceComponent: ActiveWindow {
                        bar: root
                        monitor: Brightness.getMonitorForScreen(root.screen)
                    }
                }
            }
            DelegateChoice {
                roleValue: "tray"
                delegate: WrappedLoader {
                    visible: !root.fullscreen
                    sourceComponent: Tray {}
                }
            }
            DelegateChoice {
                roleValue: "clock"
                delegate: WrappedLoader {
                    visible: !root.fullscreen
                    sourceComponent: Clock {}
                }
            }
            DelegateChoice {
                roleValue: "systemPill"
                delegate: WrappedLoader {
                    visible: !root.fullscreen
                    sourceComponent: ColumnLayout {
                        spacing: Tokens.spacing.normal
                        implicitWidth: Tokens.sizes.bar.innerWidth
                        OlvexBar.NetSpeedWidget { Layout.alignment: Qt.AlignHCenter }
                        StatusIcons { Layout.alignment: Qt.AlignHCenter }
                    }
                }
            }
            DelegateChoice {
                roleValue: "power"
                delegate: WrappedLoader {
                    // Force disable power button completely
                    active: false
                    visible: false
                    width: 0
                    height: 0
                }
            }
        }
    }

    component WrappedLoader: Loader {
        id: wrapperItem
        required enabled
        required property string id
        required property int index

        function findFirstEnabled(): Item {
            const count = repeater.count;
            for (let i = 0; i < count; i++) {
                const item = repeater.itemAt(i);
                if (item?.enabled)
                    return item;
            }
            return null;
        }

        asynchronous: true
        Layout.alignment: Qt.AlignHCenter

        // Top padding on first entry; bottom padding is on the hardcoded OsIcon below.
        Layout.topMargin: findFirstEnabled() === this ? root.vPadding : 0

        visible: enabled
        active: enabled

        property real entryXOffset: -50
        opacity: 0
        transform: Translate { x: wrapperItem.entryXOffset }

        Component.onCompleted: {
            if (enabled) {
                entryAnim.start();
            }
        }

        SequentialAnimation {
            id: entryAnim
            PauseAnimation { duration: wrapperItem.index * 45 }
            ParallelAnimation {
                NumberAnimation {
                    target: wrapperItem
                    property: "entryXOffset"
                    to: 0
                    duration: Tokens.anim.durations.expressiveDefaultSpatial
                    easing: Tokens.anim.expressiveDefaultSpatial
                }
                NumberAnimation {
                    target: wrapperItem
                    property: "opacity"
                    to: 1
                    duration: Tokens.anim.durations.expressiveDefaultEffects
                    easing: Tokens.anim.expressiveDefaultEffects
                }
            }
        }
    }

    Item {
        id: osIconWrapper
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: root.vPadding
        implicitWidth: osIconLoader.implicitWidth
        implicitHeight: osIconLoader.implicitHeight

        property real entryXOffset: -50
        opacity: 0
        transform: Translate { x: osIconWrapper.entryXOffset }

        Component.onCompleted: {
            entryAnim.start();
        }

        SequentialAnimation {
            id: entryAnim
            PauseAnimation { duration: root.barEntries.length * 45 }
            ParallelAnimation {
                NumberAnimation {
                    target: osIconWrapper
                    property: "entryXOffset"
                    to: 0
                    duration: Tokens.anim.durations.expressiveDefaultSpatial
                    easing: Tokens.anim.expressiveDefaultSpatial
                }
                NumberAnimation {
                    target: osIconWrapper
                    property: "opacity"
                    to: 1
                    duration: Tokens.anim.durations.expressiveDefaultEffects
                    easing: Tokens.anim.expressiveDefaultEffects
                }
            }
        }

        Loader {
            id: osIconLoader

            anchors.centerIn: parent
            asynchronous: true
            sourceComponent: OsIcon {}
        }
    }
}
