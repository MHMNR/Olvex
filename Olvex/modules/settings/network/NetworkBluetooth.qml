
import ".."
import "../chrome"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
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
    
    readonly property bool btEnabled: Bluetooth.defaultAdapter?.enabled ?? false
    readonly property var btDevices: {
        const vals = Bluetooth.devices?.values;
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

    function toggleBluetooth(on: bool): void {
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
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens.anim.durations.slow; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens.anim.durations.slow; easing.type: Easing.OutCubic }
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

        SettingRow {
            Layout.fillWidth: true
            title: qsTr("Bluetooth")
            description: {
                if (!root.btEnabled)
                    return root.btStatusText;
                if (Bluetooth.defaultAdapter?.discovering)
                    return qsTr("%1 · Scanning…").arg(root.btStatusText);
                return root.btStatusText;
            }
            icon: "bluetooth"
            divider: true

            Row {
                spacing: Tokens.spacing.small

                Item {
                    id: btScanCtl
                    readonly property bool scanning: Bluetooth.defaultAdapter?.discovering ?? false
                    readonly property bool canScan: root.btEnabled && !!Bluetooth.defaultAdapter
                    implicitWidth: 40
                    implicitHeight: 40

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

        Column {
            Layout.fillWidth: true
            visible: root.btEnabled
            spacing: 0

            Item {
                width: parent.width
                height: 96
                visible: root.btDevices.length === 0

                Column {
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.normal

                    LoadingIndicator {
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitSize: 36
                        color: Colours.palette.m3primary
                        animated: Bluetooth.defaultAdapter?.discovering ?? false
                        opacity: (Bluetooth.defaultAdapter?.discovering ?? false) ? 1 : 0.45
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: (Bluetooth.defaultAdapter?.discovering ?? false) ? qsTr("Scanning for devices…") : qsTr("No devices yet · tap refresh")
                        color: Colours.palette.m3onSurfaceVariant
                        font.weight: Font.Normal
                        textPointSize: Tokens.font.size.normal
                    }
                }
            }

            Repeater {
                model: root.btDevices
                delegate: Item {
                    id: btDev
                    required property var modelData
                    readonly property bool isConnecting: {
                        const s = modelData.state;
                        return s === BluetoothDeviceState.Connecting || s === BluetoothDeviceState.Disconnecting;
                    }
                    readonly property bool isConnected: modelData.connected && !btDev.isConnecting
                    readonly property real textOpacity: isConnecting ? 0.7 : 1

                    width: parent ? parent.width : 0
                    height: btRow.implicitHeight + Tokens.padding.large * 2

                    RowLayout {
                        id: btRow
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.normal
                        anchors.rightMargin: Tokens.padding.normal
                        anchors.topMargin: Tokens.padding.normal
                        anchors.bottomMargin: Tokens.padding.normal
                        spacing: Tokens.spacing.normal

                        MaterialIcon {
                            text: Icons.getBluetoothIcon(btDev.modelData.icon || "")
                            color: btDev.isConnected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            iconPointSize: Tokens.font.size.large
                            opacity: btDev.textOpacity
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            opacity: btDev.textOpacity

                            StyledText {
                                Layout.fillWidth: true
                                text: btDev.modelData.name || btDev.modelData.address || qsTr("Unknown device")
                                elide: Text.ElideRight
                                font.weight: Font.Normal
                                color: btDev.isConnected ? Colours.palette.m3primary : Colours.palette.m3onSurface
                                textPointSize: Tokens.font.size.normal
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: {
                                    if (btDev.modelData.paired || btDev.modelData.bonded) return qsTr("Paired");
                                    return qsTr("Nearby");
                                }
                                elide: Text.ElideRight
                                color: Colours.palette.m3onSurfaceVariant
                                font.weight: Font.Normal
                                textPointSize: Tokens.font.size.small
                            }
                        }

                        StyledRect {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: btPillRow.implicitWidth + Tokens.padding.normal * 2
                            implicitHeight: 26
                            radius: height / 2
                            color: {
                                if (btDev.isConnecting) return Qt.alpha(Colours.palette.m3primary, 0.16);
                                if (btDev.isConnected) return Colours.palette.m3primaryContainer;
                                return Colours.palette.m3surfaceContainerHighest;
                            }

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

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Qt.alpha(Colours.palette.m3outlineVariant, 0.35)
                    }
                }
            }
        }
    }
}
