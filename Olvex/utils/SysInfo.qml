pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Olvex.Config
import qs.utils

Singleton {
    id: root

    property string osName
    property string osPrettyName
    property string osId
    property list<string> osIdLike
    property string osLogo: ""
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

    FileView {
        id: osRelease

        path: "/etc/os-release"
        onLoaded: {
            const lines = text().split("\n");

            const fd = key => lines.find(l => l.startsWith(`${key}=`))?.split("=")[1].replace(/"/g, "") ?? "";

            root.osName = fd("NAME");
            root.osPrettyName = fd("PRETTY_NAME");
            root.osId = fd("ID");
            root.osIdLike = fd("ID_LIKE").split(" ");

            const logoName = fd("LOGO");
            if (GlobalConfig.general.logo && GlobalConfig.general.logo !== "olvex") {
                root.osLogo = Quickshell.iconPath(GlobalConfig.general.logo, true) || "file://" + Paths.absolutePath(GlobalConfig.general.logo);
                root.isDefaultLogo = false;
            } else {
                const candidates = [
                    logoName,
                    root.osId + "-logo",
                    root.osId,
                    "distributor-logo-" + root.osId,
                    ...(root.osIdLike || []).map(id => id ? id + "-logo" : ""),
                    ...(root.osIdLike || []),
                    "linux"
                ];
                let resolved = "";
                for (const c of candidates) {
                    if (c) {
                        resolved = Quickshell.iconPath(c, true);
                        if (resolved) break;
                    }
                }
                root.osLogo = resolved || ("file:///usr/share/pixmaps/" + (logoName || root.osId) + ".svg");
                root.isDefaultLogo = GlobalConfig.general.logo === "olvex";
            }
        }
    }

    Connections {
        function onLogoChanged(): void {
            osRelease.reload();
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
