pragma Singleton

import Quickshell
import QtQuick
import qs.components
import qs.services

Singleton {
    property var screens: new Map()
    property var bars: new Map()
    property bool launcherInterrupted: false
    property bool shellMotionActive: false
    property bool areaPickerActive: false

    function pulseShellMotion(duration: int): void {
        const hold = duration || 520;
        shellMotionActive = true;
        shellMotionTimer.interval = Math.max(shellMotionTimer.interval, hold);
        shellMotionTimer.restart();
    }

    Timer {
        id: shellMotionTimer
        interval: 520
        repeat: false
        onTriggered: shellMotionActive = false
    }

    function load(screen: ShellScreen, visibilities: DrawerVisibilities): void {
        screens.set(Hypr.monitorFor(screen), visibilities);
    }

    function getForActive(): DrawerVisibilities {
        return screens.get(Hypr.focusedMonitor);
    }
}
