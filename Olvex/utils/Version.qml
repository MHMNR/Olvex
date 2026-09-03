pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root

    readonly property string name: "Olvex Shell"
    property string version: "1.0.0"
    property int major: 1
    property int minor: 0
    property int patch: 0
    property string channel: "Rolling"
    property string releaseType: "beta"
    property string buildId: "2026.09.03"

    property string commit: ""
    property string branch: ""
    property string commitDate: ""

    readonly property string versionString: "v" + root.version + (root.releaseType ? "-" + root.releaseType : "")
    readonly property string fullString: root.commit ? (root.versionString + " (" + root.commit + ")") : root.versionString
    readonly property string displayString: root.commit ? (root.versionString + " · " + (root.branch ? root.branch + "@" : "") + root.commit) : root.versionString

    readonly property string manifestPath: {
        const rootUrl = Qt.resolvedUrl("../version.json");
        const local = Paths.toLocalFile(rootUrl);
        return local || "";
    }

    readonly property string repoDir: {
        const rootUrl = Qt.resolvedUrl("..");
        const local = Paths.toLocalFile(rootUrl);
        return local || "";
    }

    FileView {
        id: manifestFile
        path: root.manifestPath
        
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (data.version) root.version = data.version;
                if (data.major !== undefined) root.major = data.major;
                if (data.minor !== undefined) root.minor = data.minor;
                if (data.patch !== undefined) root.patch = data.patch;
                if (data.channel) root.channel = data.channel;
                if (data.releaseType) root.releaseType = data.releaseType;
                if (data.buildId) root.buildId = data.buildId;
            } catch (e) {
                // Keep defaults
            }
        }
    }

    Process {
        id: gitProc
        running: true
        command: ["git", "-C", root.repoDir, "log", "-1", "--format=%h|%cd|%D", "--date=short"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim() === "") return;
                const parts = text.trim().split("|");
                if (parts[0]) root.commit = parts[0].trim();
                if (parts[1]) root.commitDate = parts[1].trim();
                if (parts[2]) {
                    const m = parts[2].match(/HEAD -> ([^,]+)/);
                    if (m) root.branch = m[1].trim();
                }
            }
        }
    }
}
