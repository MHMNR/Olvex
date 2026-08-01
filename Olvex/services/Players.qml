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

    readonly property list<MprisPlayer> list: {
        const players = Mpris.players.values;
        const hasPlasma = players.some(p => {
            const dbus = (p.dbusName || p.identity || "").toLowerCase();
            return dbus.includes("plasma") || dbus.includes("browser-integration");
        });
        const filtered = hasPlasma ? players.filter(p => {
            const dbus = (p.dbusName || p.identity || "").toLowerCase();
            const isRawBrowser = (dbus.includes("firefox") || dbus.includes("chrome") || dbus.includes("chromium") || dbus.includes("brave")) && !dbus.includes("plasma");
            return !isRawBrowser;
        }) : players;

        return filtered.filter(p => {
            const dbus = (p.dbusName || "").toLowerCase();
            const id = (p.identity || "").toLowerCase().trim();

            // 1. Check Bluetooth speaker/headset device names (e.g. "m3", "m3 speaker", bluetooth devices)
            if (id === "m3" || id.startsWith("m3 ") || id.endsWith(" m3") || id.includes("m3") || id.includes("bluetooth") || id.includes("speaker") || id.includes("headset") || id.includes("headphone") || id.includes("earbud") || id.includes("airpods") || id.includes("soundbar") || id.includes("wireless"))
                return false;

            // 2. Check DBus names for Bluetooth & audio infrastructure daemons
            if (dbus.includes("bluez") || dbus.includes("bluetooth") || dbus.includes("a2dp") || dbus.includes("avrcp") || dbus.includes("pipewire") || dbus.includes("pulseaudio") || dbus.includes("alsa"))
                return false;

            // 3. Check hardware audio sink keywords
            if (id.includes("analog stereo") || id.includes("audio controller") || id.includes("built-in audio") || id.includes("output device") || id.includes("hd audio") || id.includes("default sink") || id.includes("pipewire-output") || id.includes("sound card"))
                return false;

            return true;
        });
    }

    property MprisPlayer active: null
    property string currentArtUrl: ""
    property string currentTrackKey: ""
    readonly property bool activeIsPlaying: root.active !== null && (root.active.playbackStatus === "Playing" || root.active.playbackState === 0 || root.active.isPlaying)

    property alias manualActive: props.manualActive

    property bool _recomputeScheduled: false
    property bool _syncNowScheduled: false
    property bool _refreshingPosition: false
    function _playerId(player: MprisPlayer): string {
        if (!player)
            return "";
        if (player.dbusName)
            return player.dbusName;
        return player.uniqueId !== undefined ? String(player.uniqueId) : "";
    }

    function _isSameMediaSource(p1: MprisPlayer, p2: MprisPlayer): bool {
        if (!p1 || !p2)
            return false;
        if (p1 === p2)
            return true;
        const id1 = (p1.dbusName || p1.identity || "").toLowerCase();
        const id2 = (p2.dbusName || p2.identity || "").toLowerCase();
        const isPlasma1 = id1.includes("plasma") || id1.includes("browser-integration");
        const isPlasma2 = id2.includes("plasma") || id2.includes("browser-integration");
        const isBrowser1 = id1.includes("firefox") || id1.includes("chrome") || id1.includes("chromium") || id1.includes("brave") || id1.includes("opera") || id1.includes("vivaldi");
        const isBrowser2 = id2.includes("firefox") || id2.includes("chrome") || id2.includes("chromium") || id2.includes("brave") || id2.includes("opera") || id2.includes("vivaldi");

        if ((isPlasma1 && isBrowser2) || (isPlasma2 && isBrowser1) || (isPlasma1 && isPlasma2))
            return true;

        const t1 = (p1.trackTitle || "").toLowerCase().trim();
        const t2 = (p2.trackTitle || "").toLowerCase().trim();
        if (t1 && t2 && (t1.includes(t2) || t2.includes(t1)))
            return true;

        return false;
    }

    function _pickActivePlayer(): MprisPlayer {
        const players = root.list;
        if (props.manualActive) {
            const manualMatch = players.find(p => p === props.manualActive || root._isSameMediaSource(p, props.manualActive));
            if (manualMatch)
                return manualMatch;
            props.manualActive = null;
        }

        if (root.active && players.some(p => root._isSameMediaSource(p, root.active))) {
            const playing = players.find(p => root._isPlaying(p));
            if (playing && !root._isSameMediaSource(playing, root.active)) {
                return playing;
            }
            return root.active;
        }

        const playing = players.find(p => root._isPlaying(p));
        if (playing)
            return playing;

        return players.find(p => root.getIdentity(p) === GlobalConfig.services.defaultPlayer) ?? players[0] ?? null;
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
        if (!player)
            return "";
        const alias = GlobalConfig.services.playerAliases.find(a => a.from === player.identity);
        if (alias?.to)
            return alias.to;

        let name = player.identity || "";
        if (!name && player.dbusName) {
            const parts = player.dbusName.split('.');
            name = parts[parts.length - 1] || "";
        }

        // Clean up raw dbus name formatting
        name = name.replace(/^(org\.mpris\.MediaPlayer2\.|MediaPlayer2\.)/i, "");

        // If identity string is a Bluetooth device or audio output device description, fallback to app name or "Media App"
        const lower = name.toLowerCase();
        const dbusLower = (player.dbusName || "").toLowerCase();
        if (dbusLower.includes("bluez") || dbusLower.includes("bluetooth") || lower.includes("analog stereo") || lower.includes("audio controller") || lower.includes("built-in audio") || lower.includes("hd audio") || lower.includes("output device") || lower.includes("speaker") || lower.includes("headphones") || lower.includes("alsa plug-in") || lower.includes("sound card")) {
            if (player.dbusName) {
                const parts = player.dbusName.split('.');
                const appPart = parts[parts.length - 1] || "";
                if (appPart && !appPart.toLowerCase().includes("sink") && !appPart.toLowerCase().includes("audio") && !appPart.toLowerCase().includes("bluez")) {
                    name = appPart;
                } else {
                    return "Media App";
                }
            } else {
                return "Media App";
            }
        }

        return name || "Media App";
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
        return [player.uniqueId !== undefined ? String(player.uniqueId) : "", player.trackTitle ?? "", player.trackArtist ?? "", player.trackAlbum ?? ""].join("\x1f");
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
        let url = root.getArtUrl(p);

        // Preserve current artwork for the same track if URL is empty or temporary during pause
        if (!url && key === root.currentTrackKey && root.currentArtUrl !== "") {
            url = root.currentArtUrl;
        }

        let changed = false;
        if (key !== root.currentTrackKey) {
            root.currentTrackKey = key;
            changed = true;
        }
        if (url !== root.currentArtUrl && (key !== root.currentTrackKey || !root.currentArtUrl)) {
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
        if (!p)
            return;

        // Prefer dbusName for exact targeting (handles Plasma Integration,
        // players registered with instance suffixes, etc.)
        const busName = p.dbusName ? String(p.dbusName) : "";
        let cmd;
        if (busName && busName.startsWith("org.mpris.MediaPlayer2.")) {
            cmd = `busctl --user call '${busName}' /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player ${method} 2>/dev/null || true`;
        } else {
            // Fallback: match by player identity hint
            let hint = (p.desktopEntry || p.identity || "").toLowerCase().trim().split(/\s+/)[0];
            if (hint.includes("firefox"))
                hint = "firefox";
            else if (hint.includes("chrome"))
                hint = "chrome";
            else if (hint.includes("chromium"))
                hint = "chromium";
            else if (hint.includes("plasma") || hint.includes("browser-integration"))
                hint = "plasma-browser-integration";

            cmd = `for bus in $(busctl --user list | awk '{print $1}' | grep "org.mpris.MediaPlayer2.${hint}"); do busctl --user call "$bus" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player ${method} 2>/dev/null; done`;
        }

        nudgeProcess.command = ["bash", "-c", cmd];
        nudgeProcess.running = true;
    }

    function togglePlaying() {
        // Use direct busctl nudge — bypasses Quickshell's stale canPlay guard
        nudge("PlayPause");
    }

    function next() {
        // Do NOT call root.active.next() — Quickshell silently rejects when
        // canGoNext is cached-false even if D-Bus reports true. Go direct.
        nudge("Next");
    }

    function previous() {
        nudge("Previous");
    }

    Connections {
        function onPostTrackChanged() {
            if (!GlobalConfig.qspanel.toasts.nowPlaying) {
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

        onManualActiveChanged: {
            root._recomputeActive();
        }
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

    property color bootSurfaceColor: Colours.palette.m3surfaceContainerHigh
    property color bootOnSurfaceColor: Colours.palette.m3onSurface
    property color liveSurfaceColor: Colours.palette.m3surfaceContainerHigh
    property color liveOnSurfaceColor: Colours.palette.m3onSurface

    property color displayVisualizerAccent: liveVisualizerAccent
    property color displayPlayButtonBg: livePlayButtonBg
    property color displayPlayIconColor: livePlayIconColor
    property color displaySurfaceColor: liveSurfaceColor
    property color displayOnSurfaceColor: liveOnSurfaceColor
    property color _accentAnimFromVisualizer: liveVisualizerAccent
    property color _accentAnimFromPlayBg: livePlayButtonBg
    property color _accentAnimFromPlayIcon: livePlayIconColor
    property color _accentAnimFromSurface: liveSurfaceColor
    property color _accentAnimFromOnSurface: liveOnSurfaceColor
    property color _accentAnimToVisualizer: liveVisualizerAccent
    property color _accentAnimToPlayBg: livePlayButtonBg
    property color _accentAnimToPlayIcon: livePlayIconColor
    property color _accentAnimToSurface: liveSurfaceColor
    property color _accentAnimToOnSurface: liveOnSurfaceColor
    property real accentBlendProgress: 1

    readonly property color musicVisualizerAccent: root.displayVisualizerAccent
    readonly property color musicPlayButtonBg: root.displayPlayButtonBg
    readonly property color musicPlayIconColor: root.displayPlayIconColor
    readonly property color musicSurfaceColor: root.displaySurfaceColor
    readonly property color musicOnSurfaceColor: root.displayOnSurfaceColor

    readonly property bool musicAccentReady: liveAccentReady || bootAccentLoaded
    property color musicOnAccent: "#E9DDFF"

    onAccentBlendProgressChanged: root._applyAccentBlend()

    function resolvePlayIconColor(playButtonBg: color, playIconColor: color): color {
        if (!playButtonBg || playButtonBg.a <= 0)
            return playIconColor && playIconColor.a > 0 ? playIconColor : Colours.on(Colours.palette.m3primary);
        return Colours.getLuminance(playButtonBg) > 0.48 ? Qt.rgba(0, 0, 0, 0.92) : Qt.rgba(1, 1, 1, 0.94);
    }

    function _blendHue(fromHue: real, toHue: real, t: real): real {
        let delta = toHue - fromHue;
        if (delta > 0.5)
            delta -= 1.0;
        else if (delta < -0.5)
            delta += 1.0;
        let hue = fromHue + delta * t;
        if (hue < 0)
            hue += 1.0;
        if (hue > 1)
            hue -= 1.0;
        return hue;
    }

    function _blendColor(from: color, to: color, t: real): color {
        if (!from || from.a <= 0)
            return to;
        if (!to || to.a <= 0)
            return from;
        return Qt.hsla(root._blendHue(from.hslHue, to.hslHue, t), from.hslSaturation + (to.hslSaturation - from.hslSaturation) * t, from.hslLightness + (to.hslLightness - from.hslLightness) * t, from.a + (to.a - from.a) * t);
    }

    function _applyAccentBlend(): void {
        const t = Math.max(0, Math.min(1, root.accentBlendProgress));
        root.displayVisualizerAccent = root._blendColor(root._accentAnimFromVisualizer, root._accentAnimToVisualizer, t);
        root.displayPlayButtonBg = root._blendColor(root._accentAnimFromPlayBg, root._accentAnimToPlayBg, t);
        root.displayPlayIconColor = root._blendColor(root._accentAnimFromPlayIcon, root._accentAnimToPlayIcon, t);
        root.displaySurfaceColor = root._blendColor(root._accentAnimFromSurface, root._accentAnimToSurface, t);
        root.displayOnSurfaceColor = root._blendColor(root._accentAnimFromOnSurface, root._accentAnimToOnSurface, t);
        root.musicOnAccent = Colours.on(root.displayVisualizerAccent);
    }

    function _animateAccentTo(visualizer: color, playButtonBg: color, playIconColor: color, surfaceColor: color, onSurfaceColor: color): void {
        accentBlendAnimation.stop();
        root._accentAnimFromVisualizer = root.displayVisualizerAccent;
        root._accentAnimFromPlayBg = root.displayPlayButtonBg;
        root._accentAnimFromPlayIcon = root.displayPlayIconColor;
        root._accentAnimFromSurface = root.displaySurfaceColor;
        root._accentAnimFromOnSurface = root.displayOnSurfaceColor;
        root._accentAnimToVisualizer = visualizer;
        root._accentAnimToPlayBg = playButtonBg;
        root._accentAnimToPlayIcon = playIconColor;
        root._accentAnimToSurface = surfaceColor;
        root._accentAnimToOnSurface = onSurfaceColor;
        root.accentBlendProgress = 0;
        root._applyAccentBlend();
        accentBlendAnimation.restart();
    }

    NumberAnimation {
        id: accentBlendAnimation
        target: root
        property: "accentBlendProgress"
        from: 0
        to: 1
        duration: Tokens.anim.durations.expressiveSlowEffects
        easing: Tokens.anim.emphasizedDecel
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
        root._animateAccentTo(root.liveVisualizerAccent, root.livePlayButtonBg, root.livePlayIconColor, root.liveSurfaceColor, root.liveOnSurfaceColor);
        root._updateMusicOnAccent();
    }

    property var _mediaAccentSession: ({})
    property int mediaAccentRevision: 0

    signal mediaAccentPrewarmed
    signal mediaAccentRefreshNeeded

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
        const nextIcon = playValid ? root.resolvePlayIconColor(nextPlay, playIconColor) : root.livePlayIconColor;

        const nextSurface = (surfaceColor && surfaceColor.a > 0) ? surfaceColor : root.liveSurfaceColor;
        const nextOnSurface = (onSurfaceColor && onSurfaceColor.a > 0) ? onSurfaceColor : root.liveOnSurfaceColor;

        const unchanged = root.liveAccentReady && root.liveVisualizerAccent === nextVis && root.livePlayButtonBg === nextPlay && root.liveSurfaceColor === nextSurface && root.liveOnSurfaceColor === nextOnSurface && root.livePlayIconColor === nextIcon;
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
        root._animateAccentTo(nextVis, nextPlay, nextIcon, nextSurface, nextOnSurface);
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
        root._animateAccentTo(root.liveVisualizerAccent, playButtonBg, nextIcon, root.liveSurfaceColor, root.liveOnSurfaceColor);
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
        root._animateAccentTo(root.liveVisualizerAccent, root.livePlayButtonBg, root.livePlayIconColor, root.liveSurfaceColor, root.liveOnSurfaceColor);
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
        const hash = JSON.stringify({
            lastArtUrl,
            lastVisualizer,
            lastPlayButtonBg
        });
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
                root._animateAccentTo(root.liveVisualizerAccent, root.livePlayButtonBg, root.livePlayIconColor, root.liveSurfaceColor, root.liveOnSurfaceColor);
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
        persistAccentProc.command = ["bash", "-lc", `mkdir -p '${dir.replace(/'/g, "'\\''")}' && printf '%s' '${escaped}' > '${root.mediaAccentPath.replace(/'/g, "'\\''")}'`];
        persistAccentProc.running = true;
    }

    function normalizeMediaArtUrl(url: string): string {
        if (!url)
            return "";
        url = root.sanitizeArtUrl(url);
        if (url.startsWith("/")) {
            try {
                url = decodeURIComponent(url);
            } catch (e) {}
            return "file://" + url;
        }
        if (url.startsWith("file://")) {
            let path = url.replace(/^file:\/\/+/, "");
            try {
                path = decodeURIComponent(path);
            } catch (e) {}
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
        const playIcon = playIconRaw ? (typeof playIconRaw === "string" ? Qt.color(playIconRaw) : playIconRaw) : null;
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
        const isLocal = norm.startsWith("file://");
        const cacheKey = isLocal ? norm + "::" + root.currentTrackKey : norm;
        // For local files: only match by exact trackKey to avoid stale colors from
        // a previous track that shared the same temp art file path.
        // For remote URLs: stable per-track so norm fallback is safe.
        const session = isLocal
            ? root._mediaAccentSession[cacheKey]
            : (root._mediaAccentSession[cacheKey] ?? root._mediaAccentSession[norm] ?? root._mediaAccentSession[artUrl]);
        if (session)
            return session;

        // Skip disk cache entirely for local files, because music players reuse generic 
        // temp paths (e.g. /tmp/chromium-mpris-art.png) across entirely different tracks.
        if (isLocal)
            return null;

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
        // Re-hydrate to memory cache
        root._mediaAccentSession[norm] = entry;
        return entry;
    }

    function storeMediaAccent(artUrl: string, visualizer: string, playButtonBg: string, playIconColor: string): void {
        if (!artUrl)
            return;
        const norm = root.normalizeMediaArtUrl(artUrl);
        const cacheKey = norm.startsWith("file://") ? norm + "::" + root.currentTrackKey : norm;
        const existing = root._mediaAccentSession[cacheKey] ?? root._mediaAccentSession[norm];
        const iconStr = playIconColor || root.resolvePlayIconColor(Qt.color(playButtonBg), null).toString();
        if (existing?.visualizer === visualizer && existing?.playButtonBg === playButtonBg && existing?.playIconColor === iconStr && accentProps.lastArtUrl === norm && accentProps.lastVisualizer === visualizer && accentProps.lastPlayButtonBg === playButtonBg)
            return;
        const entry = {
            visualizer: visualizer,
            playButtonBg: playButtonBg,
            playIconColor: iconStr
        };
        
        const isLocal = norm.startsWith("file://");
        root._mediaAccentSession[cacheKey] = entry;
        if (!isLocal) {
            root._mediaAccentSession[norm] = entry;
        }

        if (!isLocal) {
            const disk = root._readAccentDiskCache();
            disk[norm] = entry;
            const keys = Object.keys(disk);
            if (keys.length > 48) {
                for (let i = 0; i < keys.length - 48; i++)
                    delete disk[keys[i]];
            }
            accentProps.cacheJson = JSON.stringify(disk);
            root.persistAccentFile();
        }
        
        accentProps.lastArtUrl = norm;
        accentProps.lastVisualizer = entry.visualizer;
        accentProps.lastPlayButtonBg = entry.playButtonBg;
        root._bumpMediaAccentRevision();
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

    // Reactive playing state. CRITICAL: this is a property BINDING that directly
    // references the active player's reactive MPRIS properties, so QML re-evaluates it
    // whenever playbackStatus/playbackState/isPlaying change. A function call like
    // `_isPlaying(active)` does NOT track those inner properties — the binding would only
    // re-run when `active` itself changes, leaving the progress tick stuck (e.g. frozen
    // after a seek until a pause reassigns `active`). Bind tick.running to THIS instead.
    readonly property bool isPlaying: {
        const p = root.active;
        if (!p)
            return false;
        return p.playbackStatus === "Playing" || p.playbackState === 0 || p.isPlaying;
    }

    function _isPlaying(player: MprisPlayer): bool {
        if (!player)
            return false;
        return player.playbackStatus === "Playing" || player.playbackState === 0 || player.isPlaying;
    }

    function _applySyncAnchor(): void {
        if (seekGuard.running)
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
        if (root._refreshingPosition)
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
            Qt.callLater(() => {
                root._refreshingPosition = false;
                root._applySyncAnchor();
            });
        } else {
            root._applySyncAnchor();
        }
    }

    function _scheduleSyncNow(): void {
        if (root._syncNowScheduled)
            return;
        root._syncNowScheduled = true;
        Qt.callLater(() => {
            root._syncNowScheduled = false;
            root._syncNow();
        });
    }

    function _kickStartupSync(): void {
        startupSync.attempts = 0;
        if (root.active) {
            startupSync.start();
        } else {
            startupSync.stop();
        }
    }

    function _updateInterpolation(): void {
        const p = root.active;
        if (!p)
            return;

        const rawLen = p.length ?? 0;

        let currentPos = root._syncPosition;
        if (root._isPlaying(p)) {
            const elapsed = (Date.now() - root._syncTime) / 1000;
            currentPos = Math.min(root._syncPosition + elapsed, rawLen);
        }

        root.interpolatedPosition = currentPos;

        // Backup behavior: if a backend briefly reports the current position as
        // length during seek, keep the previous good length instead of collapsing
        // elapsed and total to the same timestamp.
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
        if (!p || !p.canSeek || !p.positionSupported)
            return;

        const liveLen = p.length ?? 0;
        // Prefer the last known-good length, like the backup did. Some players briefly
        // report the seek target/current position as `length`; trusting that live value
        // collapses elapsed and total to the same timestamp.
        const len = root.interpolatedLength > 0 ? root.interpolatedLength : liveLen;
        if (len <= 0)
            return;

        const targetPos = Math.max(0, Math.min(fraction * len, len));

        // Issue D-Bus command
        p.position = targetPos;

        // Immediately re-anchor local interpolation so the UI jumps instantly and the
        // 250ms tick continues advancing from the new position WHILE playing. The
        // _syncTime stamp is what makes interpolation move — without a fresh stamp the
        // bar would freeze until the next clean _syncNow.
        root._syncPosition = targetPos;
        root._syncTime = Date.now();
        root._updateInterpolation();

        // Block incoming D-Bus position echoes for a short window. Some players (Spotify)
        // are slow to process the seek and echo back their OLD position, which would nuke
        // the anchor and freeze the bar until the next state change (e.g. pause). Kept
        // short so a genuine post-seek resync lands quickly.
        seekGuard.restart();
    }

    // After the echo-block window expires, force one clean resync so the anchor locks to
    // the player's true (post-seek) position. Without this, the interpolation keeps
    // advancing from the locally-guessed anchor and can drift / appear frozen relative to
    // the real audio until the user pauses (which triggers its own resync).
    Timer {
        id: seekGuard
        interval: 1500
        repeat: false
        onTriggered: root._scheduleSyncNow()
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
            root._scheduleSyncNow();
            attempts++;
            const playing = root._isPlaying(root.active);
            const len = root.interpolatedLength > 0 ? root.interpolatedLength : (root.active.length ?? 0);
            // Backup behavior: while playing, keep retrying for a little while because
            // length can arrive before a useful position after shell/player attach.
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
        // Bind to the reactive `isPlaying` property (not the _isPlaying() function) so the
        // tick re-starts the instant playback resumes / a seek lands — see isPlaying note.
        running: root.isPlaying
        triggeredOnStart: true
        property int ticks: 0

        onRunningChanged: {
            if (running) {
                ticks = 0;
                root._scheduleSyncNow();
            }
        }

        onTriggered: {
            root._updateInterpolation();
            if (ticks % 4 === 0)
                root._scheduleSyncNow();
            ticks++;
        }
    }

    // Resync local anchors when D-Bus sends meaningful events
    Connections {
        target: root.active
        ignoreUnknownSignals: true
        function onPlaybackStatusChanged() {
            root._scheduleRecomputeActive();
            root._scheduleSyncNow();
        }
        function onPlaybackStateChanged() {
            root._scheduleRecomputeActive();
            root._scheduleSyncNow();
        }
        function onTrackTitleChanged() {
            root._scheduleSyncNow();
            root._scheduleArtPoll();
        }
        function onTrackArtistChanged() {
            root._scheduleSyncNow();
            root._scheduleArtPoll();
        }
        function onTrackAlbumChanged() {
            root._scheduleArtPoll();
        }
        function onTrackArtUrlChanged() {
            root._scheduleArtPoll();
        }
        function onLengthChanged() {
            root._scheduleSyncNow();
        }
        function onPositionChanged() {
            if (root._refreshingPosition)
                return;
            root._applySyncAnchor();
        }
    }

    function _onActivePlayerChanged(): void {
        root._scheduleSyncNow();
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
        root._scheduleSyncNow();
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

        function play(): void {
            if (root.active)
                root.active.play();
        }
        function pause(): void {
            if (root.active)
                root.active.pause();
        }
        function playPause(): void {
            root.togglePlaying();
        }
        function previous(): void {
            root.previous();
        }
        function next(): void {
            root.next();
        }
        function stop(): void {
            root.active?.stop();
        }

        target: "mpris"
    }
}
