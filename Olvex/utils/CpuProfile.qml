pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool enabled: Quickshell.env("OLVEX_PROFILE") === "1"
    property var counts: ({})

    function bump(key: string): void {
        if (!enabled)
            return;
        const next = Object.assign({}, counts);
        next[key] = (next[key] || 0) + 1;
        counts = next;
    }

    function flush(): void {
        if (!enabled)
            return;
        const keys = Object.keys(counts).sort();
        if (!keys.length)
            return;
        let line = "[CpuProfile 5s]";
        for (const k of keys)
            line += ` ${k}=${counts[k]}`;
        console.log(line);
        counts = {};
    }

    Component.onCompleted: {
        if (enabled)
            console.log("[CpuProfile] enabled — rolling 5s counter reports");
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.enabled
        onTriggered: root.flush()
    }
}