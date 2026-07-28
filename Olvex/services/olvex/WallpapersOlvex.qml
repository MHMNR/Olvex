pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Olvex.Config
import Olvex.Models
import qs.services
import qs.utils
import "../color/M3ColorMapper.js" as Mapper

Searcher {
    id: root

    signal colorsGenerated(string data, bool isPreview)

    readonly property string currentNamePath: `${Paths.state}/wallpaper/path.txt`
    readonly property string colourSourceCachePath: `${Paths.state}/wallpaper/colour-source.txt`
    readonly property string committedColourSource: root._committedColourSource
    readonly property list<string> smartArg: (GlobalConfig.services.smartScheme && GlobalConfig.appearance.themeMode === "auto") ? [] : ["--no-smart"]
    readonly property list<string> modeArg: GlobalConfig.appearance.themeMode !== "auto" ? ["-m", GlobalConfig.appearance.themeMode] : []
    readonly property list<string> validVideoExtensions: ["mp4", "mkv", "webm", "mov", "avi", "m4v"]
    readonly property string liveWallpaperDir: `${Paths.pictures}/Wallpapers/Live`
    readonly property string videoThumbnailDir: `${Paths.state}/wallpaper/live-thumbnails`

    property bool showPreview: false
    readonly property string current: showPreview ? previewPath : actualCurrent
    property string previewPath
    property string actualCurrent
    property bool previewColourLock
    property var monitorWallpapers: ({})
    property bool perMonitorWallpaper: GlobalConfig.background?.perMonitorWallpaper ?? false
    property string wallpaperCategory: ""
    property var videoEntries: []
    property var videoThumbnailMap: ({})
    property int thumbnailUpdateCount: 0
    property var thumbnailQueue: []
    property string pendingCurrentColourPath: ""
    property string pendingPreviewColourPath: ""
    property bool catalogReady: false
    property bool _forceNextAccentRefresh: false

    readonly property var imageEntries: {
        const fs = catalogLoader.item;
        if (!fs || !catalogReady)
            return [];
        return fs.entries.filter(entry => !isPathInLiveDir(entry.path)).map(entry => ({
            path: entry.path,
            name: entry.name,
            relativePath: entry.relativePath,
            suffix: entry.suffix,
            isVideo: false
        }));
    }
    readonly property var staticEntries: imageEntries
    readonly property var liveEntries: videoEntries
    readonly property var entries: staticEntries.concat(liveEntries)
    readonly property var entryObjects: entries
    readonly property var staticEntryObjects: staticEntries
    readonly property var liveEntryObjects: liveEntries

    function ensureCatalog(): void {
        if (!catalogReady)
            catalogReady = true;
    }

    function isVideoPath(path: string): bool {
        const lower = (path || "").toLowerCase();
        return validVideoExtensions.some(ext => lower.endsWith(`.${ext}`));
    }

    function isPathInLiveDir(path: string): bool {
        return (path || "").startsWith(`${liveWallpaperDir}/`) || path === liveWallpaperDir;
    }

    function thumbnailPathFor(path: string): string {
        if (!isVideoPath(path))
            return "";

        const safe = path.replace(/[^A-Za-z0-9._-]/g, "_");
        return `${videoThumbnailDir}/${safe}.jpg`;
    }

    function colourSourcePath(path: string): string {
        if (!isVideoPath(path))
            return path;
        return videoThumbnailMap[path] || thumbnailPathFor(path);
    }

    function queueThumbnail(path: string, prioritize): void {
        prioritize = prioritize ?? false;
        if (!isVideoPath(path))
            return;

        const thumbnailPath = thumbnailPathFor(path);
        if (videoThumbnailMap[path] === thumbnailPath)
            return;
        if (thumbnailQueue.includes(path))
            return;

        const nextQueue = thumbnailQueue.slice();
        if (prioritize)
            nextQueue.unshift(path);
        else
            nextQueue.push(path);
        thumbnailQueue = nextQueue;
        processNextThumbnail();
    }

    function queueAllVideoThumbnails(): void {
        for (const entry of videoEntries)
            queueThumbnail(entry.path);
    }

    function processNextThumbnail(): void {
        if (thumbnailProc.running || thumbnailQueue.length === 0)
            return;

        const [nextPath, ...rest] = thumbnailQueue;
        thumbnailQueue = rest;

        const outputPath = thumbnailPathFor(nextPath);
        thumbnailProc.inputPath = nextPath;
        thumbnailProc.outputPath = outputPath;
        thumbnailProc.command = ["bash", "-lc", `
            mkdir -p '${videoThumbnailDir.replace(/'/g, "'\\''")}'
            output='${outputPath.replace(/'/g, "'\\''")}'
            input='${nextPath.replace(/'/g, "'\\''")}'
            run_thumb() {
                nice -n 19 ffmpeg -y -loglevel error -ss 1 -i "$input" -frames:v 1 -vf "scale=640:-1:force_original_aspect_ratio=decrease" "$output" >/dev/null 2>&1 \
                || nice -n 19 ffmpeg -y -loglevel error -i "$input" -frames:v 1 -vf "scale=640:-1:force_original_aspect_ratio=decrease" "$output" >/dev/null 2>&1
            }
            if [ ! -s "$output" ]; then
                run_thumb
            fi
            if [ -s "$output" ]; then printf '%s\\n' "$output"; fi
        `];
        thumbnailProc.running = true;
    }

    property string _lastRefreshPath: ""
    property string _lastPreviewPath: ""
    property string _lastPreviewWallPath: ""
    property string _lastPreviewData: ""
    property string _lastCurrentData: ""
    property string _committedColourSource: ""
    property bool _pathFileLoaded: false
    property bool _colourSourceFileLoaded: false
    property bool _schemeFileLoaded: false
    property bool _bootstrapDone: false
    readonly property bool bootstrapDone: _bootstrapDone

    readonly property string _jsonPipe: `python3 -c "import sys,re; data=sys.stdin.read(); m=re.search(r'\\\\{.*\\\\}',data,re.S); print(m.group(0)) if m else sys.exit(1)"`

    function markPathFileReady(loaded: string): void {
        root.actualCurrent = loaded;
        root._pathFileLoaded = true;
        if (!root._bootstrapDone)
            root.scheduleBootstrap();
        else if (loaded !== root._lastBootstrapPath)
            root.onBootstrapPathChanged(loaded);
        root.previewColourLock = false;
    }

    function markColourSourceFileReady(loaded: string): void {
        root._committedColourSource = loaded;
        root._colourSourceFileLoaded = true;
        root.scheduleBootstrap();
    }

    function markSchemeFileReady(loaded: string): void {
        persistedScheme.schemePayload = loaded;
        root._schemeFileLoaded = true;
        root.scheduleBootstrap();
    }

    property string _lastBootstrapPath: ""

    function onBootstrapPathChanged(loaded: string): void {
        root._lastBootstrapPath = loaded;
        if (root.isVideoPath(loaded))
            root.queueThumbnail(loaded, true);
        if (loaded) {
            root._forceNextAccentRefresh = true;
            root.applyWallpaperToDisplays(loaded);
            root.requestAccentRefresh(loaded, false);
        } else {
            root.applyFallbackColours();
        }
    }

    function persistedFilesReady(): bool {
        return _pathFileLoaded && _colourSourceFileLoaded && _schemeFileLoaded;
    }

    function scheduleBootstrap(): void {
        if (!persistedFilesReady() || _bootstrapDone)
            return;
        Qt.callLater(bootstrapWallpaperColours);
    }

    function normalizeSourcePath(path: string): string {
        return (path || "").trim().replace(/^file:\/\//, "");
    }

    function applyPersistedScheme(sourcePath: string): bool {
        const payload = root.normalizePalettePayload(persistedScheme.schemePayload);
        if (!payload)
            return false;

        const committed = root.normalizeSourcePath(root._committedColourSource);
        const normalizedSource = root.normalizeSourcePath(sourcePath);
        if (committed && committed !== normalizedSource)
            return false;

        if (!committed)
            root.persistColourSource(normalizedSource);

        root._lastRefreshPath = normalizedSource;
        root._lastCurrentData = payload;
        Colours.ingestWallpaperColors(payload, false);
        return true;
    }

    function applyFallbackColours(): void {
        console.log("[Wallpapers] No wallpaper set — using built-in fallback palette");
        root._committedColourSource = "";
        root._lastRefreshPath = "";
        root._lastCurrentData = "";
        Colours.useFallbackPalette();
    }

    function bootstrapWallpaperColours(): void {
        if (_bootstrapDone || !persistedFilesReady())
            return;

        const path = (root.actualCurrent || "").trim();
        root._lastBootstrapPath = path;
        if (!path) {
            _bootstrapDone = true;
            root.applyFallbackColours();
            return;
        }

        const sourcePath = root.colourSourcePath(path);
        if (!sourcePath) {
            root.pendingCurrentColourPath = path;
            root.queueThumbnail(path, true);
            return;
        }

        _bootstrapDone = true;

        if (root.applyPersistedScheme(sourcePath))
            console.log("[Wallpapers] Startup: restored persisted scheme for", sourcePath);

        root.applyWallpaperToDisplays(path);

        // Media-pill pattern: always live-extract from wallpaper image on startup.
        console.log("[Wallpapers] Startup: live extract for", sourcePath);
        root._forceNextAccentRefresh = true;
        root.requestAccentRefresh(path, false);
    }

    function applyWallpaperToDisplays(path: string): void {
        if (!path || root.isVideoPath(path))
            return;
        const escaped = path.replace(/'/g, "'\\''");
        const smartFlags = smartArg.join(" ");
        const modeFlags = modeArg.join(" ");
        Quickshell.execDetached(["bash", "-lc",
            `if command -v olvex >/dev/null 2>&1; then olvex wallpaper -f '${escaped}' ${smartFlags} ${modeFlags}; elif command -v swww >/dev/null 2>&1; then swww img '${escaped}'; fi`]);
    }

    function persistSchemePayload(payload: string): void {
        const normalized = root.normalizePalettePayload(payload);
        if (!normalized.length)
            return;
        const schemePath = `${Paths.state}/scheme.json`;
        const stateDir = Paths.state.replace(/'/g, "'\\''");
        const quoted = normalized.replace(/'/g, "'\\''");
        schemePersistProc.command = ["bash", "-lc",
            `mkdir -p '${stateDir}' && python3 -c 'import json,sys; json.dump(json.loads(sys.argv[1]), open("${schemePath.replace(/'/g, "'\\''")}", "w"), indent=2)' '${quoted}'`];
        schemePersistProc.running = true;
    }

    function normalizePalettePayload(raw: string): string {
        const filtered = Mapper.stringifySchemePayload(raw);
        return filtered.length > 0 ? filtered : raw;
    }

    function schemeSetPrefix(): string {
        const variant = (GlobalConfig.appearance.schemeVariant || "expressive").replace(/'/g, "'\\''");
        let setCmd = `olvex scheme set -v '${variant}'`;
        if (modeArg.length > 0)
            setCmd += ` ${modeArg.join(" ")}`;
        return setCmd + " >/dev/null 2>&1 || true; sleep 0.05; ";
    }

    function wallPaletteCommand(cleanPath: string, isPreview: bool): list<string> {
        const escaped = cleanPath.replace(/'/g, "'\\''");
        const smartFlags = smartArg.join(" ");
        const wallCmd = `olvex wallpaper -p '${escaped}' ${smartFlags} | ${root._jsonPipe}`;
        if (!isPreview && modeArg.length > 0)
            return ["bash", "-lc", root.schemeSetPrefix() + wallCmd];
        return ["bash", "-lc", wallCmd];
    }

    // Same dynamic M3 pipeline as wallpaper picker — syncs variant + mode, then extracts scheme JSON.
    function dynamicPaletteCommand(cleanPath: string): list<string> {
        const escaped = cleanPath.replace(/'/g, "'\\''");
        const smartFlags = smartArg.join(" ");
        const wallCmd = `olvex wallpaper -p '${escaped}' ${smartFlags} | ${root._jsonPipe}`;
        return ["bash", "-lc", root.schemeSetPrefix() + wallCmd];
    }

    function persistColourSource(sourcePath: string): void {
        if (!sourcePath)
            return;
        root._committedColourSource = sourcePath;
        const escaped = sourcePath.replace(/'/g, "'\\''");
        const dir = root.colourSourceCachePath.replace(/\/[^/]+$/, "");
        colourSourcePersistProc.command = ["bash", "-lc",
            `mkdir -p '${dir.replace(/'/g, "'\\''")}' && printf '%s' '${escaped}' > '${root.colourSourceCachePath.replace(/'/g, "'\\''")}'`];
        colourSourcePersistProc.running = true;
    }

    function clearPreviewAccentCache(): void {
        root._lastPreviewData = "";
        root._lastPreviewWallPath = "";
        root._lastPreviewPath = "";
        getPreviewColoursProc.running = false;
        getPreviewColoursProc.targetWallPath = "";
    }

    function requestAccentRefresh(path: string, isPreview: bool): void {
        if (!path)
            return;

        const sourcePath = colourSourcePath(path);
        const forceRefresh = root._forceNextAccentRefresh;
        root._forceNextAccentRefresh = false;

        if (!isPreview && !forceRefresh && path === actualCurrent && sourcePath
            && root.applyPersistedScheme(sourcePath)) {
            console.log("[Wallpapers] Reusing persisted scheme for", sourcePath);
            return;
        }

        if (!sourcePath) {
            if (isPreview)
                pendingPreviewColourPath = path;
            else
                pendingCurrentColourPath = path;
            queueThumbnail(path, true);
            return;
        }

        const cleanPath = sourcePath.replace(/^file:\/\//, "");

        if (isPreview) {
            root._lastPreviewWallPath = path;
            root._lastPreviewPath = sourcePath;
            root._lastPreviewData = "";
            pendingPreviewColourPath = "";
            getPreviewColoursProc.running = false;
            getPreviewColoursProc.targetWallPath = path;
            getPreviewColoursProc.command = wallPaletteCommand(cleanPath, true);
            getPreviewColoursProc.running = true;
            console.log(`[Wallpapers] M3 accent preview: ${getPreviewColoursProc.command.join(" ")}`);
            return;
        }

        root._lastRefreshPath = sourcePath;

        const canHandoffPreview = !forceRefresh
            && path === root._lastPreviewWallPath
            && sourcePath === root._lastPreviewPath
            && root._lastPreviewData
            && !getPreviewColoursProc.running;
        if (canHandoffPreview) {
            console.log(`[Wallpapers] Handing off preview colors for ${path}`);
            root.colorsGenerated(root._lastPreviewData, false);
            return;
        }

        pendingCurrentColourPath = "";
        getCurrentColoursProc.running = false;
        getCurrentColoursProc.targetSourcePath = sourcePath;
        getCurrentColoursProc.command = root.dynamicPaletteCommand(cleanPath);
        getCurrentColoursProc.running = true;
        console.log(`[Wallpapers] M3 accent refresh: ${getCurrentColoursProc.command.join(" ")}`);
    }


    function monitorCommand(path: string, monitorName: string): list<string> {
        return ["bash", "-lc", `if command -v olvex >/dev/null 2>&1; then olvex wallpaper -m '${monitorName.replace(/'/g, "'\\''")}' -f '${path.replace(/'/g, "'\\''")}' ${smartArg.join(" ")} ${modeArg.join(" ")}; elif command -v swww >/dev/null 2>&1; then swww img --outputs '${monitorName.replace(/'/g, "'\\''")}' '${path.replace(/'/g, "'\\''")}'; fi`];
    }

    function setWallpaper(path: string): void {
        previewPath = "";
        showPreview = false;
        previewColourLock = false;
        Colours.setShowPreview(false);
        root.clearPreviewAccentCache();
        _forceNextAccentRefresh = true;

        actualCurrent = path;
        persistCurrentPath(path);
        root.applyWallpaperToDisplays(path);
        requestAccentRefresh(path, false);
    }

    function persistCurrentPath(path: string): void {
        persistProc.command = ["bash", "-lc", `mkdir -p "$(dirname '${currentNamePath.replace(/'/g, "'\\''")}')" && printf '%s' '${path.replace(/'/g, "'\\''")}' > '${currentNamePath.replace(/'/g, "'\\''")}'` ];
        persistProc.running = true;
    }

    function getMonitorWallpaper(monitorName: string): string {
        if (perMonitorWallpaper && monitorWallpapers[monitorName])
            return monitorWallpapers[monitorName];
        return actualCurrent;
    }

    function setMonitorWallpaper(monitorName: string, path: string): void {
        const nextMap = Object.assign({}, monitorWallpapers);
        nextMap[monitorName] = path;
        monitorWallpapers = nextMap;

        if (perMonitorWallpaper && !isVideoPath(path))
            Quickshell.execDetached(monitorCommand(path, monitorName));
    }

    function preview(path: string): void {
        previewPath = path;
        showPreview = true;
        requestAccentRefresh(path, true);
    }

    function stopPreview(): void {
        const commitPreview = showPreview
            && previewPath === actualCurrent
            && root._lastPreviewData
            && !previewColourLock;
        showPreview = false;
        if (commitPreview) {
            root._lastCurrentData = root._lastPreviewData;
            root.colorsGenerated(root._lastPreviewData, false);
        }
        if (!previewColourLock)
            Colours.setShowPreview(false);
    }

    catalog: entries
    key: "relativePath"
    useFuzzy: GlobalConfig.launcher.useFuzzy.wallpapers
    extraOpts: useFuzzy ? ({}) : ({
            forward: false
        })
    beforeQuery: function() { root.ensureCatalog(); }

    IpcHandler {
        function get(): string {
            return root.actualCurrent;
        }

        function set(path: string): void {
            root.setWallpaper(path);
        }

        function list(): string {
            root.ensureCatalog();
            return root.catalog.map(w => w.path).join("\n");
        }

        target: "wallpaper"
    }

    FileView {
        printErrors: false
        path: root.currentNamePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.markPathFileReady(text().trim())
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                root.markPathFileReady("");
        }
    }

    FileView {
        printErrors: false
        path: root.colourSourceCachePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.markColourSourceFileReady(text().trim())
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                root.markColourSourceFileReady("");
        }
    }

    FileView {
        id: persistedScheme

        printErrors: false
        path: `${Paths.state}/scheme.json`
        watchChanges: true
        property string schemePayload: ""
        onLoaded: root.markSchemeFileReady(text())
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                root.markSchemeFileReady("");
        }
        onFileChanged: reload()
    }

    Loader {
        id: catalogLoader

        active: catalogReady
        asynchronous: true
        sourceComponent: Component {
            FileSystemModel {
                recursive: true
                path: Paths.wallsdir
                filter: FileSystemModel.Images
            }
        }
    }

    Process {
        id: videoScanProc

        stdout: StdioCollector {
            onStreamFinished: {
                const base = `${liveWallpaperDir}/`;
                const lines = text.trim().split("\n").filter(Boolean);
                console.log(`[Wallpapers] videoScanProc found ${lines.length} videos`);
                
                const newMap = Object.assign({}, videoThumbnailMap);
                
                root.videoEntries = lines.map(line => {
                    const parts = line.split("|");
                    const path = parts[0];
                    const thumb = parts[1];
                    if (thumb) newMap[path] = thumb;

                    const name = path.split("/").pop();
                    return {
                        path,
                        name,
                        relativePath: path.startsWith(base) ? path.slice(base.length) : name,
                        suffix: name.includes(".") ? name.split(".").pop().toLowerCase() : "",
                        isVideo: true
                    };
                });
                
                videoThumbnailMap = newMap;
                root.queueAllVideoThumbnails();
                
                if (root.isVideoPath(root.actualCurrent)) {
                    console.log("[Wallpapers] Post-scan refresh for current video wallpaper");
                    root.requestAccentRefresh(root.actualCurrent, false);
                }
            }
        }
    }

    Process {
        id: persistProc
    }

    Process {
        id: colourSourcePersistProc
    }

    Process {
        id: schemePersistProc
    }

    Timer {
        id: videoScanTimer
        interval: 2000
        repeat: false
        onTriggered: {
            videoScanProc.command = ["bash", "-lc", `
                if [ -d '${liveWallpaperDir.replace(/'/g, "'\\''")}' ]; then
                    find '${liveWallpaperDir.replace(/'/g, "'\\''")}' -maxdepth 1 -type f \\( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' -o -iname '*.mov' -o -iname '*.avi' -o -iname '*.m4v' \\) | sort | while read -r video; do
                        safe=$(echo "$video" | sed -e 's/[^A-Za-z0-9._-]/_/g')
                        thumb="${videoThumbnailDir.replace(/'/g, "'\\''")}/$safe.jpg"
                        if [ -s "$thumb" ]; then
                            printf "%s|%s\\n" "$video" "$thumb"
                        else
                            printf "%s|\\n" "$video"
                        fi
                    done
                fi
            `];
            videoScanProc.running = true;
        }
    }

    Timer {
        id: catalogPrewarmTimer
        interval: 5000
        repeat: false
        running: true
        onTriggered: root.ensureCatalog()
    }

    Component.onCompleted: {
        console.log(`[Wallpapers] Initialized. Live Dir: ${liveWallpaperDir}`);
        videoScanTimer.start();
    }

    Process {
        id: thumbnailProc

        property string inputPath: ""
        property string outputPath: ""

        stdout: StdioCollector {
            onStreamFinished: {
                const thumbnailPath = text.trim();
                console.log(`[Wallpapers] Thumbnail generated for ${thumbnailProc.inputPath}: ${thumbnailPath}`);
                if (thumbnailPath) {
                    const nextMap = Object.assign({}, root.videoThumbnailMap);
                    nextMap[thumbnailProc.inputPath] = thumbnailPath;
                    root.videoThumbnailMap = nextMap;
                    root.thumbnailUpdateCount++;

                    if (root.pendingCurrentColourPath === thumbnailProc.inputPath) {
                        const path = root.pendingCurrentColourPath;
                        console.log(`[Wallpapers] Triggering pending current accent refresh for ${path}`);
                        Qt.callLater(() => {
                            if (!root._bootstrapDone)
                                root.scheduleBootstrap();
                            else
                                root.requestAccentRefresh(path, false);
                        });
                    }
                    if (root.pendingPreviewColourPath === thumbnailProc.inputPath) {
                        const path = root.pendingPreviewColourPath;
                        console.log(`[Wallpapers] Triggering pending preview accent refresh for ${path}`);
                        Qt.callLater(() => root.requestAccentRefresh(path, true));
                    }
                }

                Qt.callLater(() => root.processNextThumbnail());
            }
        }
    }

    Process {
        id: getPreviewColoursProc

        property string targetWallPath: ""

        stdout: StdioCollector {
            onStreamFinished: {
                if (getPreviewColoursProc.targetWallPath !== root._lastPreviewWallPath) {
                    console.log("[Wallpapers] Ignoring stale preview palette result");
                    return;
                }
                if (!text || !text.trim().length) {
                    console.log("[Wallpapers] preview palette extract returned empty output");
                    return;
                }
                const payload = root.normalizePalettePayload(text);
                root._lastPreviewData = payload;
                root.colorsGenerated(payload, true);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    console.log("[Wallpapers/preview]", text.trim());
            }
        }
    }

    Process {
        id: getCurrentColoursProc

        property string targetSourcePath: ""

        stdout: StdioCollector {
            onStreamFinished: {
                if (getCurrentColoursProc.targetSourcePath
                    && getCurrentColoursProc.targetSourcePath !== root._lastRefreshPath) {
                    console.log("[Wallpapers] Ignoring stale current palette result");
                    return;
                }
                if (!text || !text.trim().length) {
                    console.log("[Wallpapers] wallpaper palette extract returned empty output");
                    return;
                }
                const payload = root.normalizePalettePayload(text);
                root._lastCurrentData = payload;
                if (getCurrentColoursProc.targetSourcePath)
                    root.persistColourSource(getCurrentColoursProc.targetSourcePath);
                root.persistSchemePayload(payload);
                root.colorsGenerated(payload, false);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    console.log("[Wallpapers/current]", text.trim());
            }
        }

        onExited: function(exitCode) {
            if (exitCode !== 0)
                console.log("[Wallpapers] wallpaper palette extract failed, exit:", exitCode);
        }
    }
}
