pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.services
import qs.utils

LazyLoader {
    id: loader

    property list<string> cwd: ["Home"]
    property list<string> initialCwd: ["Home"]
    property bool resetCwdOnOpen: false
    property string filterLabel: "All files"
    property list<string> filters: ["*"]
    property string title: qsTr("Select a file")
    property var cwdHistory: []
    property int cwdHistoryIndex: -1

    readonly property bool canNavBack: cwdHistoryIndex > 0
    readonly property bool canNavForward: cwdHistoryIndex >= 0 && cwdHistoryIndex < cwdHistory.length - 1
    readonly property bool canNavUp: cwd.length > 1

    signal accepted(path: string)
    signal rejected

    function copyCwd(segments: list<string>): list<string> {
        return segments.slice(0, segments.length);
    }

    function cwdKey(segments: list<string>): string {
        return segments.join("\u0000");
    }

    function matchesFilter(file): bool {
        if (!file || file.isDir)
            return true;
        if (filters.includes("*"))
            return true;
        const suffix = (file.suffix ?? "").toLowerCase();
        return filters.some(ext => ext.toLowerCase().replace(/^\*\./, "") === suffix);
    }

    function resetNavigation(): void {
        cwdHistory = [copyCwd(cwd)];
        cwdHistoryIndex = 0;
    }

    function setCwd(next: list<string>): void {
        if (cwdKey(next) === cwdKey(cwd))
            return;
        cwd = copyCwd(next);
        cwdHistory = cwdHistory.slice(0, cwdHistoryIndex + 1);
        cwdHistory.push(copyCwd(cwd));
        cwdHistoryIndex = cwdHistory.length - 1;
    }

    function enterDirectory(name: string): void {
        setCwd(cwd.concat([name]));
    }

    function leaveDirectory(): void {
        if (cwd.length > 1)
            setCwd(cwd.slice(0, -1));
    }

    function goToCwdIndex(index: int): void {
        if (index >= 0 && index < cwd.length - 1)
            setCwd(cwd.slice(0, index + 1));
    }

    function goBack(): void {
        if (!canNavBack)
            return;
        cwdHistoryIndex--;
        cwd = copyCwd(cwdHistory[cwdHistoryIndex]);
    }

    function goForward(): void {
        if (!canNavForward)
            return;
        cwdHistoryIndex++;
        cwd = copyCwd(cwdHistory[cwdHistoryIndex]);
    }

    function cwdToAbsolute(segments: list<string>): string {
        if (segments.length === 0)
            return Paths.home;
        if (segments[0] === "Home") {
            const tail = segments.slice(1).join("/");
            return tail.length ? `${Paths.home}/${tail}` : Paths.home;
        }
        return segments.join("/");
    }

    function pathDisplaySegments(absPath: string): list<string> {
        const short = Paths.shortenHome(absPath);
        if (short === "~")
            return ["~"];
        if (short.startsWith("~/"))
            return ["~"].concat(short.slice(2).split("/").filter(s => s.length > 0));
        return absPath.split("/").filter(s => s.length > 0);
    }

    function segmentToAbsolute(segments: list<string>, index: int): string {
        const parts = segments.slice(0, index + 1);
        if (parts.length === 0)
            return Paths.home;
        if (parts[0] === "~")
            return parts.length === 1 ? Paths.home : `${Paths.home}/${parts.slice(1).join("/")}`;
        return `/${parts.join("/")}`;
    }

    function absoluteToCwd(absPath: string): list<string> {
        const home = Paths.home;
        if (absPath === home || absPath.startsWith(`${home}/`)) {
            const rel = absPath === home ? "" : absPath.slice(home.length + 1);
            return rel.length ? ["Home", ...rel.split("/")] : ["Home"];
        }
        const bundled = AccountFaces.bundledRoot;
        if (bundled.length && (absPath === bundled || absPath.startsWith(`${bundled}/`))) {
            const rel = absPath === bundled ? "" : absPath.slice(bundled.length + 1);
            return rel.length ? [bundled, ...rel.split("/")] : [bundled];
        }
        return absPath.split("/").filter(s => s.length > 0);
    }

    function open(): void {
        if (resetCwdOnOpen)
            cwd = copyCwd(initialCwd);
        resetNavigation();
        activeAsync = true;
    }

    function close(): void {
        rejected();
    }

    onAccepted: activeAsync = false
    onRejected: activeAsync = false

    FloatingWindow {
        id: root

        readonly property list<string> cwd: loader.cwd
        property string filterLabel: loader.filterLabel
        property list<string> filters: loader.filters

        readonly property bool canNavBack: loader.canNavBack
        readonly property bool canNavForward: loader.canNavForward
        readonly property bool canNavUp: loader.canNavUp
        readonly property string absolutePath: loader.cwdToAbsolute(loader.cwd)
        readonly property var pathSegments: loader.pathDisplaySegments(absolutePath)

        function enterDirectory(name: string): void {
            loader.enterDirectory(name);
        }

        function leaveDirectory(): void {
            loader.leaveDirectory();
        }

        function goToCwdIndex(index: int): void {
            loader.goToCwdIndex(index);
        }

        function goBack(): void {
            loader.goBack();
        }

        function goForward(): void {
            loader.goForward();
        }

        function navigateTo(segments: list<string>): void {
            loader.setCwd(segments);
        }

        function navigateToSegment(index: int): void {
            loader.setCwd(loader.absoluteToCwd(
                loader.segmentToAbsolute(pathSegments, index)));
        }

        readonly property bool selectionValid: {
            const file = folderContents.currentItem?.modelData;
            return (file && !file.isDir && loader.matchesFilter(file)) ?? false;
        }

        function matchesFilter(file): bool {
            return loader.matchesFilter(file);
        }

        function accepted(path: string): void {
            loader.accepted(path);
        }

        function rejected(): void {
            loader.rejected();
        }

        implicitWidth: 1000
        implicitHeight: 600
        color: Colours.tPalette.m3surface
        title: loader.title

        onVisibleChanged: {
            if (visible)
                loader.resetNavigation();
            else
                rejected();
        }

        Shortcut {
            sequence: "Alt+Left"
            enabled: root.visible && root.canNavBack
            onActivated: root.goBack()
        }

        Shortcut {
            sequence: "Alt+Right"
            enabled: root.visible && root.canNavForward
            onActivated: root.goForward()
        }

        Shortcut {
            sequence: "Alt+Up"
            enabled: root.visible && root.canNavUp
            onActivated: root.leaveDirectory()
        }

        RowLayout {
            anchors.fill: parent

            spacing: 0

            Sidebar {
                Layout.fillHeight: true
                dialog: root
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                spacing: 0

                HeaderBar {
                    Layout.fillWidth: true
                    dialog: root
                }

                FolderContents {
                    id: folderContents

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    dialog: root
                }

                DialogButtons {
                    Layout.fillWidth: true
                    dialog: root
                    folder: folderContents
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.BackButton | Qt.ForwardButton
            onPressed: event => {
                if (event.button === Qt.BackButton)
                    root.goBack();
                else if (event.button === Qt.ForwardButton)
                    root.goForward();
            }
        }

        Behavior on color {
            CAnim {}
        }
    }
}
