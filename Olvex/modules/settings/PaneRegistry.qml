pragma Singleton

import "../../components"
import "../../components/controls"
import "../../components/containers"
import QtQuick
import qs.services

QtObject {
    id: root

    // Bento category registry. Paths relative to modules/controlcenter/
    // accentRole: key on Colours.palette
    // Grid: 6 cols. Dual look heroes with asymmetric widths (true bento).
    //   r0–1: Appearance w6h2
    //   r2:   Network | Sound | Taskbar
    //   r3:   Notifs  | Panels | Power
    //   r4:   System  | About
    readonly property var categories: [
        {
            id: "appearance",
            label: "appearance",
            icon: "palette",
            title: "Appearance",
            sub: "Theme, colors & fonts",
            accentRole: "m3tertiary",
            kind: "appearance",
            c: 0,
            r: 0,
            w: 6,
            h: 2,
            component: "appearance/AppearancePage.qml"
        },
        {
            id: "network",
            label: "network",
            icon: "wifi",
            title: "Network",
            sub: "Wi‑Fi and Bluetooth",
            accentRole: "m3primary",
            kind: "network",
            c: 0,
            r: 2,
            w: 2,
            h: 1,
            component: "network/NetworkPage.qml"
        },
        {
            id: "sound",
            label: "sound",
            icon: "volume_up",
            title: "Sound",
            sub: "Audio and inputs",
            accentRole: "m3secondary",
            kind: "sound",
            c: 2,
            r: 2,
            w: 2,
            h: 1,
            component: "sound/SoundPage.qml"
        },
        {
            id: "taskbar",
            label: "taskbar",
            icon: "dock",
            title: "Taskbar",
            sub: "Bottom dock & items",
            accentRole: "m3primary",
            kind: "taskbar",
            c: 4,
            r: 2,
            w: 2,
            h: 1,
            component: "taskbar/TaskbarPage.qml"
        },
        {
            id: "notifs",
            label: "notifs",
            icon: "notifications",
            title: "Notifications",
            sub: "Do not disturb",
            accentRole: "m3primary",
            kind: "notifs",
            c: 0,
            r: 3,
            w: 2,
            h: 1,
            component: "notifications/NotificationsPage.qml"
        },
        {
            id: "panels",
            label: "panels",
            icon: "dashboard_customize",
            title: "Panels",
            sub: "Layout & behavior",
            accentRole: "m3secondary",
            kind: "panels",
            c: 2,
            r: 3,
            w: 2,
            h: 1,
            component: "panels/PanelsPage.qml"
        },
        {
            id: "power",
            label: "power",
            icon: "battery_charging_full",
            title: "Power",
            sub: "Sleep & idle",
            accentRole: "m3secondary",
            kind: "power",
            c: 4,
            r: 3,
            w: 2,
            h: 1,
            component: "power/PowerPage.qml"
        },
        {
            id: "system",
            label: "system",
            icon: "tune",
            title: "System",
            sub: "Apps, clock & media",
            accentRole: "m3primary",
            kind: "system",
            c: 0,
            r: 4,
            w: 3,
            h: 1,
            component: "system/SystemPage.qml"
        },
        {
            id: "about",
            label: "about",
            icon: "deployed_code",
            title: "About Olvex",
            sub: "Version, system info and links",
            accentRole: "m3primary",
            kind: "about",
            c: 3,
            r: 4,
            w: 3,
            h: 1,
            component: "about/AboutPage.qml"
        }
    ]

    readonly property int count: categories.length

    readonly property var labels: {
        const result = [];
        for (let i = 0; i < categories.length; i++)
            result.push(categories[i].id);
        return result;
    }

    // Legacy: panes list for old rail code
    readonly property var panes: categories

    function getByIndex(index: int): var {
        if (index >= 0 && index < categories.length)
            return categories[index];
        return null;
    }

    function getIndexByLabel(label: string): int {
        for (let i = 0; i < categories.length; i++) {
            if (categories[i].label === label || categories[i].id === label)
                return i;
        }
        return -1;
    }

    function getByLabel(label: string): var {
        return getByIndex(getIndexByLabel(label));
    }

    function getById(id: string): var {
        for (let i = 0; i < categories.length; i++) {
            if (categories[i].id === id)
                return categories[i];
        }
        return null;
    }

    function accentFor(cat: var): color {
        if (!cat)
            return Colours.palette.m3primary;
        const role = cat.accentRole || "m3primary";
        return Colours.palette[role] || Colours.palette.m3primary;
    }
}
