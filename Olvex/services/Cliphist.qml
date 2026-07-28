pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Olvex.Config

Singleton {
    id: root
    property string cliphistBinary: "cliphist"
    property real pasteDelay: 0.05
    property string pressPasteCommand: "ydotool key -d 1 29:1 47:1 47:0 29:0"
    property bool sloppySearch: (typeof Config !== 'undefined' && Config.options && Config.options.search) ? Config.options.search.sloppy : false
    property var entries: []

    function shellSingleQuoteEscape(s) {
        return s.replace(/'/g, "'\\''");
    }

    function fuzzyQuery(search) {
        if (!search || String(search).trim() === "") return root.entries;
        const needle = String(search).toLowerCase();
        const matches = root.entries.filter(e => String(e).toLowerCase().indexOf(needle) !== -1);
        if (matches.length) return matches;
        return root.entries.slice(0, 100);
    }

    function entryIsImage(entry) {
        return !!(/^(\d+)\t\[\[.*binary data.*\d+x\d+.*\]\]$/.test(entry));
    }

    function entryId(entry) {
        if (!entry) return "";
        const idx = String(entry).indexOf("\t");
        return idx > 0 ? String(entry).slice(0, idx).trim() : "";
    }

    function decodeImageTo(entry) {
        const id = entryId(entry);
        if (!id) return "";
        const outPath = `/tmp/olvex-clip/${id}.png`;
        Quickshell.execDetached(["bash", "-c",
            `mkdir -p /tmp/olvex-clip && printf '%s' '${shellSingleQuoteEscape(entry)}' | ${root.cliphistBinary} decode > ${outPath}`
        ]);
        return outPath;
    }

    function refresh() {
        readProc.running = false;
        readProc.buffer = [];
        readProc.running = true;
    }

    function copy(entry) {
        if (!entry) return;
        Quickshell.execDetached(["bash", "-c", `printf '%s' '${shellSingleQuoteEscape(entry)}' | ${root.cliphistBinary} decode | wl-copy`]);
    }

    function paste(entry) {
        if (!entry) return;
        Quickshell.execDetached(["bash", "-c", `printf '%s' '${shellSingleQuoteEscape(entry)}' | ${root.cliphistBinary} decode | wl-copy && wl-paste`]);
    }

    function superpaste(count, isImage) {
        const targetEntries = root.entries.filter(function(entry) {
            if (!isImage) return true;
            return root.entryIsImage(entry);
        }).slice(0, count);
        const pasteCommands = targetEntries.slice().reverse().map(function(entry) {
            return `printf '%s' '${shellSingleQuoteEscape(entry)}' | ${root.cliphistBinary} decode | wl-copy && sleep ${root.pasteDelay} && ${root.pressPasteCommand}`;
        });
        if (pasteCommands.length === 0) return;
        Quickshell.execDetached(["bash", "-c", pasteCommands.join(` && sleep ${root.pasteDelay} && `)]);
    }

    Process {
        id: deleteProc
        property string pendingEntry: ""
        command: ["bash", "-c", `printf '%s' '${root.shellSingleQuoteEscape(deleteProc.pendingEntry)}' | ${root.cliphistBinary} delete`]
        onExited: (exitCode, exitStatus) => { root.refresh(); }
    }

    function deleteEntry(entry) {
        deleteProc.pendingEntry = entry;
        deleteProc.running = true;
    }

    Process {
        id: wipeProc
        command: [root.cliphistBinary, "wipe"]
        onExited: (exitCode, exitStatus) => { root.refresh(); }
    }

    function wipe() { wipeProc.running = true; }

    Connections {
        target: Quickshell
        function onClipboardTextChanged() { delayedUpdateTimer.restart(); }
    }

    Timer {
        id: delayedUpdateTimer
        interval: (typeof Config !== 'undefined' && Config.options && Config.options.hacks && Config.options.hacks.arbitraryRaceConditionDelay) ? Config.options.hacks.arbitraryRaceConditionDelay : 100
        repeat: false
        onTriggered: { root.refresh(); }
    }

    Process {
        id: readProc
        property var buffer: []
        command: [root.cliphistBinary, "list"]
        stdout: SplitParser {
            onRead: line => {
                if (line.trim() !== "") readProc.buffer.push(line)
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                // Force new array reference so onEntriesChanged fires
                root.entries = readProc.buffer.slice()
            } else {
                console.error("[Cliphist] Failed to refresh, exit code:", exitCode)
            }
        }
    }

    IpcHandler { target: "cliphistService"; function update() { root.refresh(); } }

    Component.onCompleted: { root.refresh(); }
}
