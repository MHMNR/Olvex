import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Olvex
import Olvex.Config
import Olvex.Services
import qs.utils
import qs.services

Item {
    id: root

    // Track known connected bluetooth devices to detect transitions and avoid boot spam
    property var _connectedBtDevices: ({})
    property bool _btInitialized: false

    // ── USB Watcher Connections ──
    Connections {
        target: UsbWatcher

        function onDeviceConnected(title, message, icon): void {
            if (GlobalConfig.qspanel.toasts.usbDevices ?? true)
                Toaster.toast(title, message, icon, Toast.Info);
        }

        function onDeviceDisconnected(title, message, icon): void {
            if (GlobalConfig.qspanel.toasts.usbDevices ?? true)
                Toaster.toast(title, message, icon, Toast.Info);
        }
    }

    // ── Bluetooth Device Connect / Disconnect Monitor ──
    function getBtIcon(device): string {
        const name = (device?.name || "").toLowerCase();
        const icon = (device?.icon || "").toLowerCase();

        if (name.includes("headphone") || name.includes("headset") || name.includes("buds") ||
            name.includes("airpod") || name.includes("earphone") || name.includes("freebuds") ||
            name.includes("wh-1000") || icon.includes("headphone") || icon.includes("headset"))
            return "headphones";

        if (name.includes("mouse") || icon.includes("mouse"))
            return "mouse";

        if (name.includes("keyboard") || icon.includes("keyboard"))
            return "keyboard";

        if (name.includes("controller") || name.includes("gamepad") || name.includes("xbox") ||
            name.includes("dualsense") || name.includes("joystick"))
            return "sports_esports";

        if (name.includes("speaker") || name.includes("soundbar") || icon.includes("audio"))
            return "speaker";

        return Icons.getBluetoothIcon(device?.icon || "") || "bluetooth";
    }

    Timer {
        id: btInitTimer
        interval: 1500
        running: true
        repeat: false
        onTriggered: {
            const map = {};
            for (const d of Bluetooth.devices.values) {
                if (d.connected)
                    map[d.address || d.name] = d.name || qsTr("Bluetooth Device");
            }
            root._connectedBtDevices = map;
            root._btInitialized = true;
        }
    }

    Connections {
        target: Bluetooth.devices

        function onValuesChanged(): void {
            if (!root._btInitialized)
                return;

            const currentMap = {};
            const devices = Bluetooth.devices.values;

            for (const d of devices) {
                const id = d.address || d.name;
                if (d.connected) {
                    currentMap[id] = d.name || qsTr("Bluetooth Device");
                    if (!root._connectedBtDevices.hasOwnProperty(id)) {
                        // New connection!
                        if (GlobalConfig.qspanel.toasts.bluetoothDevices ?? true) {
                            const icon = root.getBtIcon(d);
                            Toaster.toast(qsTr("Bluetooth connected"), d.name || qsTr("Bluetooth Device"), icon, Toast.Info);
                        }
                    }
                }
            }

            for (const id in root._connectedBtDevices) {
                if (!currentMap.hasOwnProperty(id)) {
                    // Disconnected!
                    if (GlobalConfig.qspanel.toasts.bluetoothDevices ?? true) {
                        const name = root._connectedBtDevices[id];
                        Toaster.toast(qsTr("Bluetooth disconnected"), name, "bluetooth_disabled", Toast.Info);
                    }
                }
            }

            root._connectedBtDevices = currentMap;
        }
    }

    // Monitor live connected property changes per device
    Repeater {
        model: Bluetooth.devices.values

        Item {
            required property BluetoothDevice modelData

            Connections {
                target: modelData

                function onConnectedChanged(): void {
                    if (!root._btInitialized)
                        return;

                    const id = modelData.address || modelData.name;
                    if (modelData.connected) {
                        if (!root._connectedBtDevices.hasOwnProperty(id)) {
                            root._connectedBtDevices[id] = modelData.name || qsTr("Bluetooth Device");
                            if (GlobalConfig.qspanel.toasts.bluetoothDevices ?? true) {
                                const icon = root.getBtIcon(modelData);
                                Toaster.toast(qsTr("Bluetooth connected"), modelData.name || qsTr("Bluetooth Device"), icon, Toast.Info);
                            }
                        }
                    } else {
                        if (root._connectedBtDevices.hasOwnProperty(id)) {
                            const name = root._connectedBtDevices[id];
                            delete root._connectedBtDevices[id];
                            if (GlobalConfig.qspanel.toasts.bluetoothDevices ?? true)
                                Toaster.toast(qsTr("Bluetooth disconnected"), name, "bluetooth_disabled", Toast.Info);
                        }
                    }
                }
            }
        }
    }
}
