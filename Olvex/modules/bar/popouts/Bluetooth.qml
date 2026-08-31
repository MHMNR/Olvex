import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.settings
import "../../../components/containers"

ColumnLayout {
    id: root

    required property PopoutState popouts

    readonly property bool btEnabled: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
    readonly property bool discovering: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.discovering : false
    readonly property var allDevices: (Bluetooth.devices && Bluetooth.devices.values) ? Bluetooth.devices.values : []
    readonly property var connectedDevices: allDevices.filter(d => d.connected)
    readonly property var pairedDevices: allDevices.filter(d => d.paired && !d.connected)
    readonly property var otherDevices: allDevices.filter(d => !d.paired && !d.connected)

    spacing: Tokens.spacing.normal
    Layout.fillWidth: true
    implicitWidth: parent ? parent.width : 340

    // ── Bluetooth Disabled State ─────────────────────────────────────────────
    StyledRect {
        id: offStateCard
        visible: !root.btEnabled
        Layout.fillWidth: true
        Layout.preferredHeight: 160
        radius: Tokens.rounding.large
        color: Colours.layer(Colours.palette.m3surfaceContainer, 1)

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Tokens.spacing.normal

            StyledRect {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 52
                implicitHeight: 52
                radius: Tokens.rounding.full
                color: Qt.alpha(Colours.palette.m3onSurface, 0.08)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "bluetooth_disabled"
                    iconPointSize: Tokens.font.size.large
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 2

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Bluetooth is turned off")
                    font.weight: Font.DemiBold
                    textPointSize: Tokens.font.size.normal
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Turn on Bluetooth to connect devices")
                    textPointSize: Tokens.font.size.smaller
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            IconTextButton {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Turn on Bluetooth")
                icon: "bluetooth"
                inactiveColour: Colours.palette.m3primary
                inactiveOnColour: Colours.palette.m3onPrimary
                onClicked: {
                    const a = Bluetooth.defaultAdapter;
                    if (a) a.enabled = true;
                }
            }
        }
    }

    // ── Bluetooth Enabled View ───────────────────────────────────────────────
    ColumnLayout {
        id: btContainer
        visible: root.btEnabled
        Layout.fillWidth: true
        spacing: Tokens.spacing.normal

        // ── Connected Devices Section ────────────────────────────────────────
        ColumnLayout {
            visible: root.connectedDevices.length > 0
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            StyledText {
                text: qsTr("Connected")
                textPointSize: Tokens.font.size.smaller
                font.weight: Font.DemiBold
                color: Colours.palette.m3secondary
                Layout.leftMargin: Tokens.padding.small
            }

            Repeater {
                model: root.connectedDevices

                StyledRect {
                    id: connectedCard
                    required property BluetoothDevice modelData
                    required property int index

                    Layout.fillWidth: true
                    implicitHeight: 64
                    radius: Tokens.rounding.normal
                    color: Colours.palette.m3secondaryContainer

                    readonly property bool loading: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.normal
                        anchors.rightMargin: Tokens.padding.normal
                        spacing: Tokens.spacing.normal

                        // Device Type Icon Badge
                        StyledRect {
                            implicitWidth: 40
                            implicitHeight: 40
                            radius: Tokens.rounding.small
                            color: Colours.palette.m3secondary

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: Icons.getBluetoothIcon(connectedCard.modelData.icon)
                                color: Colours.palette.m3onSecondary
                                iconPointSize: Tokens.font.size.normal
                            }
                        }

                        // Device Name & Status
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: connectedCard.modelData.name || qsTr("Unknown Device")
                                font.weight: Font.DemiBold
                                textPointSize: Tokens.font.size.normal
                                color: Colours.palette.m3onSecondaryContainer
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                spacing: Tokens.spacing.extraSmall

                                StyledText {
                                    text: qsTr("Connected")
                                    textPointSize: Tokens.font.size.smaller
                                    color: Qt.alpha(Colours.palette.m3onSecondaryContainer, 0.8)
                                }

                                StyledText {
                                    visible: connectedCard.modelData.batteryAvailable
                                    text: "•"
                                    textPointSize: Tokens.font.size.smaller
                                    color: Qt.alpha(Colours.palette.m3onSecondaryContainer, 0.5)
                                }

                                MaterialIcon {
                                    visible: connectedCard.modelData.batteryAvailable
                                    text: Icons.getBatteryIcon(connectedCard.modelData.batteryAvailable ? connectedCard.modelData.battery * 100 : -1)
                                    iconPointSize: Tokens.font.size.smaller
                                    color: connectedCard.modelData.battery < 0.2 ? Colours.palette.m3error : Qt.alpha(Colours.palette.m3onSecondaryContainer, 0.8)
                                }

                                StyledText {
                                    visible: connectedCard.modelData.batteryAvailable
                                    text: `${Math.round(connectedCard.modelData.battery * 100)}%`
                                    textPointSize: Tokens.font.size.smaller
                                    color: Qt.alpha(Colours.palette.m3onSecondaryContainer, 0.8)
                                }
                            }
                        }

                        // Disconnect Button / Loading Indicator
                        StyledRect {
                            implicitWidth: 36
                            implicitHeight: 36
                            radius: Tokens.rounding.full
                            color: Qt.alpha(Colours.palette.m3onSecondaryContainer, 0.12)

                            LoadingIndicator {
                                anchors.centerIn: parent
                                implicitSize: 22
                                color: Colours.palette.m3onSecondaryContainer
                                animated: connectedCard.loading
                                opacity: connectedCard.loading ? 1 : 0
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                visible: !connectedCard.loading
                                text: "link_off"
                                color: Colours.palette.m3onSecondaryContainer
                                iconPointSize: Tokens.font.size.normal
                            }

                            StateLayer {
                                anchors.fill: parent
                                color: Colours.palette.m3onSecondaryContainer
                                disabled: connectedCard.loading
                                onClicked: connectedCard.modelData.connected = false
                            }
                        }
                    }
                }
            }
        }

        // ── Paired & Available Devices Header ────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.rightMargin: Tokens.padding.small
            spacing: Tokens.spacing.small

            StyledText {
                text: root.pairedDevices.length > 0 ? qsTr("Paired Devices") : qsTr("Available Devices")
                textPointSize: Tokens.font.size.smaller
                font.weight: Font.DemiBold
                color: Colours.palette.m3onSurfaceVariant
                Layout.fillWidth: true
            }

            // Count badge
            StyledRect {
                implicitWidth: btCountText.implicitWidth + 12
                implicitHeight: 20
                radius: Tokens.rounding.full
                color: Qt.alpha(Colours.palette.m3onSurface, 0.08)

                StyledText {
                    id: btCountText
                    anchors.centerIn: parent
                    text: `${root.allDevices.length}`
                    textPointSize: Tokens.font.size.smaller - 2
                    font.weight: Font.Medium
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }

        // ── Devices Scrollable List ──────────────────────────────────────────
        StyledFlickable {
            id: btScroll
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(btContent.implicitHeight, 300)
            contentHeight: btContent.implicitHeight
            flickableDirection: Flickable.VerticalFlick
            clip: true
            smoothWheel: true

            ScrollBar.vertical: ScrollBar {
                policy: btContent.implicitHeight > btScroll.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            ColumnLayout {
                id: btContent
                width: btScroll.width
                spacing: Tokens.spacing.small

                // Paired (but not currently connected) devices
                Repeater {
                    model: root.pairedDevices

                    StyledRect {
                        id: pairedItem
                        required property BluetoothDevice modelData
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: 52
                        radius: Tokens.rounding.normal
                        color: Colours.layer(Colours.palette.m3surfaceContainer, 1)

                        readonly property bool loading: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.padding.normal
                            anchors.rightMargin: Tokens.padding.normal
                            spacing: Tokens.spacing.normal

                            // Device Icon container
                            StyledRect {
                                implicitWidth: 34
                                implicitHeight: 34
                                radius: Tokens.rounding.small
                                color: Qt.alpha(Colours.palette.m3primary, 0.10)

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: Icons.getBluetoothIcon(pairedItem.modelData.icon)
                                    color: Colours.palette.m3primary
                                    iconPointSize: Tokens.font.size.normal
                                }
                            }

                            // Device Name & Status
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    Layout.fillWidth: true
                                    text: pairedItem.modelData.name || qsTr("Unknown Device")
                                    font.weight: Font.Medium
                                    textPointSize: Tokens.font.size.small
                                    color: Colours.palette.m3onSurface
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    text: qsTr("Paired")
                                    textPointSize: Tokens.font.size.smaller - 1
                                    color: Colours.palette.m3onSurfaceVariant
                                }
                            }

                            // Action Buttons
                            RowLayout {
                                spacing: Tokens.spacing.extraSmall

                                // Forget Button
                                StyledRect {
                                    visible: pairedItem.modelData.bonded
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    radius: Tokens.rounding.full
                                    color: "transparent"

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: "delete"
                                        color: Colours.palette.m3onSurfaceVariant
                                        iconPointSize: Tokens.font.size.small
                                    }

                                    StateLayer {
                                        anchors.fill: parent
                                        color: Colours.palette.m3error
                                        onClicked: pairedItem.modelData.forget()
                                    }
                                }

                                // Connect Action Button
                                StyledRect {
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    radius: Tokens.rounding.full
                                    color: Qt.alpha(Colours.palette.m3primary, 0.12)

                                    LoadingIndicator {
                                        anchors.centerIn: parent
                                        implicitSize: 20
                                        color: Colours.palette.m3primary
                                        animated: pairedItem.loading
                                        opacity: pairedItem.loading ? 1 : 0
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        visible: !pairedItem.loading
                                        text: "link"
                                        color: Colours.palette.m3primary
                                        iconPointSize: Tokens.font.size.normal
                                    }

                                    StateLayer {
                                        anchors.fill: parent
                                        color: Colours.palette.m3primary
                                        disabled: pairedItem.loading
                                        onClicked: pairedItem.modelData.connected = true
                                    }
                                }
                            }
                        }

                        StateLayer {
                            anchors.fill: parent
                            color: Colours.palette.m3onSurface
                            preventStealing: false
                            disabled: pairedItem.loading
                            onClicked: pairedItem.modelData.connected = true
                        }
                    }
                }

                // Other / Discovered Devices
                Repeater {
                    model: root.otherDevices

                    StyledRect {
                        id: otherItem
                        required property BluetoothDevice modelData
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: 52
                        radius: Tokens.rounding.normal
                        color: Colours.layer(Colours.palette.m3surfaceContainer, 1)

                        readonly property bool loading: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.padding.normal
                            anchors.rightMargin: Tokens.padding.normal
                            spacing: Tokens.spacing.normal

                            StyledRect {
                                implicitWidth: 34
                                implicitHeight: 34
                                radius: Tokens.rounding.small
                                color: Qt.alpha(Colours.palette.m3onSurface, 0.08)

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: Icons.getBluetoothIcon(otherItem.modelData.icon)
                                    color: Colours.palette.m3onSurfaceVariant
                                    iconPointSize: Tokens.font.size.normal
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    Layout.fillWidth: true
                                    text: otherItem.modelData.name || otherItem.modelData.address || qsTr("Unknown Device")
                                    font.weight: Font.Medium
                                    textPointSize: Tokens.font.size.small
                                    color: Colours.palette.m3onSurface
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    text: qsTr("Available")
                                    textPointSize: Tokens.font.size.smaller - 1
                                    color: Colours.palette.m3onSurfaceVariant
                                }
                            }

                            // Pair Button
                            StyledRect {
                                implicitWidth: 32
                                implicitHeight: 32
                                radius: Tokens.rounding.full
                                color: Qt.alpha(Colours.palette.m3primary, 0.12)

                                LoadingIndicator {
                                    anchors.centerIn: parent
                                    implicitSize: 20
                                    color: Colours.palette.m3primary
                                    animated: otherItem.loading
                                    opacity: otherItem.loading ? 1 : 0
                                }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    visible: !otherItem.loading
                                    text: "add_link"
                                    color: Colours.palette.m3primary
                                    iconPointSize: Tokens.font.size.normal
                                }

                                StateLayer {
                                    anchors.fill: parent
                                    color: Colours.palette.m3primary
                                    disabled: otherItem.loading
                                    onClicked: otherItem.modelData.connected = true
                                }
                            }
                        }

                        StateLayer {
                            anchors.fill: parent
                            color: Colours.palette.m3onSurface
                            preventStealing: false
                            disabled: otherItem.loading
                            onClicked: otherItem.modelData.connected = true
                        }
                    }
                }

                // Empty state when no paired/discovered devices
                StyledRect {
                    visible: root.allDevices.length === 0
                    Layout.fillWidth: true
                    implicitHeight: 96
                    radius: Tokens.rounding.normal
                    color: Qt.alpha(Colours.palette.m3onSurface, 0.04)

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.normal

                        LoadingIndicator {
                            Layout.alignment: Qt.AlignHCenter
                            implicitSize: 36
                            color: Colours.palette.m3primary
                            animated: root.discovering
                            opacity: root.discovering ? 1 : 0.45
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.discovering ? qsTr("Searching for devices…") : qsTr("No devices found · tap to scan")
                            color: Colours.palette.m3onSurfaceVariant
                            textPointSize: Tokens.font.size.small
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const a = Bluetooth.defaultAdapter;
                            if (a && root.btEnabled) a.discovering = true;
                        }
                    }
                }
            }
        }
    }

    // ── Footer: Open Bluetooth Settings ──────────────────────────────────────
    StyledRect {
        Layout.fillWidth: true
        implicitHeight: 46
        radius: Tokens.rounding.normal
        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.normal
            anchors.rightMargin: Tokens.padding.normal
            spacing: Tokens.spacing.normal

            MaterialIcon {
                text: "settings"
                color: Colours.palette.m3primary
                iconPointSize: Tokens.font.size.normal
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("More Bluetooth settings")
                font.weight: Font.Medium
                textPointSize: Tokens.font.size.small
                color: Colours.palette.m3onSurface
            }

            MaterialIcon {
                text: "chevron_right"
                color: Colours.palette.m3onSurfaceVariant
                iconPointSize: Tokens.font.size.normal
            }
        }

        StateLayer {
            anchors.fill: parent
            color: Colours.palette.m3onSurface
            onClicked: {
                root.popouts.hasCurrent = false;
                const activeScr = Visibilities.getForActive();
                if (activeScr) activeScr.qspanel = false;
                WindowFactory.create(null, {
                    active: "network",
                    activeSection: "bluetooth"
                });
            }
        }
    }
}
