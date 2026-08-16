import QtQuick
import Olvex
import Olvex.Services

Item {
    id: root

    Connections {
        target: UsbWatcher

        function onDeviceConnected(title, message, icon): void {
            Toaster.toast(title, message, icon, Toast.Info);
        }

        function onDeviceDisconnected(title, message, icon): void {
            Toaster.toast(title, message, icon, Toast.Info);
        }
    }
}
