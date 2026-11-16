pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool locked: false
    property bool unlocking: false
    property bool lockClockVisible: false
    property int liveWallpaperPosition: 0

    onLockedChanged: {
        if (!locked)
            lockClockVisible = false;
    }

    // Screen name -> { x, y, width, height, visible } of DesktopClock for smooth Lock/Unlock morph
    property var desktopClockRects: ({})
    property var desktopClockColors: ({})
    property var lastDesktopClockColors: null

    function setDesktopClockRect(screenName, rect) {
        if (!screenName)
            return;
        const next = Object.assign({}, desktopClockRects);
        next[screenName] = rect;
        desktopClockRects = next;
    }

    function getDesktopClockRect(screenName) {
        if (!screenName)
            return null;
        return desktopClockRects[screenName] ?? null;
    }

    function setDesktopClockColors(screenName, colors) {
        if (!screenName || !colors)
            return;
        const next = Object.assign({}, desktopClockColors);
        next[screenName] = colors;
        desktopClockColors = next;
        lastDesktopClockColors = colors;
    }

    function getDesktopClockColors(screenName) {
        if (screenName && desktopClockColors[screenName])
            return desktopClockColors[screenName];
        return lastDesktopClockColors;
    }
}
