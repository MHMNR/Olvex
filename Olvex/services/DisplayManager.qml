pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Olvex.Config
import qs.services

Singleton {
    id: root

    // ── Observable properties ───────────────────────────────────────────────
    property var monitors: []
    property var workspaces: []
    property var profiles: []
    property string activeProfileName: ""
    property bool useDescription: false

    // Safety test apply state
    property bool safetyActive: false
    property int safetySecondsRemaining: 10
    property string safetySnapshot: ""
    property var safetyDraftMonitors: []
    property var safetyDraftWorkspaces: []
    property bool safetyDraftUseDesc: false

    // Identify overlay state
    property bool identifyActive: false

    // Status / Loading
    property bool isLoading: false
    property string lastError: ""

    // Signals
    signal safetyTick(int seconds)
    signal safetyConfirmed()
    signal safetyReverted()
    signal configurationSaved()

    // ── Process helpers ─────────────────────────────────────────────────────
    Process {
        id: queryProc
        command: ["hyprctl", "-j", "monitors", "all"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const raw = JSON.parse(text);
                    if (Array.isArray(raw)) {
                        root.parseMonitors(raw);
                    }
                } catch (e) {
                    console.warn("[DisplayManager] Error parsing monitors:", e);
                }
                root.isLoading = false;
            }
        }
    }

    Process {
        id: wsProc
        command: ["hyprctl", "-j", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const raw = JSON.parse(text);
                    if (Array.isArray(raw)) {
                        root.workspaces = raw;
                    }
                } catch (e) {
                    console.warn("[DisplayManager] Error parsing workspaces:", e);
                }
            }
        }
    }

    Process {
        id: cmdExecProc
    }

    Timer {
        id: safetyTimer
        interval: 1000
        repeat: true
        running: root.safetyActive
        onTriggered: {
            root.safetySecondsRemaining -= 1;
            root.safetyTick(root.safetySecondsRemaining);
            if (root.safetySecondsRemaining <= 0) {
                root.revertSafetyApply();
            }
        }
    }

    Timer {
        id: identifyTimer
        interval: 3500
        repeat: false
        onTriggered: {
            root.identifyActive = false;
        }
    }

    Timer {
        id: autoRefreshTimer
        interval: 3000
        repeat: true
        running: true
        onTriggered: {
            if (!root.safetyActive) {
                root.refresh();
            }
        }
    }

    Component.onCompleted: {
        root.refresh();
        root.loadProfiles();
    }

    // ── Core Methods ────────────────────────────────────────────────────────
    function refresh() {
        if (queryProc.running) return;
        queryProc.running = true;
        if (!wsProc.running) wsProc.running = true;
    }

    function parseMonitors(rawList) {
        const list = [];
        for (let i = 0; i < rawList.length; i++) {
            const m = rawList[i];
            const w = m.width || 1920;
            const h = m.height || 1080;
            const s = m.scale || 1.0;
            const t = m.transform || 0;
            const isRotated = (t === 1 || t === 3 || t === 5 || t === 7);
            const lw = Math.round((isRotated ? h : w) / s);
            const lh = Math.round((isRotated ? w : h) / s);

            list.push({
                id: m.id ?? i,
                name: m.name || ("Output-" + i),
                description: m.description || "",
                make: m.make || "",
                model: m.model || "",
                serial: m.serial || "",
                width: w,
                height: h,
                physicalWidth: m.physicalWidth || 0,
                physicalHeight: m.physicalHeight || 0,
                refreshRate: m.refreshRate ? Number(m.refreshRate.toFixed(2)) : 60.0,
                x: m.x || 0,
                y: m.y || 0,
                scale: s,
                transform: t,
                focused: !!m.focused,
                dpmsStatus: m.dpmsStatus !== undefined ? !!m.dpmsStatus : true,
                vrr: typeof m.vrr === "number" ? m.vrr : (m.vrr ? 1 : 0),
                disabled: !!m.disabled,
                mirrorOf: (m.mirrorOf && m.mirrorOf !== "none") ? m.mirrorOf : "",
                availableModes: Array.isArray(m.availableModes) ? m.availableModes : [],
                colorManagementPreset: m.colorManagementPreset || "srgb",
                sdrBrightness: m.sdrBrightness !== undefined ? Number(m.sdrBrightness) : 1.0,
                sdrSaturation: m.sdrSaturation !== undefined ? Number(m.sdrSaturation) : 1.0,
                tenBit: m.currentFormat ? m.currentFormat.includes("10") : false,
                logicalWidth: lw,
                logicalHeight: lh,
                customMode: false
            });
        }
        root.monitors = list;
    }

    function deepCopyMonitors(list) {
        return JSON.parse(JSON.stringify(list || root.monitors));
    }

    // ── Live Apply via Hyprland IPC ─────────────────────────────────────────
    function formatMonitorLua(m, useDesc) {
        const outName = (useDesc && m.description) ? ("desc:" + m.description) : m.name;
        if (m.disabled) {
            return `hl.monitor({ output = '${outName}', mode = 'disable' })`;
        }

        const modeStr = `${m.width}x${m.height}@${m.refreshRate}`;
        const posStr = `${Math.round(m.x)}x${Math.round(m.y)}`;
        const scaleVal = Number(m.scale) || 1.0;
        const transformVal = parseInt(m.transform) || 0;
        const vrrVal = parseInt(m.vrr) || 0;
        const mirrorStr = m.mirrorOf ? m.mirrorOf : "none";

        let lua = `hl.monitor({\n` +
                  `    output = '${outName}',\n` +
                  `    mode = '${modeStr}',\n` +
                  `    position = '${posStr}',\n` +
                  `    scale = ${scaleVal},\n` +
                  `    transform = ${transformVal},\n` +
                  `    vrr = ${vrrVal}`;

        if (mirrorStr !== "none" && mirrorStr !== "") {
            lua += `,\n    mirror = '${mirrorStr}'`;
        }
        if (m.scaleFilter) {
            lua += `,\n    scale_filter = '${m.scaleFilter}'`;
        }
        if (m.colorManagementPreset && m.colorManagementPreset !== "srgb") {
            lua += `,\n    cm = '${m.colorManagementPreset}'`;
        }
        lua += `\n})`;
        return lua;
    }

    function formatMonitorConf(m, useDesc) {
        const outName = (useDesc && m.description) ? ("desc:" + m.description) : m.name;
        if (m.disabled) {
            return `monitor = ${outName}, disable`;
        }
        const modeStr = `${m.width}x${m.height}@${m.refreshRate}`;
        const posStr = `${Math.round(m.x)}x${Math.round(m.y)}`;
        const scaleVal = Number(m.scale) || 1.0;
        const transformVal = parseInt(m.transform) || 0;
        const vrrVal = parseInt(m.vrr) || 0;
        const mirrorStr = m.mirrorOf ? m.mirrorOf : "";

        let line = `monitor = ${outName}, ${modeStr}, ${posStr}, ${scaleVal}`;
        if (mirrorStr) {
            line += `, mirror, ${mirrorStr}`;
        } else {
            if (transformVal > 0) line += `, transform, ${transformVal}`;
            if (vrrVal > 0) line += `, vrr, ${vrrVal}`;
        }
        if (m.colorManagementPreset && m.colorManagementPreset !== "srgb") {
            line += `, cm, ${m.colorManagementPreset}`;
        }
        if (m.scaleFilter) {
            line += `, scale_filter, ${m.scaleFilter}`;
        }
        return line;
    }

    function applyLive(monitorsList, workspacesList, useDesc) {
        const list = monitorsList || root.monitors;
        let script = "";
        for (let i = 0; i < list.length; i++) {
            const luaCmd = root.formatMonitorLua(list[i], useDesc);
            script += `hyprctl eval "${luaCmd.replace(/"/g, '\\"')}"\n`;
            
            // DPMS dispatch
            const dpmsState = list[i].dpmsStatus ? "on" : "off";
            script += `hyprctl dispatch dpms ${dpmsState} "${list[i].name}"\n`;
        }
        if (workspacesList && Array.isArray(workspacesList)) {
            for (let j = 0; j < workspacesList.length; j++) {
                const ws = workspacesList[j];
                if (ws.workspace && ws.monitor) {
                    const wsLua = `hl.workspace_rule({ workspace = '${ws.workspace}', monitor = '${ws.monitor}'${ws.isDefault ? ", default = true" : ""} })`;
                    script += `hyprctl eval "${wsLua.replace(/"/g, '\\"')}"\n`;
                }
            }
        }

        Quickshell.execDetached(["bash", "-c", script]);
    }

    // ── Safety Apply with 10-second countdown ──────────────────────────────
    function startSafetyApply(draftMonitors, draftWorkspaces, useDesc) {
        root.safetySnapshot = JSON.stringify(root.monitors);
        root.safetyDraftMonitors = draftMonitors;
        root.safetyDraftWorkspaces = draftWorkspaces;
        root.safetyDraftUseDesc = useDesc;
        root.safetySecondsRemaining = 10;
        root.safetyActive = true;

        root.applyLive(draftMonitors, draftWorkspaces, useDesc);
    }

    function confirmSafetyApply() {
        if (!root.safetyActive) return;
        root.safetyActive = false;
        safetyTimer.stop();

        root.saveConfiguration(root.safetyDraftMonitors, root.safetyDraftWorkspaces, root.safetyDraftUseDesc);
        root.monitors = root.safetyDraftMonitors;
        root.safetyConfirmed();
    }

    function revertSafetyApply() {
        root.safetyActive = false;
        safetyTimer.stop();

        if (root.safetySnapshot) {
            try {
                const prev = JSON.parse(root.safetySnapshot);
                root.applyLive(prev, null, root.useDescription);
                root.monitors = prev;
            } catch (e) {
                console.warn("[DisplayManager] Failed to revert snapshot:", e);
            }
        }
        root.safetyReverted();
    }

    // ── Persistent Saving to ~/.config/hypr/ ─────────────────────────────────
    function saveConfiguration(monitorsList, workspacesList, useDesc) {
        const list = monitorsList || root.monitors;
        const now = new Date();
        const dateStr = now.toISOString().replace("T", " ").split(".")[0];

        // 1. Generate ~/.config/hypr/monitors.lua
        let luaContent = `-- Generated by Olvex Display Manager on ${dateStr}. Do not edit manually.\n\n`;
        for (let i = 0; i < list.length; i++) {
            luaContent += root.formatMonitorLua(list[i], useDesc) + "\n\n";
        }

        // 2. Generate ~/.config/hypr/monitors.conf
        let confContent = `# Generated by Olvex Display Manager on ${dateStr}. Do not edit manually.\n`;
        for (let j = 0; j < list.length; j++) {
            confContent += root.formatMonitorConf(list[j], useDesc) + "\n";
        }

        // 3. Generate workspace bindings if present
        let wsConfContent = `# Generated by Olvex Display Manager on ${dateStr}.\n`;
        if (workspacesList && Array.isArray(workspacesList)) {
            for (let k = 0; k < workspacesList.length; k++) {
                const w = workspacesList[k];
                if (w.workspace && w.monitor) {
                    wsConfContent += `workspace = ${w.workspace}, monitor:${w.monitor}${w.isDefault ? ", default:true" : ""}\n`;
                }
            }
        }

        // Write files using a bash script
        const script = `
mkdir -p "$HOME/.config/hypr"
cat << 'EOF' > "$HOME/.config/hypr/monitors.lua"
${luaContent}EOF

cat << 'EOF' > "$HOME/.config/hypr/monitors.conf"
${confContent}EOF

cat << 'EOF' > "$HOME/.config/hypr/workspaces.conf"
${wsConfContent}EOF
`;
        Quickshell.execDetached(["bash", "-c", script]);
        root.configurationSaved();
    }

    // ── Snapping Algorithm (1:1 with nwg-displays logic) ────────────────────
    function calculateSnap(draggingItem, newX, newY, allMonitors, snapThreshold) {
        const threshold = snapThreshold || 24;
        let snapX = newX;
        let snapY = newY;

        const dw = draggingItem.logicalWidth;
        const dh = draggingItem.logicalHeight;

        const snapLinesX = [0];
        const snapLinesY = [0];

        for (let i = 0; i < allMonitors.length; i++) {
            const m = allMonitors[i];
            if (m.name === draggingItem.name) continue;

            const mx = m.x;
            const my = m.y;
            const mw = m.logicalWidth;
            const mh = m.logicalHeight;

            // X points: left edge, right edge
            if (!snapLinesX.includes(mx)) snapLinesX.push(mx);
            if (!snapLinesX.includes(mx + mw)) snapLinesX.push(mx + mw);

            // Y points: top edge, bottom edge
            if (!snapLinesY.includes(my)) snapLinesY.push(my);
            if (!snapLinesY.includes(my + mh)) snapLinesY.push(my + mh);
        }

        // Test Horizontal Snapping (Left edge to line, Right edge to line)
        let bestDistX = threshold + 1;
        for (let xi = 0; xi < snapLinesX.length; xi++) {
            const line = snapLinesX[xi];
            // Snap left edge
            const distLeft = Math.abs(newX - line);
            if (distLeft < bestDistX) {
                bestDistX = distLeft;
                snapX = line;
            }
            // Snap right edge
            const distRight = Math.abs(newX + dw - line);
            if (distRight < bestDistX) {
                bestDistX = distRight;
                snapX = line - dw;
            }
        }

        // Test Vertical Snapping (Top edge to line, Bottom edge to line)
        let bestDistY = threshold + 1;
        for (let yi = 0; yi < snapLinesY.length; yi++) {
            const line = snapLinesY[yi];
            // Snap top edge
            const distTop = Math.abs(newY - line);
            if (distTop < bestDistY) {
                bestDistY = distTop;
                snapY = line;
            }
            // Snap bottom edge
            const distBottom = Math.abs(newY + dh - line);
            if (distBottom < bestDistY) {
                bestDistY = distBottom;
                snapY = line - dh;
            }
        }

        return {
            x: Math.round(snapX),
            y: Math.round(snapY),
            snappedX: bestDistX <= threshold,
            snappedY: bestDistY <= threshold
        };
    }

    // ── Identify Displays Overlay ───────────────────────────────────────────
    function identifyDisplays() {
        root.identifyActive = true;
        identifyTimer.restart();
    }

    Process {
        id: loadProfilesProc
        command: ["cat", `${Quickshell.env("HOME")}/.config/olvex/display-profiles.json`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    if (Array.isArray(parsed)) {
                        root.profiles = parsed;
                    }
                } catch (e) {
                    root.profiles = [];
                }
            }
        }
    }

    function loadProfiles() {
        if (!loadProfilesProc.running) loadProfilesProc.running = true;
    }

    function saveProfile(name, draftMonitors, draftWorkspaces, useDesc) {
        if (!name || !name.trim()) return;
        const cleanName = name.trim();
        const profilesList = root.profiles.slice();
        const existingIdx = profilesList.findIndex(p => p.name === cleanName);

        const newProfile = {
            name: cleanName,
            updatedAt: new Date().toISOString(),
            useDescription: !!useDesc,
            monitors: draftMonitors || root.monitors,
            workspaces: draftWorkspaces || []
        };

        if (existingIdx >= 0) {
            profilesList[existingIdx] = newProfile;
        } else {
            profilesList.push(newProfile);
        }

        root.profiles = profilesList;
        root.activeProfileName = cleanName;

        const jsonStr = JSON.stringify(profilesList, null, 2);
        const script = `
mkdir -p "$HOME/.config/olvex"
cat << 'EOF' > "$HOME/.config/olvex/display-profiles.json"
${jsonStr}
EOF
`;
        Quickshell.execDetached(["bash", "-c", script]);
    }

    function deleteProfile(name) {
        const profilesList = root.profiles.filter(p => p.name !== name);
        root.profiles = profilesList;
        if (root.activeProfileName === name) {
            root.activeProfileName = "";
        }
        const jsonStr = JSON.stringify(profilesList, null, 2);
        const script = `
mkdir -p "$HOME/.config/olvex"
cat << 'EOF' > "$HOME/.config/olvex/display-profiles.json"
${jsonStr}
EOF
`;
        Quickshell.execDetached(["bash", "-c", script]);
    }

    function applyProfile(profileObj) {
        if (!profileObj || !Array.isArray(profileObj.monitors)) return;
        root.activeProfileName = profileObj.name || "";
        root.applyLive(profileObj.monitors, profileObj.workspaces, profileObj.useDescription);
        root.saveConfiguration(profileObj.monitors, profileObj.workspaces, profileObj.useDescription);
        root.monitors = profileObj.monitors;
    }
}
