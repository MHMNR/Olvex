pragma Singleton

import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import Olvex.Config
import qs.services
import qs.utils

Searcher {
    id: root

    property string currentScheme
    property string currentVariant
    property bool catalogLoaded: false
    property bool currentLoaded: false

    function transformSearch(search: string): string {
        return search.slice(`${GlobalConfig.launcher.actionPrefix}scheme `.length);
    }

    function selector(item: var): string {
        return `${item.name} ${item.flavour}`;
    }

    function reload(): void {
        ensureLoaded();
        getCurrent.running = true;
    }

    function ensureLoaded(): void {
        if (!catalogLoaded && !getSchemes.running)
            getSchemes.running = true;
        if (!currentLoaded && !getCurrent.running)
            getCurrent.running = true;
    }

    catalog: schemes.instances
    useFuzzy: GlobalConfig.launcher.useFuzzy.schemes
    beforeQuery: function() { root.ensureLoaded(); }
    keys: ["name", "flavour"]
    weights: [0.9, 0.1]

    Variants {
        id: schemes

        Scheme {}
    }

    Process {
        id: getSchemes

        running: false
        command: ["olvex", "scheme", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const schemeData = JSON.parse(text);
                const list = Object.entries(schemeData).map(([name, f]) => Object.entries(f).map(([flavour, colours]) => ({
                                name,
                                flavour,
                                colours
                            })));

                const flat = [];
                for (const s of list)
                    for (const f of s)
                        flat.push(f);

                schemes.model = flat.sort((a, b) => String(a.name + a.flavour).localeCompare((b.name + b.flavour)));
                root.catalogLoaded = true;
            }
        }
    }

    Process {
        id: getCurrent

        running: false
        command: ["olvex", "scheme", "get", "-nfv"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [name, flavour, variant] = text.trim().split("\n");
                root.currentScheme = `${name} ${flavour}`;
                root.currentVariant = variant;
                root.currentLoaded = true;
            }
        }
    }

    Process {
        id: setProc
        
        onExited: {
            Wallpapers.requestAccentRefresh(Wallpapers.current, false);
            Qt.callLater(() => root.reload());
        }
    }

    function setScheme(name: string, flavour: string): void {
        setProc.command = ["olvex", "scheme", "set", "--notify", "-n", name, "-f", flavour];
        setProc.running = true;
    }

    function setVariant(variant: string): void {
        setProc.command = ["olvex", "scheme", "set", "--notify", "-v", variant];
        setProc.running = true;
    }

    component Scheme: QtObject {
        required property var modelData
        readonly property string name: modelData.name
        readonly property string flavour: modelData.flavour
        readonly property var colours: modelData.colours

        function onClicked(list: AppList): void {
            list.visibilities.launcher = false;
            root.setScheme(name, flavour);
        }
    }
}
