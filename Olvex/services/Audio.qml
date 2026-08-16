pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Olvex
import Olvex.Config
import Olvex.Services

Singleton {
    id: root

    property string previousSinkName: ""
    property string previousSourceName: ""

    property list<PwNode> sinks: []
    property list<PwNode> sources: []
    property list<PwNode> streams: []

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool muted: !!sink?.audio?.muted
    readonly property real volume: sink?.audio?.volume ?? 0

    readonly property bool sourceMuted: !!source?.audio?.muted
    readonly property real sourceVolume: source?.audio?.volume ?? 0

    readonly property alias cava: cava
    readonly property int visualiserFps: Math.max(1, Math.min(GlobalConfig.services["visualiserFps"] || 60, 60))

    function syncCavaFrameRate(): void {
        if ("frameRate" in cava)
            cava.frameRate = root.visualiserFps;
    }

    function setVolume(newVolume: real): void {
        const clamped = Math.max(0, Math.min(GlobalConfig.services.maxVolume || 1.5, newVolume));
        if (sink?.ready && sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = clamped;
        }
        const pct = Math.round(clamped * 100);
        let target = "@DEFAULT_SINK@";
        if (sink?.name)
            target = sink.name;
        setSinkProc.command = ["sh", "-c", `pactl set-sink-volume "${target}" ${pct}% ; pactl set-sink-mute "${target}" 0`];
        setSinkProc.running = true;
    }

    function setSinkVolume(sinkName: string, newVolume: real): void {
        const clamped = Math.max(0, Math.min(GlobalConfig.services.maxVolume || 1.5, newVolume));
        const targetNode = sinks.find(s => s && (s.name === sinkName || (s.name && sinkName && (s.name.includes(sinkName) || sinkName.includes(s.name)))));
        if (targetNode?.audio) {
            targetNode.audio.muted = false;
            targetNode.audio.volume = clamped;
        }
        const pct = Math.round(clamped * 100);
        setSinkProc.command = ["sh", "-c", `pactl set-sink-volume "${sinkName}" ${pct}% ; pactl set-sink-mute "${sinkName}" 0`];
        setSinkProc.running = true;
    }

    function incrementVolume(amount: real): void {
        setVolume(volume + (amount || GlobalConfig.services.audioIncrement));
    }

    function decrementVolume(amount: real): void {
        setVolume(volume - (amount || GlobalConfig.services.audioIncrement));
    }

    function setSourceVolume(newVolume: real): void {
        const clamped = Math.max(0, Math.min(GlobalConfig.services.maxVolume || 1.5, newVolume));
        if (source?.ready && source?.audio) {
            source.audio.muted = false;
            source.audio.volume = clamped;
        }
        const pct = Math.round(clamped * 100);
        let target = "@DEFAULT_SOURCE@";
        if (source?.name)
            target = source.name;
        setSourceProc.command = ["sh", "-c", `pactl set-source-volume "${target}" ${pct}% ; pactl set-source-mute "${target}" 0`];
        setSourceProc.running = true;
    }

    function incrementSourceVolume(amount: real): void {
        setSourceVolume(sourceVolume + (amount || GlobalConfig.services.audioIncrement));
    }

    function decrementSourceVolume(amount: real): void {
        setSourceVolume(sourceVolume - (amount || GlobalConfig.services.audioIncrement));
    }

    function setAudioSink(newSink: PwNode): void {
        if (!newSink) return;
        Pipewire.preferredDefaultAudioSink = newSink;
        if (newSink.name) {
            let cmd = `pactl set-default-sink "${newSink.name}" ; for input in $(pactl list short sink-inputs 2>/dev/null | cut -f1); do pactl move-sink-input "$input" "${newSink.name}" 2>/dev/null; done`;
            setSinkProc.command = ["sh", "-c", cmd];
            setSinkProc.running = true;
            refreshTimer.restart();
        }
    }

    function setAudioSource(newSource: PwNode): void {
        if (!newSource) return;
        Pipewire.preferredDefaultAudioSource = newSource;
        if (newSource.name) {
            let cmd = `pactl set-default-source "${newSource.name}" ; for output in $(pactl list short source-outputs 2>/dev/null | cut -f1); do pactl move-source-output "$output" "${newSource.name}" 2>/dev/null; done`;
            setSourceProc.command = ["sh", "-c", cmd];
            setSourceProc.running = true;
            refreshTimer.restart();
        }
    }

    function cycleNextAudioOutput(): void {
        if (sinks.length === 0)
            return;

        const currentIndex = sinks.findIndex(s => s === sink);
        const nextIndex = (currentIndex + 1) % sinks.length;
        setAudioSink(sinks[nextIndex]);
    }

    function setStreamVolume(stream: PwNode, newVolume: real): void {
        if (stream?.ready && stream?.audio) {
            stream.audio.muted = false;
            stream.audio.volume = Math.max(0, Math.min(GlobalConfig.services.maxVolume, newVolume));
        }
    }

    function setStreamMuted(stream: PwNode, muted: bool): void {
        if (stream?.ready && stream?.audio) {
            stream.audio.muted = muted;
        }
    }

    function getStreamVolume(stream: PwNode): real {
        return stream?.audio?.volume ?? 0;
    }

    function getStreamMuted(stream: PwNode): bool {
        return !!stream?.audio?.muted;
    }

    function getStreamName(stream: PwNode): string {
        if (!stream)
            return qsTr("Unknown");
        // Try application name first, then description, then name
        return stream.properties["application.name"] || stream.description || stream.name || qsTr("Unknown Application");
    }

    onSinkChanged: {
        if (!sink?.ready)
            return;

        const newSinkName = sink.description || sink.name || qsTr("Unknown Device");
        const lower = newSinkName.toLowerCase();
        const isHeadphones = lower.includes("headphone") || lower.includes("headset") || lower.includes("earphone") || lower.includes("buds") || lower.includes("airpod");
        const prevLower = previousSinkName.toLowerCase();
        const prevIsHeadphones = prevLower.includes("headphone") || prevLower.includes("headset") || prevLower.includes("earphone") || prevLower.includes("buds") || prevLower.includes("airpod");

        if (previousSinkName && previousSinkName !== newSinkName && GlobalConfig.qspanel.toasts.audioOutputChanged) {
            if (isHeadphones && !prevIsHeadphones) {
                Toaster.toast(qsTr("Headphones connected"), newSinkName, "headphones", Toast.Info);
            } else if (!isHeadphones && prevIsHeadphones) {
                Toaster.toast(qsTr("Headphones disconnected"), qsTr("Switched to %1").arg(newSinkName), "headphones", Toast.Info);
            } else {
                let icon = "volume_up";
                if (lower.includes("hdmi") || lower.includes("tv"))
                    icon = "tv";
                else if (lower.includes("speaker"))
                    icon = "speaker";
                else if (isHeadphones)
                    icon = "headphones";

                Toaster.toast(qsTr("Audio output changed"), qsTr("Now using: %1").arg(newSinkName), icon, Toast.Info);
            }
        }

        previousSinkName = newSinkName;
    }

    onSourceChanged: {
        if (!source?.ready)
            return;

        const newSourceName = source.description || source.name || qsTr("Unknown Device");

        if (previousSourceName && previousSourceName !== newSourceName && GlobalConfig.qspanel.toasts.audioInputChanged)
            Toaster.toast(qsTr("Audio input changed"), qsTr("Now using: %1").arg(newSourceName), "mic");

        previousSourceName = newSourceName;
    }

    property var detailedSinks: []
    property var detailedSources: []

    Process {
        id: sinksProc
        command: ["pactl", "-f", "json", "list", "sinks"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.detailedSinks = JSON.parse(text.trim());
                } catch (e) {}
            }
        }
    }

    Process {
        id: sourcesProc
        command: ["pactl", "-f", "json", "list", "sources"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.detailedSources = JSON.parse(text.trim());
                } catch (e) {}
            }
        }
    }

    Process {
        id: setSinkProc
    }

    Process {
        id: setSourceProc
    }

    Timer {
        id: refreshTimer
        interval: 150
        repeat: false
        onTriggered: root.refreshDetailedDevices()
    }

    function refreshDetailedDevices(): void {
        sinksProc.running = true;
        sourcesProc.running = true;
    }

    function setAudioOutputPort(sinkName: string, portName: string): void {
        const targetNode = sinks.find(s => s && (s.name === sinkName || (s.name && sinkName && (s.name.includes(sinkName) || sinkName.includes(s.name)))));
        if (targetNode) {
            Pipewire.preferredDefaultAudioSink = targetNode;
        }
        let cmd = `pactl set-default-sink "${sinkName}"`;
        if (portName)
            cmd += ` ; pactl set-sink-port "${sinkName}" "${portName}"`;
        cmd += ` ; for input in $(pactl list short sink-inputs 2>/dev/null | cut -f1); do pactl move-sink-input "$input" "${sinkName}" 2>/dev/null; done`;
        setSinkProc.command = ["sh", "-c", cmd];
        setSinkProc.running = true;
        refreshTimer.restart();
    }

    function setAudioInputPort(sourceName: string, portName: string): void {
        const targetNode = sources.find(s => s && (s.name === sourceName || (s.name && sourceName && (s.name.includes(sourceName) || sourceName.includes(s.name)))));
        if (targetNode) {
            Pipewire.preferredDefaultAudioSource = targetNode;
        }
        let cmd = `pactl set-default-source "${sourceName}"`;
        if (portName)
            cmd += ` ; pactl set-source-port "${sourceName}" "${portName}"`;
        cmd += ` ; for output in $(pactl list short source-outputs 2>/dev/null | cut -f1); do pactl move-source-output "$output" "${sourceName}" 2>/dev/null; done`;
        setSourceProc.command = ["sh", "-c", cmd];
        setSourceProc.running = true;
        refreshTimer.restart();
    }

    Component.onCompleted: {
        previousSinkName = sink?.description || sink?.name || qsTr("Unknown Device");
        previousSourceName = source?.description || source?.name || qsTr("Unknown Device");
        root.refreshDetailedDevices();
    }

    Connections {
        function onValuesChanged(): void {
            const newSinks = [];
            const newSources = [];
            const newStreams = [];

            for (const node of Pipewire.nodes.values) {
                if (!node.isStream) {
                    if (node.isSink)
                        newSinks.push(node);
                    else if (node.audio)
                        newSources.push(node);
                } else if (node.audio) {
                    newStreams.push(node);
                }
            }

            root.sinks = newSinks;
            root.sources = newSources;
            root.streams = newStreams;
            root.refreshDetailedDevices();
        }

        target: Pipewire.nodes
    }

    PwObjectTracker {
        objects: [...root.sinks, ...root.sources, ...root.streams]
    }

    CavaProvider {
        id: cava

        bars: GlobalConfig.services.visualiserBars

        Component.onCompleted: root.syncCavaFrameRate()
    }

    Connections {
        target: GlobalConfig.services
        ignoreUnknownSignals: true

        function onVisualiserFpsChanged(): void {
            root.syncCavaFrameRate();
        }
    }

    IpcHandler {
        function cycleOutput(): void {
            root.cycleNextAudioOutput();
        }

        target: "audio"
    }
}
