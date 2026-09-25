pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Olvex
import Olvex.Config
import qs.utils

Singleton {
    id: root

    readonly property var availableSounds: [
        "charger-in.mp3",
        "charger-out.mp3",
        "device-in.mp3",
        "device-out.mp3",
        "notif.mp3",
        "notif2.mp3",
        "notif3.mp3",
        "notificationV.mp3",
        "toast.mp3",
        "warning.mp3"
    ]

    function soundLabel(filename) {
        if (!filename) return qsTr("None");
        if (filename.startsWith("/")) {
            const base = filename.split("/").pop();
            return base.replace(/\.[^/.]+$/, "") + " (" + qsTr("Custom") + ")";
        }
        switch (filename) {
            case "charger-in.mp3": return qsTr("Charger In");
            case "charger-out.mp3": return qsTr("Charger Out");
            case "device-in.mp3": return qsTr("Device Connect");
            case "device-out.mp3": return qsTr("Device Disconnect");
            case "notif.mp3": return qsTr("Notification 1");
            case "notif2.mp3": return qsTr("Notification 2");
            case "notif3.mp3": return qsTr("Notification 3");
            case "notificationV.mp3": return qsTr("Notification Urgent");
            case "toast.mp3": return qsTr("Toast Message");
            case "warning.mp3": return qsTr("Warning");
            default: return filename ? filename.replace(/\.[^/.]+$/, "") : "";
        }
    }

    function resolveAudioPath(name) {
        if (!name) return "";
        if (name.startsWith("/") || name.startsWith("file://")) {
            return name.replace(/^file:\/\//, "");
        }
        return Quickshell.shellDir + "/assets/audio/" + name;
    }

    function play(soundName, volMultiplier) {
        if (!GlobalConfig.services.uiSounds.enabled)
            return;
        const path = resolveAudioPath(soundName);
        if (!path)
            return;
        const mult = (volMultiplier !== undefined && volMultiplier !== null) ? volMultiplier : 1.0;
        const vol = Math.max(0.01, Math.min(1.0, (GlobalConfig.services.uiSounds.volume || 0.8) * mult));
        Quickshell.execDetached(["pw-play", "--volume", vol.toFixed(2), path]);
    }

    function preview(soundName) {
        const path = resolveAudioPath(soundName);
        if (!path)
            return;
        const vol = Math.max(0.01, Math.min(1.0, (GlobalConfig.services.uiSounds.volume || 0.8)));
        Quickshell.execDetached(["pw-play", "--volume", vol.toFixed(2), path]);
    }

    function playChargerIn() {
        if (GlobalConfig.services.uiSounds.enabled && GlobalConfig.services.uiSounds.charger)
            play(GlobalConfig.services.uiSounds.chargerInSound);
    }

    function playChargerOut() {
        if (GlobalConfig.services.uiSounds.enabled && GlobalConfig.services.uiSounds.charger)
            play(GlobalConfig.services.uiSounds.chargerOutSound);
    }

    function playDeviceIn() {
        if (GlobalConfig.services.uiSounds.enabled && GlobalConfig.services.uiSounds.device)
            play(GlobalConfig.services.uiSounds.deviceInSound);
    }

    function playDeviceOut() {
        if (GlobalConfig.services.uiSounds.enabled && GlobalConfig.services.uiSounds.device)
            play(GlobalConfig.services.uiSounds.deviceOutSound);
    }

    function playNotification(urgency) {
        if (GlobalConfig.services.uiSounds.enabled && GlobalConfig.services.uiSounds.notifications) {
            if (urgency === 2)
                play(GlobalConfig.services.uiSounds.notificationsUrgentSound);
            else
                play(GlobalConfig.services.uiSounds.notificationsSound);
        }
    }

    function playToast(type) {
        if (GlobalConfig.services.uiSounds.enabled && GlobalConfig.services.uiSounds.toasts) {
            if (type === 2 || type === 3) // Warning or Error
                play(GlobalConfig.services.uiSounds.warningSound);
            else
                play(GlobalConfig.services.uiSounds.toastSound);
        }
    }

    function playWarning() {
        if (GlobalConfig.services.uiSounds.enabled && GlobalConfig.services.uiSounds.warnings)
            play(GlobalConfig.services.uiSounds.warningSound);
    }

    function isHardwareEventToast(title, message, icon) {
        const t = (title || "").toLowerCase();
        const m = (message || "").toLowerCase();
        const ic = (icon || "").toLowerCase();

        // Charger events (handled by playChargerIn / playChargerOut)
        if (t.includes("charger") || t.includes("charging") || ic === "power" || ic === "power_off" || ic.includes("battery_charging"))
            return true;

        // Battery warnings (handled by playWarning)
        if (t.includes("battery") || t.includes("hibernating") || ic === "battery_android_alert")
            return true;

        // Bluetooth / USB / Headphones peripheral connect & disconnect / remove
        if (t.includes("bluetooth") || t.includes("device") || t.includes("usb") || t.includes("headphones") ||
            ic.includes("bluetooth") || ic.includes("usb") || ic === "headphones" || ic === "mouse" ||
            ic === "keyboard" || ic === "sports_esports" || ic === "speaker") {
            if (t.includes("connected") || t.includes("disconnected") || t.includes("removed") || t.includes("attached") ||
                t.includes("unplugged") || t.includes("ejected") || m.includes("connected") || m.includes("disconnected") ||
                m.includes("removed") || t.includes("switched") || ic.includes("off") || ic.includes("disabled"))
                return true;
        }

        return false;
    }

    Connections {
        target: Toaster
        function onToastAdded(title, message, icon, type) {
            if (root.isHardwareEventToast(title, message, icon))
                return;
            root.playToast(type);
        }
    }
}
