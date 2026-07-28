//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QML2_IMPORT_PATH=/home/abm/Projects/QS-Config/Olvex/build/qml
//@ pragma Env QML_IMPORT_PATH=/home/abm/Projects/QS-Config/Olvex/build/qml
//@ pragma Env QT_FFMPEG_DECODING_HW_DEVICE_TYPES=cuda
// Dev-only debug (enable with OLVEX_DEV=1 when launching qs):
// QML_IMPORT_TRACE=1, QT_DEBUG_PLUGINS=1, QML_DEBUG=1,
// QT_LOGGING_RULES=*.debug=true;qml.debug=true;quickshell.*.debug=true

import "modules"
import "modules/drawers"
import "modules/background"
import "modules/areapicker"
import "modules/lock"
import "modules/olvex" as Olvex
import Quickshell
import QtQuick
import qs.utils

ShellRoot {
    settings.watchFiles: Quickshell.env("OLVEX_DEV") === "1"
    readonly property bool _cpuProfileInit: CpuProfile.enabled
    readonly property bool _initApps: {
        Qt.application.name = "Olvex";
        Qt.application.organization = "Olvex";
        return true;
    }
    readonly property bool olvexWallpaperCyclingActive: Olvex.WallpaperCyclingServiceOlvex.cyclingActive

    Background { id: bg }
    Drawers {}
    AreaPicker {}
    Lock {
        id: lock
    }

    ConfigToasts {}
    Shortcuts {}
    BatteryMonitor {}
    IdleMonitors {
        lock: lock
    }
}