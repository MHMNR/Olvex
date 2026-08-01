pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.utils
import "M3ColorMapper.js" as Mapper

Item {
    id: root
    visible: false
    width: 0
    height: 0

    signal paletteReady(var scheme, bool isPreview)
    signal paletteFailed(string reason, bool isPreview)

    property string state: "idle"
    property string lastSource: ""
    property string lastPreviewSource: ""
    property string lastPreviewPayload: ""
    property bool persistedLoaded: false

    readonly property var schemePaths: [Paths.state + "/scheme.json"]

    function pickFromWallpaper(imagePath, isPreview, smartArg) {
        if (!imagePath) {
            root.paletteFailed("empty wallpaper path", isPreview);
            return;
        }

        const cleanPath = String(imagePath).replace(/^file:\/\//, "");
        if (isPreview)
            root.lastPreviewSource = cleanPath;
        else
            root.lastSource = cleanPath;

        root.state = isPreview ? "preview-extracting" : "extracting";

        const args = ["wallpaper", "-p", cleanPath];
        for (let i = 0; i < smartArg.length; i++)
            args.push(smartArg[i]);

        extractProc.isPreview = isPreview;
        extractProc.command = ["olvex"].concat(args);
        extractProc.running = true;
    }

    function schemePayloadAt(index) {
        const row = schemeWatchers.itemAt(index);
        if (!row || row.children.length === 0)
            return "";
        const view = row.children[0];
        return view.loaded ? view.text() : "";
    }

    function tryLoadPersisted() {
        if (root.persistedLoaded)
            return true;

        if (!Wallpapers.bootstrapDone)
            return false;

        const wallPath = (Wallpapers.actualCurrent || "").trim();
        const sourcePath = Wallpapers.colourSourcePath(wallPath);
        if (!wallPath || !sourcePath)
            return false;

        const normalize = p => (p || "").trim().replace(/^file:\/\//, "");
        const committed = normalize(Wallpapers.committedColourSource);
        const normalizedSource = normalize(sourcePath);
        if (committed && committed !== normalizedSource)
            return false;

        for (let i = 0; i < schemeWatchers.count; i++) {
            const payload = schemePayloadAt(i);
            if (!payload || !payload.trim().length)
                continue;
            const scheme = Mapper.parseSchemePayload(payload);
            if (!scheme)
                continue;
            root.persistedLoaded = true;
            root.lastSource = normalizedSource;
            root.state = "persisted";
            root.paletteReady(scheme, false);
            return true;
        }
        return false;
    }

    function handoffPreviewIfCached(imagePath) {
        const cleanPath = String(imagePath).replace(/^file:\/\//, "");
        if (cleanPath !== root.lastPreviewSource || !root.lastPreviewPayload)
            return false;
        const scheme = Mapper.parseSchemePayload(root.lastPreviewPayload);
        if (!scheme)
            return false;
        root.paletteReady(scheme, false);
        root.state = "ready";
        return true;
    }

    Repeater {
        id: schemeWatchers
        model: root.schemePaths
        delegate: Item {
            required property var modelData
            width: 0
            height: 0
            visible: false

            FileView {
                printErrors: false
                path: modelData
                watchChanges: true
                onFileChanged: reload()
                onLoaded: {
                    if (!root.persistedLoaded)
                        root.tryLoadPersisted();
                }
                onLoadFailed: err => {
                    if (err === FileViewError.FileNotFound && !root.persistedLoaded)
                        root.tryLoadPersisted();
                }
            }
        }
    }

    Process {
        id: extractProc
        property bool isPreview: false

        stdout: StdioCollector {
            onStreamFinished: {
                const scheme = Mapper.parseSchemePayload(text);
                if (!scheme) {
                    root.state = "error";
                    root.paletteFailed("wallpaper palette extraction failed", extractProc.isPreview);
                    return;
                }

                const payload = Mapper.stringifySchemePayload(text);
                if (extractProc.isPreview) {
                    root.lastPreviewPayload = payload.length > 0 ? payload : text;
                    root.state = "preview-ready";
                } else {
                    root.state = "ready";
                }
                root.paletteReady(scheme, extractProc.isPreview);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    console.log("[ExpressiveColourPicker]", text.trim());
            }
        }
    }
}