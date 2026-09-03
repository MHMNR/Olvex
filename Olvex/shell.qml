//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_AUTO_SCREEN_SCALE_FACTOR=1
//@ pragma Env QT_ENABLE_HIGHDPI_SCALING=1
//@ pragma Env QT_SCALE_FACTOR_ROUNDING_POLICY=PassThrough
//@ pragma Env QT_LOGGING_RULES=qt.qml.propertyCache.append.warning=false;quickshell.dbus.properties.warning=false;quickshell.dbus.warning=false
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QML2_IMPORT_PATH=/home/abm/Projects/QS-Config/Github/Olvex/build/qml
//@ pragma Env QML_IMPORT_PATH=/home/abm/Projects/QS-Config/Github/Olvex/build/qml
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
import Olvex.Internal
import Quickshell
import QtQuick
import qs.utils
import qs.services

ShellRoot {
    settings.watchFiles: true
    readonly property bool _resizerInit: WindowResizer.active
    readonly property bool _cpuProfileInit: CpuProfile.enabled
    readonly property bool _accountFacesInit: AccountFaces.faces.length >= 0
    readonly property bool _hardwareButtonsInit: HardwareButtons.hasOwnProperty("objectName")
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
    UsbMonitor {}
    IdleMonitors {
        lock: lock
    }
}
