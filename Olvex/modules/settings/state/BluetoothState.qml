import ".."
import "../chrome"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import Quickshell.Bluetooth

QtObject {
    id: root

    property BluetoothDevice active: null
    property BluetoothAdapter currentAdapter: Bluetooth.defaultAdapter
    property bool editingAdapterName: false
    property bool fabMenuOpen: false
    property bool editingDeviceName: false
}
