pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Olvex
import Olvex.Config

Singleton {
    id: root

    property bool enabled: GlobalConfig.services?.nightLight ?? false
    property int temperature: GlobalConfig.services?.nightLightTemperature ?? 4500
    property bool autoSchedule: GlobalConfig.services?.nightLightAuto ?? true

    function setEnabled(val: bool): void {
        if (root.enabled !== val) {
            root.enabled = val;
            if (GlobalConfig.services) {
                GlobalConfig.services.nightLight = val;
                GlobalConfig.save();
            }
        }
    }

    function setTemperature(val: int): void {
        if (root.temperature !== val) {
            root.temperature = val;
            if (GlobalConfig.services) {
                GlobalConfig.services.nightLightTemperature = val;
                GlobalConfig.save();
            }
        }
    }

    function setAutoSchedule(val: bool): void {
        if (root.autoSchedule !== val) {
            root.autoSchedule = val;
            if (GlobalConfig.services) {
                GlobalConfig.services.nightLightAuto = val;
                GlobalConfig.save();
            }
        }
    }

    function toggle(): void {
        setEnabled(!root.enabled);
    }

    function runCommand(cmd: string) {
        if (applyScript.running)
            applyScript.running = false;
        applyScript.command = ["bash", "-c", cmd];
        applyScript.running = true;
    }

    function calculateAutoTemp(): int {
        const d = new Date();
        const hour = d.getHours() + (d.getMinutes() / 60);
        // Day: 07:30 -> 18:00 (6500K)
        // Sunset transition: 18:00 -> 21:00 (6500 -> target)
        // Night: 21:00 -> 06:00 (target)
        // Sunrise transition: 06:00 -> 07:30 (target -> 6500)
        const targetTemp = root.temperature;
        if (hour >= 7.5 && hour < 18.0) {
            return 6500;
        } else if (hour >= 18.0 && hour < 21.0) {
            const frac = (hour - 18.0) / 3.0;
            return Math.round(6500 - frac * (6500 - targetTemp));
        } else if (hour >= 21.0 || hour < 6.0) {
            return targetTemp;
        } else {
            const frac = (hour - 6.0) / 1.5;
            return Math.round(targetTemp + frac * (6500 - targetTemp));
        }
    }

    function applyState() {
        const targetTemp = root.autoSchedule ? calculateAutoTemp() : root.temperature;

        if (root.enabled) {
            if (targetTemp >= 6500) {
                // Neutral
                runCommand(`
                    NIGHT_BIN=$(which hyprsunset 2>/dev/null || echo "$HOME/.local/bin/hyprsunset")
                    if [ -x "$NIGHT_BIN" ]; then
                        pkill -9 hyprsunset 2>/dev/null || true
                        nohup "$NIGHT_BIN" -i >/dev/null 2>&1 &
                        sleep 0.3
                        pkill -9 hyprsunset 2>/dev/null || true
                    fi
                    pkill -9 gammastep 2>/dev/null || true
                    gammastep -x 2>/dev/null || true
                `);
            } else {
                runCommand(`
                    NIGHT_BIN=$(which hyprsunset 2>/dev/null || echo "$HOME/.local/bin/hyprsunset")
                    if [ -x "$NIGHT_BIN" ]; then
                        pkill -9 hyprsunset 2>/dev/null || true
                        pkill -9 gammastep 2>/dev/null || true
                        nohup "$NIGHT_BIN" -t ${targetTemp} >/dev/null 2>&1 &
                    elif which gammastep >/dev/null 2>&1; then
                        pkill -9 gammastep 2>/dev/null || true
                        nohup gammastep -O ${targetTemp} >/dev/null 2>&1 &
                    fi
                `);
            }
        } else {
            runCommand(`
                NIGHT_BIN=$(which hyprsunset 2>/dev/null || echo "$HOME/.local/bin/hyprsunset")
                if [ -x "$NIGHT_BIN" ]; then
                    pkill -9 hyprsunset 2>/dev/null || true
                    nohup "$NIGHT_BIN" -i >/dev/null 2>&1 &
                    sleep 0.3
                    pkill -9 hyprsunset 2>/dev/null || true
                fi
                pkill -9 gammastep 2>/dev/null || true
                gammastep -x 2>/dev/null || true
            `);
        }
    }

    Timer {
        id: debounceApply
        interval: 80
        repeat: false
        onTriggered: root.applyState()
    }

    Timer {
        id: autoScheduleTimer
        interval: 60000
        repeat: true
        running: root.enabled && root.autoSchedule
        onTriggered: root.applyState()
    }

    onEnabledChanged: {
        if (GlobalConfig.services && GlobalConfig.services.nightLight !== root.enabled) {
            GlobalConfig.services.nightLight = root.enabled;
            GlobalConfig.save();
        }
        debounceApply.restart();
    }

    onTemperatureChanged: {
        if (GlobalConfig.services && GlobalConfig.services.nightLightTemperature !== root.temperature) {
            GlobalConfig.services.nightLightTemperature = root.temperature;
            GlobalConfig.save();
        }
        if (root.enabled)
            debounceApply.restart();
    }

    onAutoScheduleChanged: {
        if (GlobalConfig.services && GlobalConfig.services.nightLightAuto !== root.autoSchedule) {
            GlobalConfig.services.nightLightAuto = root.autoSchedule;
            GlobalConfig.save();
        }
        if (root.enabled)
            debounceApply.restart();
    }

    Process {
        id: applyScript
        running: false
    }

    Component.onCompleted: {
        debounceApply.restart();
    }

    IpcHandler {
        function toggle(): void {
            root.toggle();
        }

        function isEnabled(): bool {
            return root.enabled;
        }

        function setEnabled(val: bool): void {
            root.setEnabled(val);
        }

        function setTemperature(temp: int): void {
            root.setTemperature(temp);
        }

        function setAutoSchedule(val: bool): void {
            root.setAutoSchedule(val);
        }

        target: "nightlight"
    }
}
