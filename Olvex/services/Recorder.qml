pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property alias running: props.running
    readonly property alias paused: props.paused
    readonly property alias elapsed: props.elapsed
    property bool selecting: false

    function start(extraArgs = []): void {
        if (props.running)
            return;

        if (extraArgs.some(a => a.includes("r"))) {
            root.selecting = true;
        }

        const script = `${Quickshell.shellDir}/scripts/record.sh`;
        Quickshell.execDetached([script, ...extraArgs]);

        pollTimer.restart();
    }

    function stop(): void {
        root.selecting = false;
        const script = `${Quickshell.shellDir}/scripts/record.sh`;
        Quickshell.execDetached([script, "--stop"]);
        Quickshell.execDetached(["pkill", "-f", "slurp"]);

        props.running = false;
        props.paused = false;
        props.elapsed = 0;
        pollTimer.restart();
    }

    function togglePause(): void {
        const script = `${Quickshell.shellDir}/scripts/record.sh`;
        Quickshell.execDetached([script, "-p"]);
        props.paused = !props.paused;
    }

    PersistentProperties {
        id: props

        property bool running: false
        property bool paused: false
        property real elapsed: 0

        reloadableId: "recorder"
    }

    Process {
        id: gsrCheckProc
        command: ["pidof", "gpu-screen-recorder"]
        onExited: code => { // qmllint disable signal-handler-parameters
            const isRunning = (code === 0);
            if (isRunning) {
                if (!props.running) {
                    props.running = true;
                    props.elapsed = 0;
                }
                root.selecting = false;
            } else {
                if (root.selecting) {
                    if (!slurpCheckProc.running)
                        slurpCheckProc.running = true;
                } else {
                    props.running = false;
                    props.paused = false;
                }
            }
        }
    }

    Process {
        id: slurpCheckProc
        command: ["pidof", "slurp"]
        onExited: code => { // qmllint disable signal-handler-parameters
            if (code !== 0 && !props.running) {
                graceTimer.restart();
            }
        }
    }

    Timer {
        id: graceTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (!gsrCheckProc.running)
                gsrCheckProc.running = true;
            root.selecting = false;
        }
    }

    Timer {
        id: pollTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            if (props.running && !props.paused) {
                props.elapsed++;
            }
            if (!gsrCheckProc.running) {
                gsrCheckProc.running = true;
            }
        }
    }

    Component.onCompleted: {
        gsrCheckProc.running = true;
    }
}
