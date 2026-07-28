import QtQuick
import Quickshell
import Quickshell.Io
import Olvex
import Olvex.Config
import qs.components.misc
import qs.services
import qs.modules.controlcenter

Scope {
    id: root

    readonly property bool hasFullscreen: Hypr.focusedWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false
    property bool launcherKeyPressed: false
    property var lastPressed: ({})

    function shouldTrigger(name: string): bool {
        if (name === "launcherInterrupt") return true;
        const now = Date.now();
        const last = lastPressed[name] || 0;
        if (now - last < 150) return false;
        lastPressed[name] = now;
        return true;
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "controlCenter"
        description: "Open control center"
        onPressed: {
            if (!root.shouldTrigger("controlCenter")) return;
            WindowFactory.create();
            Visibilities.launcherInterrupted = true;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "showall"
        description: "Toggle launcher, dashboard and osd"
        onPressed: {
            if (!root.shouldTrigger("showall")) return;
            if (root.hasFullscreen)
                return;
            const v = Visibilities.getForActive();
            v.launcher = v.dashboard = v.osd = v.utilities = !(v.launcher || v.dashboard || v.osd || v.utilities);
            Visibilities.launcherInterrupted = true;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "dashboard"
        description: "Toggle dashboard"
        onPressed: {
            if (!root.shouldTrigger("dashboard")) return;
            if (root.hasFullscreen)
                return;
            const visibilities = Visibilities.getForActive();
            visibilities.dashboard = !visibilities.dashboard;
            Visibilities.launcherInterrupted = true;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "session"
        description: "Toggle session menu"
        onPressed: {
            if (!root.shouldTrigger("session")) return;
            if (root.hasFullscreen)
                return;
            const visibilities = Visibilities.getForActive();
            visibilities.session = !visibilities.session;
            Visibilities.launcherInterrupted = true;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "launcher"
        description: "Toggle launcher"
        onPressed: {
            if (!root.shouldTrigger("launcher")) return;
            if (!root.launcherKeyPressed) {
                Visibilities.launcherInterrupted = false;
                root.launcherKeyPressed = true;
            }
        }
        onReleased: {
            if (root.launcherKeyPressed) {
                Qt.callLater(() => {
                    if (!Visibilities.launcherInterrupted && !root.hasFullscreen) {
                        const visibilities = Visibilities.getForActive();
                        visibilities.launcher = !visibilities.launcher;
                    }
                    Visibilities.launcherInterrupted = false;
                    root.launcherKeyPressed = false;
                });
            }
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "launcherInterrupt"
        description: "Interrupt launcher keybind"
        onPressed: {
            if (!root.shouldTrigger("launcherInterrupt")) return;
            Visibilities.launcherInterrupted = true;
        }
    }


    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "utilities"
        description: "Toggle utilities"
        onPressed: {
            if (!root.shouldTrigger("utilities")) return;
            if (root.hasFullscreen)
                return;
            const visibilities = Visibilities.getForActive();
            visibilities.utilities = !visibilities.utilities;
            Visibilities.launcherInterrupted = true;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "screenshotRegion"
        description: "Take a region screenshot"
        onPressed: {
            if (!root.shouldTrigger("screenshotRegion")) return;
            Quickshell.execDetached(["olvex", "shell", "picker", "openClip"]);
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "bottomPanel"
        description: "Toggle bottom panel"
        onPressed: {
            if (!root.shouldTrigger("bottomPanel")) return;
            if (root.hasFullscreen)
                return;
            const visibilities = Visibilities.getForActive();
            visibilities.bottomPanel = !visibilities.bottomPanel;
            Visibilities.launcherInterrupted = true;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "wallpapers"
        description: "Open wallpaper selector"
        onPressed: {
            if (!root.shouldTrigger("wallpapers")) return;
            if (root.hasFullscreen)
                return;
            const visibilities = Visibilities.getForActive();
            visibilities.wallpaperLauncher = true;
            visibilities.launcher = true;
            Visibilities.launcherInterrupted = true;
        }
    }

    IpcHandler {
        function toggle(drawer: string): void {
            if (list().split("\n").includes(drawer)) {
                if (root.hasFullscreen && ["launcher", "session", "dashboard"].includes(drawer))
                    return;
                const visibilities = Visibilities.getForActive();
                visibilities[drawer] = !visibilities[drawer];
            } else {
                console.warn(lc, `Drawer "${drawer}" does not exist`);
            }
        }

        function list(): string {
            const visibilities = Visibilities.getForActive();
            return Object.keys(visibilities).filter(k => typeof visibilities[k] === "boolean").join("\n");
        }

        function openWallpapers(): void {
            const visibilities = Visibilities.getForActive();
            visibilities.launcherSearchText = `${Config.launcher.actionPrefix}wallpaper `;
            visibilities.launcher = true;
        }

        target: "drawers"
    }

    IpcHandler {
        function open(): void {
            WindowFactory.create();
        }

        target: "controlCenter"
    }

    IpcHandler {
        function info(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Info);
        }

        function success(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Success);
        }

        function warn(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Warning);
        }

        function error(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Error);
        }

        target: "toaster"
    }

    LoggingCategory {
        id: lc

        name: "olvex.qml.shortcuts"
        defaultLogLevel: LoggingCategory.Info
    }
}
