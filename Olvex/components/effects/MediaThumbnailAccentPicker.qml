import QtQuick
import Olvex
import Olvex.Config
import qs.services
import qs.utils

Item {
    id: root

    property string artUrl: Players.currentArtUrl
    property string trackKey: Players.currentTrackKey

    readonly property bool hasArt: Players.active !== null && !!Players.currentArtUrl
    readonly property bool accentReady: Players.musicAccentReady
    readonly property color dominantSeed: Players.dominantSeed
    readonly property color visualizerAccent: Players.musicVisualizerAccent
    readonly property color playButtonBg: Players.musicPlayButtonBg
    readonly property color playIconColor: Players.musicPlayIconColor
    readonly property color surfaceColor: Players.musicSurfaceColor
    readonly property color onSurfaceColor: Players.musicOnSurfaceColor

    signal accentColorsChanged

    function syncSystemDefaults() {
        Players.recomputeThemeAccents();
    }

    function recomputeThemeColors() {
        Players.recomputeThemeAccents();
    }

    function applySystemFallback() {
        Players.clearLiveAccent();
    }

    function publishAccent(url) {
        Players.recomputeThemeAccents();
    }

    function setArtUrl(url) {
        // Handled centrally in Players singleton
    }

    function scheduleAnalysis() {
        Players.requestMediaAccentRefresh();
    }

    Connections {
        target: Players
        function onMusicPlayButtonBgChanged() {
            root.accentColorsChanged();
        }
        function onMusicVisualizerAccentChanged() {
            root.accentColorsChanged();
        }
        function onMusicSurfaceColorChanged() {
            root.accentColorsChanged();
        }
    }
}
