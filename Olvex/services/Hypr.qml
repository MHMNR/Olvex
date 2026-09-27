pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Olvex
import Olvex.Config
import Olvex.Internal
import qs.components.misc

Singleton {
    id: root

    readonly property var toplevels: Hyprland.toplevels
    readonly property var workspaces: Hyprland.workspaces
    readonly property var monitors: Hyprland.monitors

    readonly property HyprlandToplevel activeToplevel: {
        const t = Hyprland.activeToplevel;
        return t?.workspace?.name.startsWith("special:") || Hyprland.focusedWorkspace?.toplevels.values.length > 0 ? t : null;
    }
    readonly property HyprlandWorkspace focusedWorkspace: Hyprland.focusedWorkspace
    readonly property HyprlandMonitor focusedMonitor: Hyprland.focusedMonitor
    readonly property int activeWsId: focusedWorkspace?.id ?? 1

    readonly property HyprKeyboard keyboard: extras.devices.keyboards.find(kb => kb.main) ?? null
    readonly property bool capsLock: keyboard?.capsLock ?? false
    readonly property bool numLock: keyboard?.numLock ?? false
    readonly property string defaultKbLayout: keyboard?.layout.split(",")[0] ?? "??"
    readonly property string kbLayoutFull: keyboard?.activeKeymap ?? "Unknown"
    readonly property string kbLayout: kbMap.get(kbLayoutFull) ?? "??"
    readonly property var kbMap: new Map()

    readonly property alias extras: extras
    readonly property alias options: extras.options
    readonly property alias devices: extras.devices

    property bool hadKeyboard
    property string lastSpecialWorkspace: ""
    property int toplevelUpdateCounter: 0

    signal configReloaded

    function dispatch(request: string): void {
        const trimmed = request.trim();
        if (!trimmed)
            return;

        if (trimmed.startsWith("hl.") || trimmed.startsWith("return ")) {
            Quickshell.execDetached(["hyprctl", "dispatch", trimmed]);
            return;
        }

        const parts = trimmed.split(/\s+/);
        const cmd = parts[0].toLowerCase();
        const arg = parts.slice(1).join(" ").trim();

        let luaExpr = "";

        if (cmd === "workspace") {
            luaExpr = `hl.dsp.focus({ workspace = '${arg}' })`;
        } else if (cmd === "togglespecialworkspace") {
            const wsName = arg || "special";
            luaExpr = `hl.dsp.workspace.toggle_special('${wsName}')`;
        } else if (cmd === "focuswindow") {
            luaExpr = `hl.dsp.focus({ window = '${arg}' })`;
        } else if (cmd === "closewindow") {
            luaExpr = arg ? `hl.dsp.window.close({ window = '${arg}' })` : `hl.dsp.window.close()`;
        } else if (cmd === "killwindow") {
            luaExpr = arg ? `hl.dsp.window.kill({ window = '${arg}' })` : `hl.dsp.window.kill()`;
        } else if (cmd === "togglefloating") {
            luaExpr = arg ? `hl.dsp.window.float({ action = 'toggle', window = '${arg}' })` : `hl.dsp.window.float({ action = 'toggle' })`;
        } else if (cmd === "pin") {
            luaExpr = arg ? `hl.dsp.window.pin({ action = 'toggle', window = '${arg}' })` : `hl.dsp.window.pin({ action = 'toggle' })`;
        } else if (cmd === "dpms") {
            luaExpr = `hl.dsp.dpms('${arg}')`;
        } else if (cmd === "movetoworkspace") {
            const sub = arg.split(",");
            const targetWs = sub[0].trim();
            const targetWin = sub.length > 1 ? sub[1].trim() : "";
            luaExpr = targetWin ? `hl.dsp.window.move({ workspace = '${targetWs}', window = '${targetWin}' })` : `hl.dsp.window.move({ workspace = '${targetWs}' })`;
        } else {
            Quickshell.execDetached(["hyprctl", "dispatch"].concat(parts));
            return;
        }

        Quickshell.execDetached(["hyprctl", "dispatch", luaExpr]);
    }

    function cycleSpecialWorkspace(direction: string): void {
        const openSpecials = workspaces.values.filter(w => w.name.startsWith("special:") && w.lastIpcObject.windows > 0);

        if (openSpecials.length === 0)
            return;

        const activeSpecial = focusedMonitor.lastIpcObject.specialWorkspace.name ?? "";

        if (!activeSpecial) {
            if (lastSpecialWorkspace) {
                const workspace = workspaces.values.find(w => w.name === lastSpecialWorkspace);
                if (workspace && workspace.lastIpcObject.windows > 0) {
                    dispatch(`workspace ${lastSpecialWorkspace}`);
                    return;
                }
            }
            dispatch(`workspace ${openSpecials[0].name}`);
            return;
        }

        const currentIndex = openSpecials.findIndex(w => w.name === activeSpecial);
        let nextIndex = 0;

        if (currentIndex !== -1) {
            if (direction === "next")
                nextIndex = (currentIndex + 1) % openSpecials.length;
            else
                nextIndex = (currentIndex - 1 + openSpecials.length) % openSpecials.length;
        }

        dispatch(`workspace ${openSpecials[nextIndex].name}`);
    }

    function monitorNames(): list<string> {
        return monitors.values.map(e => e.name);
    }

    function monitorFor(screen: ShellScreen): HyprlandMonitor {
        return Hyprland.monitorFor(screen);
    }

    function isCodeEditorClass(cls: string): bool {
        return cls.length > 0 && /^(code|cursor|codium|vscodium|code-oss)$/i.test(cls);
    }

    function isCodeEditorToplevel(t: var): bool {
        if (!t)
            return false;

        const cls = t.lastIpcObject?.class || t.lastIpcObject?.appId || "";
        const title = t.lastIpcObject?.title || "";

        if (isCodeEditorClass(cls))
            return true;

        return title.length > 0 && /visual studio code|^cursor(\s|$|-)/i.test(title);
    }

    readonly property bool hasCodeEditorOpen: toplevels.values.some(t => isCodeEditorToplevel(t))

    function shouldBlockScreenCapture(): bool {
        return isCodeEditorToplevel(activeToplevel);
    }

    function canLivePreviewToplevel(t: var): bool {
        return !isCodeEditorToplevel(t);
    }

    function syncGaps(): void {
        if (typeof GameMode !== "undefined" && GameMode && GameMode.enabled)
            return;
        const gap = GlobalConfig.border.gap ?? 5;
        const rounding = Math.max(0, (GlobalConfig.border.rounding ?? 24) - gap);
        extras.applyOptions({
            "general:gaps_out": gap,
            "decoration:rounding": rounding
        });
    }

    function reloadDynamicConfs(): void {
        extras.batchMessage(["eval hl.bind('Caps_Lock', hl.dsp.global('olvex:refreshDevices'), { locked = true, non_consuming = true, ignore_mods = true })", "eval hl.bind('Num_Lock', hl.dsp.global('olvex:refreshDevices'), { locked = true, non_consuming = true, ignore_mods = true })"]);
        syncGaps();
    }

    Component.onCompleted: reloadDynamicConfs()

    Connections {
        target: GlobalConfig.border
        function onGapChanged(): void {
            root.syncGaps();
        }
        function onFloatingChanged(): void {
            root.syncGaps();
        }
        function onRoundingChanged(): void {
            root.syncGaps();
        }
        function onDrawerRoundingChanged(): void {
            root.syncGaps();
        }
    }

    onCapsLockChanged: {
        if (!GlobalConfig.qspanel.toasts.capsLockChanged)
            return;

        if (capsLock)
            Toaster.toast(qsTr("Caps lock on"), "", "keyboard_capslock_badge");
        else
            Toaster.toast(qsTr("Caps lock off"), "", "keyboard_capslock");
    }

    onNumLockChanged: {
        if (!GlobalConfig.qspanel.toasts.numLockChanged)
            return;

        if (numLock)
            Toaster.toast(qsTr("Num lock on"), "", "looks_one");
        else
            Toaster.toast(qsTr("Num lock off"), "", "timer_1");
    }

    onKbLayoutFullChanged: {
        if (hadKeyboard && GlobalConfig.qspanel.toasts.kbLayoutChanged)
            Toaster.toast(qsTr("Keyboard layout changed"), qsTr("Layout changed to: %1").arg(kbLayoutFull), "keyboard");

        hadKeyboard = !!keyboard;
    }

    Connections {
        function onRawEvent(event: HyprlandEvent): void {
            let n = event.name;
            if (n.endsWith("v2"))
                n = n.slice(0, -2);

            if (n === "configreloaded") {
                root.configReloaded();
                root.reloadDynamicConfs();
            } else if (["workspace", "moveworkspace", "activespecial", "focusedmon"].includes(n)) {
                Hyprland.refreshWorkspaces();
                Hyprland.refreshMonitors();
            } else if (["openwindow", "closewindow", "movewindow"].includes(n)) {
                Hyprland.refreshToplevels();
                Hyprland.refreshWorkspaces();
                root.toplevelUpdateCounter++;
            } else if (n.includes("mon")) {
                Hyprland.refreshMonitors();
            } else if (n.includes("workspace")) {
                Hyprland.refreshWorkspaces();
            } else if (n.includes("window") || n.includes("group") || ["pin", "fullscreen", "changefloatingmode", "minimize"].includes(n)) {
                Hyprland.refreshToplevels();
                root.toplevelUpdateCounter++;
            }
        }

        target: Hyprland
    }

    Connections {
        function onLastIpcObjectChanged(): void {
            const specialName = root.focusedMonitor.lastIpcObject.specialWorkspace.name;

            if (specialName && specialName.startsWith("special:")) {
                root.lastSpecialWorkspace = specialName;
            }
        }

        target: root.focusedMonitor
    }

    FileView {
        id: kbLayoutFile

        path: Quickshell.env("OLVEX_XKB_RULES_PATH") || "/usr/share/X11/xkb/rules/base.lst"
        onLoaded: {
            const layoutMatch = text().match(/! layout\n([\s\S]*?)\n\n/);
            if (layoutMatch) {
                const lines = layoutMatch[1].split("\n");
                for (const line of lines) {
                    if (!line.trim() || line.trim().startsWith("!"))
                        continue;

                    const match = line.match(/^\s*([a-z]{2,})\s+([a-zA-Z() ]+)$/);
                    if (match)
                        root.kbMap.set(match[2], match[1]);
                }
            }

            const variantMatch = text().match(/! variant\n([\s\S]*?)\n\n/);
            if (variantMatch) {
                const lines = variantMatch[1].split("\n");
                for (const line of lines) {
                    if (!line.trim() || line.trim().startsWith("!"))
                        continue;

                    const match = line.match(/^\s*([a-zA-Z0-9_-]+)\s+([a-z]{2,}): (.+)$/);
                    if (match)
                        root.kbMap.set(match[3], match[2]);
                }
            }
        }
    }

    IpcHandler {
        function refreshDevices(): void {
            extras.refreshDevices();
        }

        function cycleSpecialWorkspace(direction: string): void {
            root.cycleSpecialWorkspace(direction);
        }

        function listSpecialWorkspaces(): string {
            return root.workspaces.values.filter(w => w.name.startsWith("special:") && w.lastIpcObject.windows > 0).map(w => w.name).join("\n");
        }

        target: "hypr"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "refreshDevices"
        description: "Reload devices"
        onPressed: extras.refreshDevices()
        onReleased: extras.refreshDevices()
    }

    HyprExtras {
        id: extras
    }
}
