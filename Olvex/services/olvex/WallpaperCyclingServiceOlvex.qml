pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Olvex.Config
import qs.services
import Olvex.Services

Singleton {
    id: root

    Component.onCompleted: {
        console.log("[WallpaperCyclingService] Initialized");
        refreshTimer();
    }

    property bool cyclingActive: cycleTimer.running
    readonly property bool fullscreenShowing: Hypr.focusedWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false
    readonly property bool liveWallpaperShowing: Wallpapers.isVideoPath(Wallpapers.actualCurrent)
    readonly property bool lockscreenShowing: LockState.locked
    readonly property var cyclingConfig: GlobalConfig.background?.wallpaperCycling ?? null
    readonly property bool shouldPauseCycling: liveWallpaperShowing
        || ((cyclingConfig?.pauseOnFullscreen ?? true) && fullscreenShowing)
        || ((cyclingConfig?.pauseOnLock ?? true) && lockscreenShowing)

    function cycleToNextWallpaper(current: string, monitor: string): void {
        const wallpapers = Wallpapers.staticEntryObjects;
        if (!wallpapers || wallpapers.length <= 1) return;
        
        let currentIndex = -1;
        for (let i = 0; i < wallpapers.length; i++) {
            if (wallpapers[i].path === current) {
                currentIndex = i;
                break;
            }
        }
        
        const nextIndex = (currentIndex + 1) % wallpapers.length;
        const target = wallpapers[nextIndex].path;
        
        if (monitor)
            Wallpapers.setMonitorWallpaper(monitor, target);
        else
            Wallpapers.setWallpaper(target, false);
    }


    function cycleForMonitor(screenName: string): void {
        const current = Wallpapers.getMonitorWallpaper(screenName);
        if (current)
            cycleToNextWallpaper(current, screenName);
    }

    function cycleAll(): void {
        if (shouldPauseCycling || !(cyclingConfig?.enabled ?? false))
            return;

        if (Wallpapers.perMonitorWallpaper) {
            for (const screen of Screens.screens)
                cycleForMonitor(screen.name);
            return;
        }

        cycleToNextWallpaper(Wallpapers.actualCurrent, "");
    }

    function refreshTimer(): void {
        cycleTimer.stop();
        if (!(cyclingConfig?.enabled ?? false) || shouldPauseCycling)
            return;
        cycleTimer.interval = Math.max(5, cyclingConfig?.intervalSeconds ?? 300) * 1000;
        cycleTimer.start();
    }

    onShouldPauseCyclingChanged: {
        if (shouldPauseCycling) {
            console.log("[WallpaperCyclingService] Paused cycling (Condition met)");
            cycleTimer.stop();
        } else {
            console.log("[WallpaperCyclingService] Resuming cycling (Condition cleared)");
            refreshTimer();
        }
    }

    Timer {
        id: cycleTimer

        repeat: true
        running: false
        onTriggered: root.cycleAll()
    }

    onCyclingConfigChanged: {
        console.log("[WallpaperCyclingService] Cycling config changed");
        root.refreshTimer();
    }

    Connections {
        target: root.cyclingConfig || null
        ignoreUnknownSignals: true
        function onEnabledChanged(): void {
            console.log("[WallpaperCyclingService] enabled changed:", root.cyclingConfig.enabled);
            root.refreshTimer();
        }
        function onIntervalSecondsChanged(): void {
            console.log("[WallpaperCyclingService] interval changed:", root.cyclingConfig.intervalSeconds);
            root.refreshTimer();
        }
    }

    Connections {
        target: Wallpapers
        function onActualCurrentChanged(): void {
            // Restart timer on manual wallpaper change to reset the cycle duration
            if (root.cyclingActive)
                root.refreshTimer();
        }
        function onPerMonitorWallpaperChanged(): void {
            if (root.cyclingActive)
                root.refreshTimer();
        }
    }
}
