pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Olvex
import Olvex.Config
import qs.utils

Singleton {
    id: root

    property string osName: "Linux"
    property string osPrettyName: "Linux"
    property string osId: "linux"
    property list<string> osIdLike
    property string osLogo: ""
    property string osGlyph: "\uf17c"
    property string detectedOsGlyph: "\uf31a"
    property bool isOlvexLogo: false
    property bool hasCustomImage: false
    property bool isDefaultLogo: true
    property string kernel: ""
    property string arch: "x86_64"
    property string hostName: "localhost"
    property string hyprVersion: ""

    property string uptime
    readonly property string user: Quickshell.env("USER") || "user"
    readonly property string wm: Quickshell.env("XDG_CURRENT_DESKTOP") || Quickshell.env("XDG_SESSION_DESKTOP") || "Hyprland"
    readonly property string shellRaw: Quickshell.env("SHELL").split("/").pop() || "fish"
    readonly property string shell: {
        const s = shellRaw.toLowerCase();
        if (s === "fish") return "Fish";
        if (s === "zsh") return "Zsh";
        if (s === "bash") return "Bash";
        if (s === "nushell" || s === "nu") return "Nu";
        return s ? (s.charAt(0).toUpperCase() + s.slice(1)) : "Shell";
    }

    readonly property string kernelFormatted: {
        if (!kernel) return "Linux";
        return kernel.startsWith("Linux") ? kernel : ("Linux " + kernel);
    }

    readonly property string osDisplay: {
        const name = osPrettyName || osName || "Linux";
        return arch ? (name + " (" + arch + ")") : name;
    }

    readonly property string hostDisplay: {
        return (user || "user") + "@" + (hostName || "localhost");
    }

    readonly property string wmDisplay: {
        const w = wm || "Hyprland";
        const ver = hyprVersion ? (" " + hyprVersion) : "";
        return w + ver + " · Wayland";
    }

    readonly property string frameworkDisplay: {
        const qtVer = (typeof Qt !== "undefined" && Qt.version) ? Qt.version : "6.9";
        return "Qt " + qtVer + " · QML · Hyprland IPC";
    }

    FileView {
        id: fileKernel
        path: "/proc/version"
        onLoaded: {
            // "Linux version 6.9.4-zen1-1-zen (linux-zen@archlinux) ..."
            const txt = text();
            const match = txt.match(/Linux version (\S+)/);
            if (match) root.kernel = match[1];
            if (txt.includes("x86_64")) root.arch = "x86_64";
            else if (txt.includes("aarch64") || txt.includes("arm64")) root.arch = "aarch64";
            else if (txt.includes("arm")) root.arch = "arm";
        }
    }

    FileView {
        id: fileHostname
        path: "/proc/sys/kernel/hostname"
        onLoaded: {
            const h = text().trim();
            if (h) root.hostName = h;
        }
    }

    Process {
        id: hyprVerProc
        running: true
        command: ["hyprctl", "version"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text) return;
                const m = text.match(/Hyprland\s+([0-9.]+)/i);
                if (m && m[1]) root.hyprVersion = "v" + m[1];
            }
        }
    }

    function updateLogo() {
        const logoConfig = (GlobalConfig.general.logo || "").trim();

        if (logoConfig === "olvex") {
            root.isOlvexLogo = true;
            root.hasCustomImage = false;
            root.osLogo = Qt.resolvedUrl("../assets/images/olvex-mark.svg").toString();
            root.osGlyph = "";
            root.isDefaultLogo = false;
            return;
        }

        if (logoConfig && logoConfig !== "auto") {
            const isPath = logoConfig.includes("/") || /\.(svg|png|jpg|jpeg|webp)$/i.test(logoConfig);
            if (isPath) {
                root.isOlvexLogo = false;
                root.hasCustomImage = true;
                root.osLogo = logoConfig.startsWith("/") ? ("file://" + logoConfig) : ("file://" + Paths.absolutePath(logoConfig));
                root.osGlyph = "";
                root.isDefaultLogo = false;
                return;
            }

            let glyph = "";
            if (typeof CUtils !== "undefined" && typeof CUtils.distroGlyph === "function") {
                glyph = CUtils.distroGlyph(logoConfig, [], logoConfig);
            }

            if (glyph) {
                root.isOlvexLogo = false;
                root.hasCustomImage = false;
                root.osLogo = "";
                root.osGlyph = glyph;
                root.isDefaultLogo = false;
                return;
            }

            const iconResolved = Quickshell.iconPath(logoConfig, true);
            if (iconResolved) {
                root.isOlvexLogo = false;
                root.hasCustomImage = true;
                root.osLogo = iconResolved;
                root.osGlyph = "";
                root.isDefaultLogo = false;
                return;
            }

            root.isOlvexLogo = false;
            root.hasCustomImage = false;
            root.osLogo = "";
            root.osGlyph = logoConfig;
            root.isDefaultLogo = false;
            return;
        }

        // Auto mode (detect from distro via C++ CUtils)
        root.isOlvexLogo = false;
        root.hasCustomImage = false;
        root.osLogo = "";
        root.osGlyph = root.detectedOsGlyph || "\uf31a";
        root.isDefaultLogo = true;
    }

    FileView {
        id: osRelease

        path: "/etc/os-release"
        onLoaded: {
            const rawText = text();
            if (!rawText) return;

            const lines = rawText.split("\n");

            const fd = key => {
                const prefix = key + "=";
                const line = lines.find(l => l.startsWith(prefix));
                if (!line) return "";
                const val = line.slice(prefix.length).trim();
                return val.replace(/^["']|["']$/g, "");
            };

            root.osName = fd("NAME") || "Linux";
            root.osPrettyName = fd("PRETTY_NAME") || root.osName;
            root.osId = (fd("ID") || "linux").toLowerCase();

            const rawIdLike = fd("ID_LIKE");
            root.osIdLike = rawIdLike ? rawIdLike.toLowerCase().split(/\s+/).filter(Boolean) : [];

            if (typeof CUtils !== "undefined" && typeof CUtils.distroGlyph === "function") {
                root.detectedOsGlyph = CUtils.distroGlyph(root.osId, root.osIdLike, root.osName);
            } else {
                root.detectedOsGlyph = "\uf31a";
            }

            root.updateLogo();
        }
    }

    Connections {
        function onLogoChanged() {
            root.updateLogo();
        }

        target: GlobalConfig.general
    }

    Timer {
        running: true
        repeat: true
        interval: 15000
        onTriggered: fileUptime.reload()
    }

    FileView {
        id: fileUptime

        path: "/proc/uptime"
        onLoaded: {
            const up = parseInt(text().split(" ")[0] ?? 0);

            const days = Math.floor(up / 86400);
            const hours = Math.floor((up % 86400) / 3600);
            const minutes = Math.floor((up % 3600) / 60);

            let str = "";
            if (days > 0)
                str += `${days}d`;
            if (hours > 0)
                str += `${str ? " " : ""}${hours}h`;
            if (minutes > 0 || !str)
                str += `${str ? " " : ""}${minutes}m`;
            root.uptime = str;
        }
    }
}
