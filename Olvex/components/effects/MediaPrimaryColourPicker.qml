pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Olvex.Config
import qs.services
import qs.utils
import "../../services/color"
import "../../services/color/M3ColorMapper.js" as Mapper

// Stripdown ExpressiveColourPicker: global dynamic scheme pipeline, emits m3primary + m3onPrimary.
Item {
    id: root

    visible: false
    width: 0
    height: 0

    signal primaryReady(color primary, color onPrimary)
    signal primaryFailed(string reason)

    property string state: "idle"
    property string lastSource: ""
    property string lastConfigKey: ""
    property color lastPrimary
    property color lastOnPrimary

    readonly property string artCacheDir: `${Paths.state}/media/art-cache`

    function cleanPath(path: string): string {
        const raw = String(path || "").trim();
        if (!raw || Players.isRemoteArtUrl(raw))
            return "";
        return raw.replace(/^file:\/\//, "");
    }

    function configKey(): string {
        return [
            "playFill-sat-black-v5",
            GlobalConfig.appearance.schemeVariant || "expressive",
            GlobalConfig.appearance.themeMode || "auto",
            Wallpapers.smartArg.join(",")
        ].join("|");
    }

    function pickFromArt(artUrl: string, localPath: string): void {
        const stripped = Players.sanitizeArtUrl(artUrl);
        const local = root.cleanPath(localPath);
        if (local) {
            root.pickFromPath(local);
            return;
        }
        if (!stripped) {
            root.primaryFailed("empty art url");
            return;
        }
        if (Players.isRemoteArtUrl(stripped)) {
            root.state = "fetching";
            fetchProc.running = false;
            fetchProc.command = root.fetchCommand(stripped);
            fetchProc.running = true;
            return;
        }
        const path = root.cleanPath(stripped);
        if (path) {
            root.pickFromPath(path);
            return;
        }
        root.primaryFailed("local art path unreadable");
    }

    function fetchCommand(artUrl: string): list<string> {
        const norm = Players.normalizeMediaArtUrl(Players.sanitizeArtUrl(artUrl));
        const cacheFile = `${root.artCacheDir}/${Qt.md5(norm)}.img`;
        const escapedUrl = artUrl.replace(/'/g, "'\\''");
        const escapedCache = cacheFile.replace(/'/g, "'\\''");
        const escapedDir = root.artCacheDir.replace(/'/g, "'\\''");
        return ["bash", "-lc",
            `mkdir -p '${escapedDir}' && curl -fsSL '${escapedUrl}' -o '${escapedCache}' && printf '%s' '${escapedCache}'`];
    }

    function pickFromPath(imagePath: string): void {
        const clean = root.cleanPath(imagePath);
        if (!clean) {
            root.primaryFailed("empty image path");
            return;
        }

        const cfg = root.configKey();
        if (clean === root.lastSource && cfg === root.lastConfigKey && root.lastPrimary.a > 0) {
            root.state = "cached";
            root.primaryReady(root.lastPrimary, root.lastOnPrimary);
            return;
        }

        root.lastSource = clean;
        root.lastConfigKey = cfg;
        root.state = "extracting";

        extractProc.running = false;
        extractProc.command = Wallpapers.dynamicPaletteCommand(clean);
        extractProc.running = true;
    }

    function cancel(): void {
        fetchProc.running = false;
        extractProc.running = false;
        root.state = "idle";
    }

    M3ExpressivePalette {
        id: schemePalette
    }

    Process {
        id: fetchProc

        stdout: StdioCollector {
            onStreamFinished: {
                const cached = text.trim();
                if (!cached) {
                    root.state = "error";
                    root.primaryFailed("remote art fetch failed");
                    return;
                }
                root.pickFromPath(cached);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    console.log("[MediaPrimaryColourPicker] fetch:", text.trim());
            }
        }
    }

    Process {
        id: extractProc

        stdout: StdioCollector {
            onStreamFinished: {
                const scheme = Mapper.parseSchemePayload(text);
                if (!scheme || !schemePalette.applyScheme(scheme)) {
                    root.state = "error";
                    root.primaryFailed("dynamic scheme apply failed");
                    return;
                }
                const primary = schemePalette.m3primary;
                const onPrimary = schemePalette.m3onPrimary;
                if (!primary || primary.a <= 0) {
                    root.state = "error";
                    root.primaryFailed("m3primary missing from scheme");
                    return;
                }
                root.lastPrimary = primary;
                root.lastOnPrimary = onPrimary.a > 0 ? onPrimary : Colours.on(primary);
                root.state = "ready";
                root.primaryReady(primary, root.lastOnPrimary);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    console.log("[MediaPrimaryColourPicker]", text.trim());
            }
        }
    }

    Connections {
        target: GlobalConfig.appearance
        function onSchemeVariantChanged() {
            root.lastConfigKey = "";
        }
        function onThemeModeChanged() {
            root.lastConfigKey = "";
        }
    }
}