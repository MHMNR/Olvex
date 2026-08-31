pragma Singleton

import Quickshell
import QtQuick
import QtCore as QC
import qs.components
import qs.services

Singleton {
    property var screens: new Map()
    property var bars: new Map()
    property bool launcherInterrupted: false
    property bool shellMotionActive: false
    property bool areaPickerActive: false

    property bool bottomPanelDockBackground: bpSettings.dockBackground

    QC.Settings {
        id: bpSettings
        category: "BottomPanel"
        property bool dockBackground: true
    }

    function setBottomPanelDockBackground(val) {
        bpSettings.dockBackground = val;
        bottomPanelDockBackground = val;
    }

    function pulseShellMotion(duration) {
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

    function load(screen, visibilities) {
        screens.set(Hypr.monitorFor(screen), visibilities);
    }

    function getForActive() {
        return screens.get(Hypr.focusedMonitor);
    }
}
