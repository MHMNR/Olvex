pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Olvex
import Olvex.Config
import qs.components.misc
import qs.services
import qs.utils

Singleton {
    id: root

    readonly property list<MprisPlayer> list: Mpris.players.values

    property MprisPlayer active: null
    property string currentArtUrl: ""
    property string currentTrackKey: ""
    readonly property bool activeIsPlaying: root.active !== null && (
        root.active.playbackStatus === "Playing"
        || root.active.playbackState === 0
        || root.active.isPlaying)

    property alias manualActive: props.manualActive

    property bool _recomputeScheduled: false
    property bool _refreshingPosition: false

    function _playerId(player: MprisPlayer): string {
        if (!player)
            return "";
        if (player.dbusName)
            return player.dbusName;
        return player.uniqueId !== undefined ? String(player.uniqueId) : "";
    }

    function _pickActivePlayer(): MprisPlayer {
        const players = Mpris.players.values;
        if (props.manualActive)
            return props.manualActive;
        const playing = players.find(p => root._isPlaying(p));
        return playing
            ?? players.find(p => root.getIdentity(p) === GlobalConfig.services.defaultPlayer)
            ?? players[0]
            ?? null;
    }

    function _recomputeActive(): void {
        const next = root._pickActivePlayer();
        const prevId = root._playerId(root.active);
        const nextId = root._playerId(next);
        if (root.active === next && prevId === nextId)
            return;
        root.active = next;
    }

    function _scheduleRecomputeActive(): void {
        if (root._recomputeScheduled)
            return;
        root._recomputeScheduled = true;
        Qt.callLater(() => {
            root._recomputeScheduled = false;
            root._recomputeActive();
        });
    }

    function _attachPlayer(player: MprisPlayer): void {
        if (!player)
            return;
        if (player.playbackStatusChanged)
            player.playbackStatusChanged.connect(root._scheduleRecomputeActive);
        if (player.playbackStateChanged)
            player.playbackStateChanged.connect(root._scheduleRecomputeActive);
        root._scheduleRecomputeActive();
        Qt.callLater(() => {
            root._kickStartupSync();
            root._scheduleArtPoll();
        });
    }

    function _detachPlayer(player: MprisPlayer): void {
        if (!player)
            return;
        if (player.playbackStatusChanged)
            player.playbackStatusChanged.disconnect(root._scheduleRecomputeActive);
        if (player.playbackStateChanged)
            player.playbackStateChanged.disconnect(root._scheduleRecomputeActive);
        root._scheduleRecomputeActive();
    }

    // Per-screen morph overlays (Drawers Variants = one ContentWindow per monitor)
    property var _mediaMorphByScreen: ({})
    property var mediaMorph: null

    function registerMediaMorph(screenName: string, overlay: var): void {
        if (!screenName || !overlay)
            return;
        const map = Object.assign({}, root._mediaMorphByScreen);
        map[screenName] = overlay;
        root._mediaMorphByScreen = map;
        root.mediaMorph = overlay;
    }

    function unregisterMediaMorph(screenName: string, overlay: var): void {
        if (!screenName)
            return;
        const map = Object.assign({}, root._mediaMorphByScreen);
        if (map[screenName] === overlay)
            delete map[screenName];
        root._mediaMorphByScreen = map;
        if (root.mediaMorph === overlay) {
            const keys = Object.keys(map);
            root.mediaMorph = keys.length ? map[keys[keys.length - 1]] : null;
        }
    }

    function mediaMorphForScreen(screenName: string): var {
        if (!screenName)
            return root.mediaMorph;
        return root._mediaMorphByScreen[screenName] ?? root.mediaMorph;
    }

    function getIdentity(player: MprisPlayer): string {
        if (!player) return "";
        const alias = GlobalConfig.services.playerAliases.find(a => a.from === player.identity);
        return alias?.to ?? player.identity;
    }

    function sanitizeArtUrl(url: string): string {
        let u = root.stripArtDisplayUrl(String(url || "").trim());
        if (!u)
            return "";
        // MPRIS/browser sources sometimes emit https:/host (single slash).
        u = u.replace(/^(https?):\/([^/])/i, "$1://$2");
        return u;
    }

    function isRemoteArtUrl(url: string): bool {
        const u = root.sanitizeArtUrl(url);
        return /^https?:\/\//i.test(u);
    }

    function getArtUrl(player: MprisPlayer): string {
        if (!player)
            return "";
        if (player.trackArtUrl)
            return root.sanitizeArtUrl(player.trackArtUrl);

        const meta = player.metadata;
        if (meta) {
            const art = meta["mpris:artUrl"] ?? meta["xesam:artUrl"] ?? "";
            if (art)
                return root.sanitizeArtUrl(art);
        }

        const url = meta?.["xesam:url"] ?? "";
        if (url.startsWith("https://www.youtube.com/watch") || url.startsWith("http://www.youtube.com/watch")) {
            const id = url.match(/[?&]v=([\w-]{11})/)?.[1];
            return id ? `https://img.youtube.com/vi/${id}/hqdefault.jpg` : "";
        }
        return "";
    }

    function getTrackKey(player: MprisPlayer): string {
        if (!player)
            return "";
        return [
            player.uniqueId !== undefined ? String(player.uniqueId) : "",
            player.trackTitle ?? "",
            player.trackArtist ?? "",
            player.trackAlbum ?? ""
        ].join("\x1f");
    }

    function stripArtDisplayUrl(url: string): string {
        if (!url)
            return "";
        const tag = url.indexOf("#olvex-art=");
        if (tag >= 0)
            return url.substring(0, tag);
        const hash = url.indexOf("#");
        if (hash >= 0)
            return url.substring(0, hash);
        return url;
    }

    property int artReloadNonce: 0
    property bool _artPollScheduled: false
    property bool _artReloadBusy: false

    function _bumpArtReload(): void {
        if (root._artReloadBusy)
            return;
        root._artReloadBusy = true;
        root.artReloadNonce++;
        Qt.callLater(() => {
            root._artReloadBusy = false;
        });
    }

    function _scheduleArtPoll(): void {
        if (root._artPollScheduled)
            return;
        root._artPollScheduled = true;
        Qt.callLater(() => {
            root._artPollScheduled = false;
            root._applyArtState();
        });
    }

    function _applyArtState(): void {
        const p = root.active;
        if (!p) {
            if (root.currentTrackKey !== "")
                root.currentTrackKey = "";
            if (root.currentArtUrl !== "")
                root.currentArtUrl = "";
            artPollTimer.stop();
            return;
        }

        const key = root.getTrackKey(p);
        const url = root.getArtUrl(p);
        let changed = false;
        if (key !== root.currentTrackKey) {
            root.currentTrackKey = key;
            changed = true;
        }
        if (url !== root.currentArtUrl) {
            root.currentArtUrl = url;
            changed = true;
        }
        if (changed)
            root._bumpArtReload();

        artPollTimer.attempts = 0;
        artPollTimer.start();
    }

    Timer {
        id: artPollTimer
        interval: 350
        repeat: true
        property int attempts: 0

        onTriggered: {
            if (!root.active) {
                stop();
                attempts = 0;
                return;
            }
            const url = root.getArtUrl(root.active);
            if (url !== root.currentArtUrl) {
                root.currentArtUrl = url;
                root._bumpArtReload();
            }
            attempts++;
            if (attempts >= 16)
                stop();
        }
    }

    // Process component for one-shot commands
    Process {
        id: nudgeProcess
        onExited: running = false
    }

    function nudge(method: string) {
        const p = root.active;
        if (!p) return;
        
        let hint = p.desktopEntry || p.identity.toLowerCase();
        if (hint.includes("firefox")) hint = "firefox";
        else if (hint.includes("chrome")) hint = "chrome";
        else if (hint.includes("chromium")) hint = "chromium";
        else hint = hint.split(" ")[0];

        // CLEAN BUSCTL NUDGE: Uses awk to reliably get the first column (bus name)
        const cmd = `for bus in $(busctl --user list | awk '{print $1}' | grep "org.mpris.MediaPlayer2.${hint}"); do busctl --user call $bus /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player ${method}; done`;
        
        nudgeProcess.command = ["bash", "-c", cmd];
        nudgeProcess.running = true;
    }

    function togglePlaying() {
        const p = root.active;
        if (p) {
            // Browser-optimized toggle logic: relies on D-Bus nudges to bypass unreliable internal status reporting.
            
            // To prevent double-triggering (Play + Toggle = Pause), we use ONLY the nudge for browsers.
            // For local players, we use the standard toggle.
            const isBrowser = p.identity.toLowerCase().match(/firefox|chrome|chromium/);
            if (!isBrowser) {
                p.playPause();
            }
            nudge("PlayPause");
        }
    }

    function next() {
        if (root.active) {
            root.active.next();
            nudge("Next");
        }
    }

    function previous() {
        if (root.active) {
            root.active.previous();
            nudge("Previous");
        }
    }

    Connections {
        function onPostTrackChanged() {
            if (!GlobalConfig.utilities.toasts.nowPlaying) {
                return;
            }
            if (root.active && root.active.trackArtist != "" && root.active.trackTitle != "") {
                Toaster.toast(qsTr("Now Playing"), qsTr("%1 - %2").arg(root.active.trackArtist).arg(root.active.trackTitle), "music_note");
            }
        }

        target: root.active
    }

    PersistentProperties {
        id: props
        property MprisPlayer manualActive
        reloadableId: "players"
    }

    PersistentProperties {
        id: accentProps
        property string cacheJson: "{}"
        property string lastArtUrl: ""
        property string lastVisualizer: ""
        property string lastPlayButtonBg: ""
        reloadableId: "mediaAccent"
    }

    readonly property string lastMediaArtUrl: accentProps.lastArtUrl
    readonly property string mediaAccentPath: `${Paths.state}/media/accent.json`

    property bool bootAccentLoaded: false
    // Stored accents — never bind to Colours.palette (caused binding recursion with pickers).
    property color bootVisualizerAccent: "#4F378A"
    property color bootPlayButtonBg: "#CFBCFF"
    property color bootPlayIconColor: Qt.rgba(0, 0, 0, 0.92)

    property color liveVisualizerAccent: "#4F378A"
    property color livePlayButtonBg: "#CFBCFF"
    property color livePlayIconColor: Qt.rgba(0, 0, 0, 0.92)
    property bool liveAccentReady: false

    readonly property color musicVisualizerAccent: liveAccentReady
        ? liveVisualizerAccent
        : bootVisualizerAccent
    readonly property color musicPlayButtonBg: liveAccentReady
        ? livePlayButtonBg
        : bootPlayButtonBg
    readonly property color musicPlayIconColor: liveAccentReady
        ? livePlayIconColor
        : bootPlayIconColor
        
    property color bootSurfaceColor: Colours.palette.m3surfaceContainerHigh
    property color bootOnSurfaceColor: Colours.palette.m3onSurface
    property color liveSurfaceColor: Colours.palette.m3surfaceContainerHigh
    property color liveOnSurfaceColor: Colours.palette.m3onSurface
    readonly property color musicSurfaceColor: liveAccentReady ? liveSurfaceColor : bootSurfaceColor
    readonly property color musicOnSurfaceColor: liveAccentReady ? liveOnSurfaceColor : bootOnSurfaceColor

    readonly property bool musicAccentReady: liveAccentReady || bootAccentLoaded
    property color musicOnAccent: "#E9DDFF"

    function resolvePlayIconColor(playButtonBg: color, playIconColor: color): color {
        return Qt.rgba(0, 0, 0, 0.92);
    }

    function _updateMusicOnAccent(): void {
        root.musicOnAccent = Colours.on(root.musicVisualizerAccent);
    }

    function syncBootAccentsFromSystem(): void {
        if (root.liveAccentReady || root.bootAccentLoaded)
            return;
        root.bootVisualizerAccent = Colours.palette.m3primaryContainer;
        root.bootPlayButtonBg = Colours.palette.m3primary;
        root.bootSurfaceColor = Colours.palette.m3surfaceContainerHigh;
        root.bootOnSurfaceColor = Colours.palette.m3onSurface;
        root.bootPlayIconColor = root.resolvePlayIconColor(root.bootPlayButtonBg, null);
        root.liveVisualizerAccent = root.bootVisualizerAccent;
        root.livePlayButtonBg = root.bootPlayButtonBg;
        root.liveSurfaceColor = root.bootSurfaceColor;
        root.liveOnSurfaceColor = root.bootOnSurfaceColor;
        root.livePlayIconColor = root.bootPlayIconColor;
        root._updateMusicOnAccent();
    }

    property var _mediaAccentSession: ({})
    property int mediaAccentRevision: 0

    signal mediaAccentPrewarmed()
    signal mediaAccentRefreshNeeded()

    function _bumpMediaAccentRevision(): void {
        root.mediaAccentRevision++;
    }

    function requestMediaAccentRefresh(): void {
        root.mediaAccentRefreshNeeded();
    }

    property bool _publishingAccent: false
    property bool _ingestingAccent: false
    property bool _suppressAccentFileIngest: false

    function publishLiveAccent(visualizer: color, playButtonBg: color, artUrl: string, playIconColor: color, surfaceColor: color, onSurfaceColor: color): void {
        if (root._publishingAccent)
            return;

        const playValid = playButtonBg && playButtonBg.a > 0 && playButtonBg.hslLightness > 0.02;
        const visValid = visualizer && visualizer.a > 0 && visualizer.hslLightness > 0.02;
        const nextVis = visValid ? visualizer : root.liveVisualizerAccent;
        const nextPlay = playValid ? playButtonBg : root.livePlayButtonBg;
        const nextIcon = playValid
            ? root.resolvePlayIconColor(nextPlay, playIconColor)
            : root.livePlayIconColor;
            
        const nextSurface = (surfaceColor && surfaceColor.a > 0) ? surfaceColor : root.liveSurfaceColor;
        const nextOnSurface = (onSurfaceColor && onSurfaceColor.a > 0) ? onSurfaceColor : root.liveOnSurfaceColor;

        const unchanged = root.liveAccentReady
            && root.liveVisualizerAccent === nextVis
            && root.livePlayButtonBg === nextPlay
            && root.liveSurfaceColor === nextSurface
            && root.liveOnSurfaceColor === nextOnSurface
            && root.livePlayIconColor === nextIcon;
        if (unchanged && !artUrl)
            return;

        root._publishingAccent = true;
        root.liveVisualizerAccent = nextVis;
        root.livePlayButtonBg = nextPlay;
        root.liveSurfaceColor = nextSurface;
        root.liveOnSurfaceColor = nextOnSurface;
        root.livePlayIconColor = nextIcon;
        root.liveAccentReady = true;
        root.bootVisualizerAccent = nextVis;
        root.bootPlayButtonBg = nextPlay;
        root.bootSurfaceColor = nextSurface;
        root.bootOnSurfaceColor = nextOnSurface;
        root.bootPlayIconColor = nextIcon;
        root.bootAccentLoaded = true;
        if (artUrl && visValid && playValid)
            root.storeMediaAccent(artUrl, nextVis.toString(), nextPlay.toString(), nextIcon.toString());
        else if (artUrl && playValid)
            root._bumpMediaAccentRevision();
        else if (!unchanged)
            root._bumpMediaAccentRevision();
        root._updateMusicOnAccent();
        root._publishingAccent = false;
    }

    function publishPlayButtonBg(playButtonBg: color, artUrl: string, playIconColor: color): void {
        if (root._publishingAccent)
            return;
        if (!playButtonBg || playButtonBg.a <= 0 || playButtonBg.hslLightness <= 0.02)
            return;

        const nextIcon = root.resolvePlayIconColor(playButtonBg, playIconColor);
        root._publishingAccent = true;
        root.livePlayButtonBg = playButtonBg;
        root.bootPlayButtonBg = playButtonBg;
        root.livePlayIconColor = nextIcon;
        root.bootPlayIconColor = nextIcon;
        root.liveAccentReady = true;
        root.bootAccentLoaded = true;
        root._updateMusicOnAccent();
        root._publishingAccent = false;
    }

    function clearLiveAccent(): void {
        root.liveAccentReady = false;
        root.liveVisualizerAccent = root.bootVisualizerAccent;
        root.livePlayButtonBg = root.bootPlayButtonBg;
        root.liveSurfaceColor = root.bootSurfaceColor;
        root.liveOnSurfaceColor = root.bootOnSurfaceColor;
        root.livePlayIconColor = root.bootPlayIconColor;
        root._updateMusicOnAccent();
    }

    property string _lastIngestHash: ""

    function ingestAccentPayload(data: var): void {
        if (!data || typeof data !== "object" || root._ingestingAccent)
            return;

        root._ingestingAccent = true;

        const lastArtUrl = data.lastArtUrl ?? "";
        const lastVisualizer = data.lastVisualizer ?? "";
        const lastPlayButtonBg = data.lastPlayButtonBg ?? "";
        const cache = data.cache && typeof data.cache === "object" ? data.cache : {};
        const hash = JSON.stringify({ lastArtUrl, lastVisualizer, lastPlayButtonBg });
        if (hash === root._lastIngestHash && root.bootAccentLoaded) {
            root._ingestingAccent = false;
            return;
        }
        root._lastIngestHash = hash;

        if (lastArtUrl)
            accentProps.lastArtUrl = lastArtUrl;
        if (lastVisualizer)
            accentProps.lastVisualizer = lastVisualizer;
        if (lastPlayButtonBg)
            accentProps.lastPlayButtonBg = lastPlayButtonBg;
        accentProps.cacheJson = JSON.stringify(cache);

        if (lastVisualizer && lastPlayButtonBg) {
            const bootPlay = Qt.color(lastPlayButtonBg);
            root.bootVisualizerAccent = Qt.color(lastVisualizer);
            root.bootPlayButtonBg = bootPlay;
            root.bootPlayIconColor = root.resolvePlayIconColor(bootPlay, null);
            root.bootAccentLoaded = true;
            if (!root.liveAccentReady) {
                root.liveVisualizerAccent = root.bootVisualizerAccent;
                root.livePlayButtonBg = root.bootPlayButtonBg;
                root.livePlayIconColor = root.bootPlayIconColor;
            }
            root._updateMusicOnAccent();
        }

        for (const key of Object.keys(cache)) {
            const entry = cache[key];
            if (entry?.visualizer && entry?.playButtonBg)
                root._mediaAccentSession[root.normalizeMediaArtUrl(key)] = entry;
        }

        root._bumpMediaAccentRevision();
        if (!root._publishingAccent) {
            root.mediaAccentPrewarmed();
            root.requestMediaAccentRefresh();
        }
        root._ingestingAccent = false;
    }

    function persistAccentFile(): void {
        const payload = JSON.stringify({
            lastArtUrl: accentProps.lastArtUrl,
            lastVisualizer: accentProps.lastVisualizer,
            lastPlayButtonBg: accentProps.lastPlayButtonBg,
            cache: root._readAccentDiskCache()
        });
        const escaped = payload.replace(/'/g, "'\\''");
        const dir = root.mediaAccentPath.replace(/\/[^/]+$/, "");
        root._suppressAccentFileIngest = true;
        persistAccentProc.command = ["bash", "-lc",
            `mkdir -p '${dir.replace(/'/g, "'\\''")}' && printf '%s' '${escaped}' > '${root.mediaAccentPath.replace(/'/g, "'\\''")}'`];
        persistAccentProc.running = true;
    }

    function normalizeMediaArtUrl(url: string): string {
        if (!url)
            return "";
        url = root.sanitizeArtUrl(url);
        if (url.startsWith("/")) {
            try {
                url = decodeURIComponent(url);
            } catch (e) {
            }
            return "file://" + url;
        }
        if (url.startsWith("file://")) {
            let path = url.replace(/^file:\/\/+/, "");
            try {
                path = decodeURIComponent(path);
            } catch (e) {
            }
            if (!path.startsWith("/"))
                path = "/" + path;
            return "file://" + path;
        }
        const tag = url.indexOf("#olvex-art=");
        if (tag >= 0)
            url = url.substring(0, tag);
        const hash = url.indexOf("#");
        if (hash >= 0)
            url = url.substring(0, hash);
        const query = url.indexOf("?");
        if (query >= 0)
            url = url.substring(0, query);
        return url;
    }

    function _coerceAccentEntry(entry: var): var {
        if (!entry)
            return null;
        const visualizer = entry.visualizer;
        const playButtonBg = entry.playButtonBg;
        if (!visualizer || !playButtonBg)
            return null;
        const playBg = typeof playButtonBg === "string" ? Qt.color(playButtonBg) : playButtonBg;
        const playIconRaw = entry.playIconColor;
        const playIcon = playIconRaw
            ? (typeof playIconRaw === "string" ? Qt.color(playIconRaw) : playIconRaw)
            : null;
        return {
            visualizer: typeof visualizer === "string" ? Qt.color(visualizer) : visualizer,
            playButtonBg: playBg,
            playIconColor: root.resolvePlayIconColor(playBg, playIcon)
        };
    }

    function prewarmMediaAccent(): void {
        root._readAccentDiskCache();
        if (accentProps.lastArtUrl)
            root.getMediaAccent(accentProps.lastArtUrl);
        if (root.currentArtUrl)
            root.getMediaAccent(root.currentArtUrl);
        else {
            const player = root.active;
            const url = player ? root.getArtUrl(player) : "";
            if (url)
                root.getMediaAccent(url);
        }
        root._bumpMediaAccentRevision();
        root.mediaAccentPrewarmed();
    }

    function lookupMediaAccent(artUrl: string): var {
        if (!artUrl)
            return root._coerceAccentEntry(root.getBootAccent(""));
        const hit = root.getMediaAccent(artUrl);
        if (hit)
            return root._coerceAccentEntry(hit);
        return root._coerceAccentEntry(root.getBootAccent(artUrl));
    }

    function getBootAccent(artUrl: string): var {
        if (!accentProps.lastVisualizer || !accentProps.lastPlayButtonBg)
            return null;
        if (!artUrl) {
            return {
                visualizer: accentProps.lastVisualizer,
                playButtonBg: accentProps.lastPlayButtonBg
            };
        }
        const norm = root.normalizeMediaArtUrl(artUrl);
        const lastNorm = root.normalizeMediaArtUrl(accentProps.lastArtUrl);
        if (norm !== lastNorm)
            return null;
        return {
            visualizer: accentProps.lastVisualizer,
            playButtonBg: accentProps.lastPlayButtonBg
        };
    }

    function _readAccentDiskCache(): var {
        try {
            const parsed = JSON.parse(accentProps.cacheJson);
            return parsed && typeof parsed === "object" ? parsed : {};
        } catch (e) {
            return {};
        }
    }

    function getMediaAccent(artUrl: string): var {
        if (!artUrl)
            return null;
        const norm = root.normalizeMediaArtUrl(artUrl);
        const session = root._mediaAccentSession[norm] ?? root._mediaAccentSession[artUrl];
        if (session)
            return session;

        const disk = root._readAccentDiskCache();
        let entry = disk[norm] ?? disk[artUrl];
        if (!entry) {
            for (const key of Object.keys(disk)) {
                if (root.normalizeMediaArtUrl(key) === norm) {
                    entry = disk[key];
                    break;
                }
            }
        }
        if (!entry)
            return null;
        root._mediaAccentSession[norm] = entry;
        return entry;
    }

    function storeMediaAccent(artUrl: string, visualizer: string, playButtonBg: string, playIconColor: string): void {
        if (!artUrl)
            return;
        const norm = root.normalizeMediaArtUrl(artUrl);
        const existing = root._mediaAccentSession[norm];
        const iconStr = playIconColor
            || root.resolvePlayIconColor(Qt.color(playButtonBg), null).toString();
        if (existing?.visualizer === visualizer
            && existing?.playButtonBg === playButtonBg
            && existing?.playIconColor === iconStr
            && accentProps.lastArtUrl === norm
            && accentProps.lastVisualizer === visualizer
            && accentProps.lastPlayButtonBg === playButtonBg)
            return;
        const entry = {
            visualizer: visualizer,
            playButtonBg: playButtonBg,
            playIconColor: iconStr
        };
        root._mediaAccentSession[norm] = entry;

        const disk = root._readAccentDiskCache();
        disk[norm] = entry;
        const keys = Object.keys(disk);
        if (keys.length > 48) {
            for (let i = 0; i < keys.length - 48; i++)
                delete disk[keys[i]];
        }
        accentProps.cacheJson = JSON.stringify(disk);
        accentProps.lastArtUrl = norm;
        accentProps.lastVisualizer = entry.visualizer;
        accentProps.lastPlayButtonBg = entry.playButtonBg;
        root._bumpMediaAccentRevision();
        root.persistAccentFile();
    }

    FileView {
        id: mediaAccentFile

        printErrors: false
        path: root.mediaAccentPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            if (root._suppressAccentFileIngest) {
                root._suppressAccentFileIngest = false;
                return;
            }
            try {
                root.ingestAccentPayload(JSON.parse(text()));
            } catch (e) {
                console.log("[Players] media accent file parse failed:", e);
            }
        }
        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound)
                return;
            if (!accentProps.lastVisualizer || !accentProps.lastPlayButtonBg)
                return;
            root.ingestAccentPayload({
                lastArtUrl: accentProps.lastArtUrl,
                lastVisualizer: accentProps.lastVisualizer,
                lastPlayButtonBg: accentProps.lastPlayButtonBg,
                cache: root._readAccentDiskCache()
            });
            root.persistAccentFile();
        }
    }

    Process {
        id: persistAccentProc
        onExited: running = false
    }

    // ── Global Progress Sync Engine ──────────────────────────────────────
    // Single source of truth for all media progress bars across Olvex.
    //
    // HOW IT WORKS:
    //   MPRIS Position is a cached D-Bus property — it does NOT update
    //   automatically as audio plays. The only way to get the current
    //   position is to force a cache refresh by emitting positionChanged().
    //   One global 250ms timer does this, then reads the fresh value.
    //   All progress bars across Olvex bind to these two properties.
    //
    // WHY NOT local interpolation:
    //   Date.now() is not a QML reactive dependency. Computed readonly
    //   bindings that use it never re-evaluate on their own. Writing
    //   explicit values from a timer is the only reliable approach.

    property real interpolatedPosition: 0
    property real interpolatedLength: 0
    property real interpolatedProgress: 0

    property real _syncPosition: 0
    property real _syncTime: 0

    function _isPlaying(player: MprisPlayer): bool {
        if (!player)
            return false;
        return player.playbackStatus === "Playing"
            || player.playbackState === 0
            || player.isPlaying;
    }

    function _applySyncAnchor(): void {
        if (seekGuard.running || root._refreshingPosition)
            return;

        const p = root.active;
        if (!p) {
            root.interpolatedPosition = 0;
            root.interpolatedProgress = 0;
            root.interpolatedLength = 0;
            return;
        }

        root._syncPosition = p.position ?? 0;
        root._syncTime = Date.now();
        root._updateInterpolation();
    }

    function _syncNow(): void {
        if (seekGuard.running)
            return;

        const p = root.active;
        if (!p) {
            root.interpolatedPosition = 0;
            root.interpolatedProgress = 0;
            root.interpolatedLength = 0;
            return;
        }

        // MPRIS position refresh is async — read anchor after the cache update lands.
        if (p.positionSupported) {
            root._refreshingPosition = true;
            p.positionChanged();
            root._refreshingPosition = false;
        }
        Qt.callLater(root._applySyncAnchor);
    }

    function _kickStartupSync(): void {
        startupSync.attempts = 0;
        if (root.active)
            startupSync.start();
        else
            startupSync.stop();
    }

    function _updateInterpolation(): void {
        const p = root.active;
        if (!p) return;
        
        let currentPos = root._syncPosition;
        if (root._isPlaying(p)) {
            const elapsed = (Date.now() - root._syncTime) / 1000;
            currentPos = Math.min(root._syncPosition + elapsed, p.length ?? 0);
        }
        
        root.interpolatedPosition = currentPos;
        
        // Protect against backends that drop length metadata during seek
        const rawLen = p.length ?? 0;
        if (rawLen > 0 && Math.abs(rawLen - currentPos) > 1) {
            root.interpolatedLength = rawLen;
        } else if (root.interpolatedLength === 0) {
            root.interpolatedLength = rawLen;
        }
        
        root.interpolatedProgress = root.interpolatedLength > 0 ? Math.max(0, Math.min(1, currentPos / root.interpolatedLength)) : 0;
    }

    // Called by UI seek bars.
    function seekTo(fraction: real): void {
        const p = root.active;
        if (!p || !p.canSeek || !p.positionSupported) return;
        const len = root.interpolatedLength > 0 ? root.interpolatedLength : (p.length ?? 0);
        const targetPos = fraction * len;
        
        // Issue D-Bus command
        p.position = targetPos;
        
        // Immediately update our local interpolation anchor so the UI jumps instantly
        // and the 250ms tick continues smoothly from the new position.
        root._syncPosition = targetPos;
        root._syncTime = Date.now();
        root._updateInterpolation();
        
        // Block incoming D-Bus position updates for 1500ms. Some players (like Spotify)
        // are slow to process seeks and will echo back their old position, nuking the sync.
        seekGuard.restart();
    }

    Timer {
        id: seekGuard
        interval: 1500
        repeat: false
    }

    // Retry until MPRIS metadata is ready after shell/player attach.
    Timer {
        id: startupSync
        interval: 250
        repeat: true
        property int attempts: 0

        onTriggered: {
            if (!root.active) {
                stop();
                attempts = 0;
                return;
            }
            root._syncNow();
            attempts++;
            const playing = root._isPlaying(root.active);
            const len = root.interpolatedLength > 0 ? root.interpolatedLength : (root.active.length ?? 0);
            // Playing after shell restart: length may arrive before position — keep polling.
            if (playing) {
                if (attempts >= 20)
                    stop();
            } else if (len > 0 || attempts >= 8) {
                stop();
            }
        }
    }

    // 250ms global tick — smooth interpolation between periodic MPRIS refreshes.
    Timer {
        id: progressTick
        interval: 250
        repeat: true
        running: root._isPlaying(root.active)
        triggeredOnStart: true
        property int ticks: 0

        onRunningChanged: {
            if (running) {
                ticks = 0;
                Qt.callLater(root._syncNow);
            }
        }

        onTriggered: {
            root._updateInterpolation();
            if (ticks % 4 === 0)
                root._syncNow();
            ticks++;
        }
    }

    // Resync local anchors when D-Bus sends meaningful events
    Connections {
        target: root.active
        ignoreUnknownSignals: true
        function onPlaybackStatusChanged() {
            root._scheduleRecomputeActive();
            Qt.callLater(root._syncNow);
        }
        function onPlaybackStateChanged() {
            root._scheduleRecomputeActive();
            Qt.callLater(root._syncNow);
        }
        function onTrackTitleChanged()     { Qt.callLater(root._syncNow); root._scheduleArtPoll(); }
        function onTrackArtistChanged()    { Qt.callLater(root._syncNow); root._scheduleArtPoll(); }
        function onTrackAlbumChanged()     { root._scheduleArtPoll(); }
        function onTrackArtUrlChanged()    { root._scheduleArtPoll(); }
        function onLengthChanged()         { Qt.callLater(root._syncNow); }
        function onPositionChanged() {
            root._applySyncAnchor();
        }
    }

    function _onActivePlayerChanged(): void {
        root._syncNow();
        root._kickStartupSync();
        root._scheduleArtPoll();
        if (root.active)
            root.requestMediaAccentRefresh();
    }

    onActiveChanged: Qt.callLater(root._onActivePlayerChanged)

    // ─────────────────────────────────────────────────────────────────────

    Instantiator {
        model: Mpris.players

        delegate: QtObject {
            required property var modelData

            Component.onCompleted: root._attachPlayer(modelData)
            Component.onDestruction: root._detachPlayer(modelData)
        }
    }

    Connections {
        target: props
        function onManualActiveChanged() {
            root._scheduleRecomputeActive();
        }
    }

    Connections {
        target: GlobalConfig.appearance
        function onSchemeVariantChanged() {
            root.syncBootAccentsFromSystem();
        }
        function onThemeModeChanged() {
            root.syncBootAccentsFromSystem();
        }
    }

    Component.onCompleted: {
        root.syncBootAccentsFromSystem();
        root._recomputeActive();
        root.prewarmMediaAccent();
        Qt.callLater(root._syncNow);
        root._kickStartupSync();
        root._scheduleArtPoll();
        accentRefreshDeferTimer.start();
    }

    Timer {
        id: accentRefreshDeferTimer
        interval: 1500
        repeat: false
        onTriggered: root.requestMediaAccentRefresh()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaToggle"
        description: "Toggle media playback"
        onPressed: root.togglePlaying()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaPrev"
        description: "Previous track"
        onPressed: root.previous()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaNext"
        description: "Next track"
        onPressed: root.next()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaStop"
        description: "Stop media playback"
        onPressed: root.active?.stop()
    }

    IpcHandler {
        function getActive(prop: string): string {
            const active = root.active;
            return active ? active[prop] ?? "Invalid property" : "No active player";
        }

        function list(): string {
            return root.list.map(p => root.getIdentity(p)).join("\n");
        }

        function play(): void { if (root.active) root.active.play() }
        function pause(): void { if (root.active) root.active.pause() }
        function playPause(): void { root.togglePlaying() }
        function previous(): void { root.previous() }
        function next(): void { root.next() }
        function stop(): void { root.active?.stop() }

        target: "mpris"
    }
}
