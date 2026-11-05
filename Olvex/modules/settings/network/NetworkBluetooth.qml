
import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import "../../../components/icons"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Olvex.Config
import qs.services
import qs.utils

Item {
    id: root

    property Session session
    
    readonly property bool btEnabled: (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled) || false
    readonly property var btDevices: {
        const vals = Bluetooth.devices ? Bluetooth.devices.values : null;
        if (!vals)
            return [];
        return [...vals].sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || (a.name || "").localeCompare(b.name || "")).slice(0, 24);
    }
    readonly property int btConnectedCount: btDevices.filter(d => d.connected).length
    readonly property string btStatusText: {
        if (!Bluetooth.defaultAdapter)
            return qsTr("No adapter");
        if (!root.btEnabled)
            return qsTr("Off");
        if (root.btConnectedCount > 0)
            return qsTr("On · %1 connected").arg(root.btConnectedCount);
        return qsTr("On · %1 device%2").arg(root.btDevices.length).arg(root.btDevices.length === 1 ? "" : "s");
    }

    function toggleBluetooth(on) {
        const adapter = Bluetooth.defaultAdapter;
        if (!adapter)
            return;
        adapter.enabled = on;
        if (on)
            adapter.discovering = true;
    }
    
    opacity: 0
    y: 10
    Component.onCompleted: cascadeIn.start()
    
    ParallelAnimation {
        id: cascadeIn
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens.anim.durations.large; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens.anim.durations.large; easing.type: Easing.OutCubic }
    }

    implicitHeight: (col ? col.implicitHeight : 0) + Tokens.padding.large * 2
    
    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Tokens.padding.large
        anchors.rightMargin: Tokens.padding.large
        anchors.topMargin: Tokens.padding.large
        spacing: Tokens.spacing.large

        Section {
            title: qsTr("Bluetooth")
            description: qsTr("Pair and manage wireless accessories")
            icon: "bluetooth"

            SettingRow {
                Layout.fillWidth: true
                title: qsTr("Bluetooth")
                description: {
                    if (!root.btEnabled)
                        return root.btStatusText;
                    if (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering)
                        return qsTr("%1 · Scanning…").arg(root.btStatusText);
                    return root.btStatusText;
                }

                Row {
                    spacing: Tokens.spacing.small

                    Item {
                        id: btScanCtl
                        readonly property bool scanning: (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering) || false
                        readonly property bool canScan: root.btEnabled && !!Bluetooth.defaultAdapter
                        implicitWidth: 36
                        implicitHeight: 36

                        LoadingIndicator {
                            anchors.centerIn: parent
                            implicitSize: 32
                            color: Colours.palette.m3primary
                            animated: btScanCtl.scanning
                            opacity: btScanCtl.scanning ? 1 : 0
                            scale: btScanCtl.scanning ? 1 : 0.72
                            visible: opacity > 0.01
                            Behavior on opacity { Anim { type: Anim.FastEffects } }
                            Behavior on scale { Anim { type: Anim.DefaultSpatial } }
                        }

                        IconButton {
                            anchors.centerIn: parent
                            type: IconButton.Text
                            icon: "refresh"
                            disabled: !btScanCtl.canScan
                            opacity: btScanCtl.scanning ? 0 : 1
                            visible: opacity > 0.01
                            enabled: btScanCtl.canScan && !btScanCtl.scanning
                            Behavior on opacity { Anim { type: Anim.FastEffects } }

                            onClicked: {
                                const a = Bluetooth.defaultAdapter;
                                if (!a || !root.btEnabled) return;
                                if (a.discovering) {
                                    a.discovering = false;
                                    Qt.callLater(() => {
                                        if (Bluetooth.defaultAdapter)
                                            Bluetooth.defaultAdapter.discovering = true;
                                    });
                                } else {
                                    a.discovering = true;
                                }
                            }
                        }
                    }

                    StyledSwitch {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: root.btEnabled
                        enabled: !!Bluetooth.defaultAdapter
                        onToggled: root.toggleBluetooth(checked)
                    }
                }
            }
        }

        Section {
            Layout.fillWidth: true
            visible: root.btEnabled && root.btDevices.length > 0
            title: qsTr("Paired & Available Devices")
            accentColor: Colours.palette.m3primary

            Repeater {
                model: root.btDevices
                delegate: SettingRow {
                    id: btDev
                    required property var modelData
                    required property int index
                    showIconBackground: false

                    readonly property bool isConnecting: {
                        const s = modelData.state;
                        return s === BluetoothDeviceState.Connecting || s === BluetoothDeviceState.Disconnecting;
                    }
                    readonly property bool isConnected: modelData.connected && !btDev.isConnecting

                    title: btDev.modelData.name || btDev.modelData.address || qsTr("Unknown device")
                    description: {
                        if (btDev.isConnecting) {
                            if (btDev.modelData.state === BluetoothDeviceState.Disconnecting) return qsTr("Disconnecting…");
                            return qsTr("Connecting…");
                        }
                        if (btDev.isConnected) return qsTr("Connected");
                        if (btDev.modelData.paired || btDev.modelData.bonded) return qsTr("Paired");
                        return qsTr("Nearby");
                    }
                    clickable: !btDev.isConnecting
                    onClicked: {
                        if (!btDev.isConnecting)
                            btDev.modelData.connected = !btDev.modelData.connected;
                    }

                    customIcon: Component {
                        Loader {
                            id: btIconLoader
                            readonly property string devIcon: Icons.getBluetoothIcon(btDev.modelData.icon || "")
                            readonly property bool isGenericBt: devIcon === "bluetooth"
                            sourceComponent: isGenericBt ? btLottieComp : devIconComp

                            Component {
                                id: btLottieComp
                                BluetoothLottieIcon {
                                    size: 24
                                    connected: btDev.isConnected
                                    color: btDev.isConnected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                }
                            }

                            Component {
                                id: devIconComp
                                MaterialIcon {
                                    text: btIconLoader.devIcon
                                    color: btDev.isConnected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                    iconPointSize: Tokens.font.size.large
                                }
                            }
                        }
                    }

                    StyledRect {
                        implicitWidth: btPillRow.implicitWidth + Tokens.padding.normal * 2
                        implicitHeight: 28
                        radius: Tokens.rounding.full
                        color: {
                            if (btDev.isConnecting) return Qt.alpha(Colours.palette.m3primary, 0.16);
                            if (btDev.isConnected) return Colours.palette.m3primaryContainer;
                            return Colours.palette.m3surfaceContainerHighest;
                        }

                        Behavior on color { CAnim {} }

                        Row {
                            id: btPillRow
                            anchors.centerIn: parent
                            spacing: Tokens.spacing.extraSmall

                            LoadingIndicator {
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 14
                                color: Colours.palette.m3primary
                                animated: btDev.isConnecting
                                visible: btDev.isConnecting
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    if (btDev.isConnecting) {
                                        if (btDev.modelData.state === BluetoothDeviceState.Disconnecting) return qsTr("Disconnecting");
                                        return qsTr("Connecting");
                                    }
                                    if (btDev.isConnected) return qsTr("Connected");
                                    return qsTr("Available");
                                }
                                color: {
                                    if (btDev.isConnecting) return Colours.palette.m3primary;
                                    if (btDev.isConnected) return Colours.palette.m3onPrimaryContainer;
                                    return Colours.palette.m3onSurfaceVariant;
                                }
                                font.weight: Font.Normal
                                font.letterSpacing: 0.15
                                textPointSize: Tokens.font.size.small
                            }
                        }

                        StateLayer {
                            anchors.fill: parent
                            radius: parent.radius
                            interactive: !btDev.isConnecting
                            disabled: btDev.isConnecting
                            onClicked: {
                                if (!btDev.isConnecting)
                                    btDev.modelData.connected = !btDev.modelData.connected;
                            }
                        }
                    }
                }
            }
        }
    }
}