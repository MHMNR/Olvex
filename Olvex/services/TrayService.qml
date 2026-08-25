pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Olvex.Config

Singleton {
    id: root

    property int _revision: 0

    function _notifyChange(): void {
        root._revision++;
    }

    Connections {
        target: SystemTray.items
        function onValuesChanged(): void {
            root._notifyChange();
        }
    }

    readonly property var rawItems: {
        const _ = root._revision;
        return SystemTray.items?.values ?? [];
    }

    readonly property var items: {
        const _ = root._revision;
        const list = root.rawItems;
        const hidden = GlobalConfig.bar.tray.hiddenIcons ?? [];
        return list.filter(item => item && item.id && !hidden.includes(item.id));
    }

    readonly property int count: items.length
    readonly property bool hasItems: count > 0

    function getById(id: string): var {
        return items.find(item => item && item.id === id) ?? null;
    }

    function getByIndex(index: int): var {
        return (index >= 0 && index < items.length) ? items[index] : null;
    }

    function activate(item: var): void {
        if (item && typeof item.activate === "function") {
            item.activate();
        }
    }

    function secondaryActivate(item: var): void {
        if (item && typeof item.secondaryActivate === "function") {
            item.secondaryActivate();
        }
    }
}
