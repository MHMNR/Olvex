pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Olvex.Config

Singleton {
    id: root

    // CPU properties
    property string cpuName: ""
    property real cpuPerc
    property real cpuTemp

    // GPU properties
    readonly property string gpuType: GlobalConfig.services.gpuType.toUpperCase() || autoGpuType
    readonly property bool explicitGpuType: GlobalConfig.services.gpuType !== ""
    property string autoGpuType: "NONE"
    property string gpuName: ""
    property real gpuPerc
    property real gpuTemp

    // Per-GPU: { id, name, label, perc, temp }
    property var gpus: []

    // Memory properties
    property real memUsed
    property real memTotal
    readonly property real memPerc: memTotal > 0 ? memUsed / memTotal : 0

    // Storage properties (aggregated)
    readonly property real storagePerc: {
        let totalUsed = 0;
        let totalSize = 0;
        for (const disk of disks) {
            totalUsed += disk.used;
            totalSize += disk.total;
        }
        return totalSize > 0 ? totalUsed / totalSize : 0;
    }

    // Individual disks: Array of { mount, label, used, total, free, perc, hasRoot }
    property var disks: []

    property real lastCpuIdle
    property real lastCpuTotal

    property int refCount

    function cleanCpuName(name: string): string {
        return name.replace(/\(R\)|\(TM\)|CPU|\d+(?:th|nd|rd|st) Gen |Core |Processor/gi, "").replace(/\s+/g, " ").trim();
    }

    function cleanGpuName(name: string): string {
        return name.replace(/\(R\)|\(TM\)|\(rev [^)]+\)/gi, "").replace(/\s+/g, " ").trim();
    }

    function isAmdIntegratedGpu(rawName, source) {
        const raw = rawName.toLowerCase();
        return /renoir|radeon vega series|radeon vega mobile|cezanne|phoenix|barcelo|rembrandt|raphael|granite ridge|ryzen.*graphics/.test(raw)
                || (source === "drm" && /\[amd\/ati\].*renoir/.test(raw));
    }

    function gpuShortLabel(rawName, index, source) {
        if (source === undefined)
            source = "";
        const raw = rawName.trim();
        const cleaned = cleanGpuName(raw);

        if (!cleaned && !raw)
            return "GPU " + index;

        if (/nvidia|geforce|rtx|gtx|quadro/i.test(raw + " " + cleaned))
            return cleaned || raw;

        if (isAmdIntegratedGpu(raw, source))
            return "Radeon Graphics";

        if (/intel.*(uhd|iris|xe graphics|hd graphics)/i.test(raw)) {
            const intel = raw.match(/Intel[^(\[]+/i);
            return intel ? intel[0].trim() : "Intel Graphics";
        }

        if (!cleaned)
            return "GPU " + index;

        const bracket = cleaned.match(/\[([^\]]+)\]/);
        if (bracket) {
            const inner = bracket[1].replace(/^AMD\/ATI\s*/i, "").trim();
            if (inner && !/^AMD/i.test(inner))
                return inner.split("/")[0].trim();
        }

        const short = cleaned
            .replace(/^AMD\s+/i, "")
            .replace(/^Advanced Micro Devices, Inc\.?\s*/i, "")
            .replace(/\s*Series$/i, "")
            .trim();

        return short !== "" ? short : ("GPU " + index);
    }

    function syncLegacyGpu() {
        if (gpus.length === 0) {
            gpuPerc = 0;
            gpuTemp = 0;
            return;
        }

        const sum = gpus.reduce((acc, gpu) => acc + gpu.perc, 0);
        gpuPerc = sum / gpus.length;
        gpuTemp = gpus[0].temp;
        if (gpus[0].name)
            gpuName = gpus[0].name;
    }

    function mergeGpuTemps(adapterTemps: var) {
        if (gpus.length === 0 || adapterTemps.length === 0)
            return;

        let adapterIdx = 0;
        const merged = gpus.map(gpu => {
            if (gpu.source === "nvidia")
                return gpu;

            const temp = adapterTemps[adapterIdx] ?? gpu.temp ?? 0;
            adapterIdx++;
            return {
                id: gpu.id,
                name: gpu.name,
                label: gpu.label,
                perc: gpu.perc,
                temp: temp,
                source: gpu.source
            };
        });

        gpus = merged;
        syncLegacyGpu();
    }

    readonly property string nvidiaGpuScanSh: "nvidia-smi --query-gpu=index,name,utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | while IFS= read -r line; do [ -z \"$line\" ] && continue; idx=$(echo \"$line\" | cut -d, -f1 | tr -d ' '); name=$(echo \"$line\" | cut -d, -f2 | sed 's/^ *//'); perc=$(echo \"$line\" | cut -d, -f3 | tr -d ' '); temp=$(echo \"$line\" | cut -d, -f4 | tr -d ' '); echo \"nvidia|$idx|$name|$perc|$temp\"; done"

    readonly property string drmGpuScanSh: "for card in /sys/class/drm/card[0-9]; do dev=\"$card/device\"; [ -f \"$dev/gpu_busy_percent\" ] || continue; idx=${card##*card}; name=$(cat \"$dev/name\" 2>/dev/null); if [ -z \"$name\" ]; then slot=$(grep -m1 \"^PCI_SLOT_NAME=\" \"$dev/uevent\" 2>/dev/null | cut -d= -f2); if [ -n \"$slot\" ] && command -v lspci >/dev/null; then name=$(lspci -s \"$slot\" 2>/dev/null | sed 's/.*: //'); fi; fi; [ -z \"$name\" ] && name=GPU; perc=$(cat \"$dev/gpu_busy_percent\"); temp=0; for h in \"$dev\"/hwmon/hwmon*/temp*_input; do [ -f \"$h\" ] || continue; t=$(cat \"$h\" 2>/dev/null); [ -n \"$t\" ] && temp=$((t/1000)) && break; done; echo \"drm|$idx|$name|$perc|$temp\"; done"

    readonly property string hybridGpuScanSh: nvidiaGpuScanSh + "; " + drmGpuScanSh

    function gpuQueryCommand(): var {
        if (gpuType === "GENERIC")
            return ["sh", "-c", drmGpuScanSh];
        if (gpuType === "NVIDIA" && explicitGpuType)
            return ["sh", "-c", nvidiaGpuScanSh];
        return ["sh", "-c", hybridGpuScanSh];
    }

    function parseGpuStdout(output: string): void {
        const list = [];

        for (const line of output.trim().split("\n")) {
            if (!line)
                continue;

            const parts = line.split("|");
            if (parts.length < 5)
                continue;

            const source = parts[0];
            const id = parseInt(parts[1], 10);
            const rawName = parts[2];
            const name = cleanGpuName(rawName);
            const perc = parseInt(parts[3], 10) / 100;
            const temp = parseInt(parts[4], 10);

            list.push({
                id: isNaN(id) ? list.length : id,
                name: name,
                label: gpuShortLabel(rawName, id, source),
                perc: isNaN(perc) ? 0 : perc,
                temp: isNaN(temp) ? 0 : temp,
                source: source
            });
        }

        list.sort((a, b) => {
            if (a.source !== b.source)
                return a.source === "nvidia" ? -1 : 1;
            return a.id - b.id;
        });

        gpus = list;
        syncLegacyGpu();
    }

    function formatKib(kib: real): var {
        const mib = 1024;
        const gib = 1024 ** 2;
        const tib = 1024 ** 3;

        if (kib >= tib)
            return {
                value: kib / tib,
                unit: "TiB"
            };
        if (kib >= gib)
            return {
                value: kib / gib,
                unit: "GiB"
            };
        if (kib >= mib)
            return {
                value: kib / mib,
                unit: "MiB"
            };
        return {
            value: kib,
            unit: "KiB"
        };
    }

    Timer {
        running: root.refCount > 0
        interval: GlobalConfig.dashboard.resourceUpdateInterval
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            storage.running = true;
            gpuUsage.running = true;
            sensors.running = true;
        }
    }

    // One-time CPU info detection (name)
    FileView {
        id: cpuinfoInit

        path: "/proc/cpuinfo"
        onLoaded: {
            const nameMatch = text().match(/model name\s*:\s*(.+)/);
            if (nameMatch)
                root.cpuName = root.cleanCpuName(nameMatch[1]);
        }
    }

    FileView {
        id: stat

        path: "/proc/stat"
        onLoaded: {
            const data = text().match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/);
            if (data) {
                const stats = data.slice(1).map(n => parseInt(n, 10));
                const total = stats.reduce((a, b) => a + b, 0);
                const idle = stats[3] + (stats[4] ?? 0);

                const totalDiff = total - root.lastCpuTotal;
                const idleDiff = idle - root.lastCpuIdle;
                root.cpuPerc = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0;

                root.lastCpuTotal = total;
                root.lastCpuIdle = idle;
            }
        }
    }

    FileView {
        id: meminfo

        path: "/proc/meminfo"
        onLoaded: {
            const data = text();
            root.memTotal = parseInt(data.match(/MemTotal: *(\d+)/)[1], 10) || 1;
            root.memUsed = (root.memTotal - parseInt(data.match(/MemAvailable: *(\d+)/)[1], 10)) || 0;
        }
    }

    Process {
        id: storage

        // Mounted partitions/volumes — labels match file-manager folder names (root, efi, games, …)
        command: ["lsblk", "-J", "-b", "-o", "NAME,SIZE,TYPE,FSUSED,FSSIZE,MOUNTPOINT"]

        stdout: StdioCollector {
            onStreamFinished: {
                const data = JSON.parse(text);
                const diskList = [];
                const seenMounts = new Set();

                const mountLabel = mountPath => {
                    if (!mountPath || mountPath === "/")
                        return "root";
                    const name = mountPath.replace(/\/$/, "").split("/").pop();
                    return name !== "" ? name : mountPath;
                };

                const collectMounts = (node, out) => {
                    const mount = node.mountpoint;
                    const size = parseInt(node.fssize) || 0;
                    const used = parseInt(node.fsused) || 0;

                    if (mount && size > 0 && !seenMounts.has(mount)) {
                        seenMounts.add(mount);
                        out.push({
                            mount: mount,
                            device: node.name,
                            label: mountLabel(mount),
                            used: used / 1024,
                            total: size / 1024,
                            free: (size - used) / 1024,
                            perc: used / size,
                            hasRoot: mount === "/"
                        });
                    }

                    if (node.children) {
                        for (const child of node.children)
                            collectMounts(child, out);
                    }
                };

                for (const dev of data.blockdevices) {
                    if (dev.name?.startsWith("zram"))
                        continue;
                    collectMounts(dev, diskList);
                }

                root.disks = diskList.sort((a, b) => {
                    if (a.hasRoot && !b.hasRoot)
                        return -1;
                    if (!a.hasRoot && b.hasRoot)
                        return 1;
                    return a.mount.localeCompare(b.mount);
                });
            }
        }
    }

    // GPU name detection (one-time)
    Process {
        id: gpuNameDetect

        running: true
        command: ["sh", "-c", "nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || glxinfo -B 2>/dev/null | grep 'Device:' | cut -d':' -f2 | cut -d'(' -f1 || lspci 2>/dev/null | grep -i 'vga\\|3d controller\\|display' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                if (!output)
                    return;

                // Check if it's from nvidia-smi (clean GPU name)
                if (output.toLowerCase().includes("nvidia") || output.toLowerCase().includes("geforce") || output.toLowerCase().includes("rtx") || output.toLowerCase().includes("gtx")) {
                    root.gpuName = root.cleanGpuName(output);
                } else if (output.toLowerCase().includes("rx")) {
                    root.gpuName = root.cleanGpuName(output);
                } else {
                    // Parse lspci output: extract name from brackets or after colon
                    // Handles cases like [AMD/ATI] Navi 21 [Radeon RX 6800/6800 XT / 6900 XT] (rev c0)
                    const bracketMatch = output.match(/\[([^\]]+)\][^\[]*$/);
                    if (bracketMatch) {
                        root.gpuName = root.cleanGpuName(bracketMatch[1]);
                    } else {
                        const colonMatch = output.match(/:\s*(.+)/);
                        if (colonMatch)
                            root.gpuName = root.cleanGpuName(colonMatch[1]);
                    }
                }
            }
        }
    }

    Process {
        id: gpuTypeCheck

        running: !GlobalConfig.services.gpuType
        command: ["sh", "-c", "if command -v nvidia-smi &>/dev/null && nvidia-smi -L &>/dev/null; then echo NVIDIA; elif ls /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | grep -q .; then echo GENERIC; else echo NONE; fi"]
        stdout: StdioCollector {
            onStreamFinished: root.autoGpuType = text.trim()
        }
    }

    Process {
        id: gpuUsage

        command: root.gpuQueryCommand()
        stdout: StdioCollector {
            onStreamFinished: root.parseGpuStdout(text)
        }
    }

    Process {
        id: sensors

        command: ["sensors"]
        environment: ({
                LANG: "C.UTF-8",
                LC_ALL: "C.UTF-8"
            })
        stdout: StdioCollector {
            onStreamFinished: {
                let cpuTemp = text.match(/(?:Package id [0-9]+|Tdie):\s+((\+|-)[0-9.]+)(°| )C/);
                if (!cpuTemp)
                    // If AMD Tdie pattern failed, try fallback on Tctl
                    cpuTemp = text.match(/Tctl:\s+((\+|-)[0-9.]+)(°| )C/);

                if (cpuTemp)
                    root.cpuTemp = parseFloat(cpuTemp[1]);

                const adapterTemps = [];
                let eligible = false;
                let blockSum = 0;
                let blockCount = 0;

                const flushBlock = () => {
                    if (blockCount > 0)
                        adapterTemps.push(blockSum / blockCount);
                    blockSum = 0;
                    blockCount = 0;
                };

                for (const line of text.trim().split("\n")) {
                    if (line === "Adapter: PCI adapter") {
                        flushBlock();
                        eligible = true;
                    } else if (line === "") {
                        flushBlock();
                        eligible = false;
                    } else if (eligible) {
                        let match = line.match(/^(temp[0-9]+|GPU core|edge)+:\s+\+([0-9]+\.[0-9]+)(°| )C/);
                        if (!match)
                            match = line.match(/^(junction|mem)+:\s+\+([0-9]+\.[0-9]+)(°| )C/);

                        if (match) {
                            blockSum += parseFloat(match[2]);
                            blockCount++;
                        }
                    }
                }

                flushBlock();

                if (root.gpus.some(gpu => gpu.source === "drm"))
                    root.mergeGpuTemps(adapterTemps);
            }
        }
    }
}
