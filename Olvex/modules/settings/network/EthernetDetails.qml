import QtQuick
import QtQuick.Layouts
import Quickshell
import Olvex
import Olvex.Config
import qs.services
import ".."
import "../ui"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"

Item {
    id: root

    property Session session
    readonly property var ethernetDevice: root.session && root.session.ethernet ? root.session.ethernet.active : null

    property bool isManual: false
    property string staticIpAddress: "192.168.1.100"
    property string staticSubnet: "255.255.255.0"
    property string staticGateway: "192.168.1.1"
    property string primaryDns: "8.8.8.8"
    property string secondaryDns: "8.8.4.4"

    signal autoConnectChanged(bool enabled)
    signal ipAssignmentModeChanged(string mode)
    signal staticIpConfigChanged(var config)
    
    function copyMacToClipboard() {
        const mac = (Nmcli.ethernetDeviceDetails && (Nmcli.ethernetDeviceDetails.macAddress || Nmcli.ethernetDeviceDetails.hwAddress)) || "";
        if (mac) {
            Quickshell.execDetached(["wl-copy", mac]);
            Toaster.toast(qsTr("MAC Address Copied"), mac, "content_copy");
        }
    }

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    onEthernetDeviceChanged: {
        if (root.ethernetDevice && root.ethernetDevice.interface) {
            Nmcli.getEthernetDeviceDetails(root.ethernetDevice.interface, () => {});
        } else {
            Nmcli.ethernetDeviceDetails = null;
        }
    }

    ParallelAnimation {
        id: animateEntry
        NumberAnimation {
            target: root
            property: "opacity"
            from: 0
            to: 1
            duration: Tokens.anim.durations.large
            easing.type: Easing.OutCubic
        }
    }

    onSessionChanged: {
        if (root.session && !root.session.ethernet.active && Nmcli.ethernetDevices.length > 0) {
            root.session.ethernet.active = Nmcli.ethernetDevices[0];
        }
        if (root.ethernetDevice && root.ethernetDevice.interface) {
            Nmcli.getEthernetDeviceDetails(root.ethernetDevice.interface, () => {});
        }
        animateEntry.restart();
    }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Tokens.spacing.large

        // ── Connection Status ───────────────────────────────────────────────
        Section {
            title: qsTr("Connection Status")
            description: qsTr("Wired network interface and speed")
            icon: "cable"
            accentColor: Colours.palette.m3primary

            SettingRow {
                Layout.fillWidth: true
                title: (root.ethernetDevice && root.ethernetDevice.interface) || qsTr("Unknown Interface")
                description: {
                    if (root.ethernetDevice && root.ethernetDevice.connected) {
                        return root.ethernetDevice.connection || qsTr("Connected · 1000 Mbps, Full Duplex");
                    }
                    return qsTr("Disconnected");
                }
                StyledSwitch {
                    checked: (root.ethernetDevice && root.ethernetDevice.connected) || false
                    onToggled: {
                        if (checked) {
                            Nmcli.connectEthernet((root.ethernetDevice && root.ethernetDevice.connection) || "", (root.ethernetDevice && root.ethernetDevice.interface) || "", () => {});
                        } else {
                            if (root.ethernetDevice && root.ethernetDevice.connection) {
                                Nmcli.disconnectEthernet(root.ethernetDevice.connection, () => {});
                            }
                        }
                    }
                }
            }
        }

        // ── IP Configuration ────────────────────────────────────────────────
        Section {
            title: qsTr("IP Configuration")
            description: qsTr("DHCP and static network addressing")
            icon: "dns"
            accentColor: Colours.palette.m3primary

            SettingRow {
                Layout.fillWidth: true
                title: qsTr("IP Assignment")
                description: root.isManual ? qsTr("Manual (Static address)") : qsTr("DHCP (Automatic from router)")

                Segmented {
                    Layout.preferredWidth: 200
                    minSegmentWidth: 80
                    model: [
                        { label: qsTr("DHCP") },
                        { label: qsTr("Manual") }
                    ]
                    currentIndex: root.isManual ? 1 : 0
                    onSelected: i => {
                        root.isManual = (i === 1);
                        root.ipAssignmentModeChanged(root.isManual ? "Manual" : "DHCP");
                    }
                }
            }

            SettingRow {
                Layout.fillWidth: true
                visible: root.isManual
                title: qsTr("IP Address")
                description: qsTr("Static IPv4 host address")
                StyledTextField {
                    width: Math.max(180, Math.round(contentWidth + leftPadding + rightPadding + 16))
                    text: root.staticIpAddress
                    font.family: Tokens.font.family.mono || "monospace"
                    onTextChanged: root.staticIpAddress = text
                }
            }

            SettingRow {
                Layout.fillWidth: true
                visible: root.isManual
                title: qsTr("Subnet Mask")
                description: qsTr("Network subnet bitmask")
                StyledTextField {
                    width: Math.max(180, Math.round(contentWidth + leftPadding + rightPadding + 16))
                    text: root.staticSubnet
                    font.family: Tokens.font.family.mono || "monospace"
                    onTextChanged: root.staticSubnet = text
                }
            }

            SettingRow {
                Layout.fillWidth: true
                visible: root.isManual
                title: qsTr("Gateway")
                description: qsTr("Default router IPv4 gateway")
                StyledTextField {
                    width: Math.max(180, Math.round(contentWidth + leftPadding + rightPadding + 16))
                    text: root.staticGateway
                    font.family: Tokens.font.family.mono || "monospace"
                    onTextChanged: root.staticGateway = text
                }
            }

            SettingRow {
                Layout.fillWidth: true
                visible: root.isManual
                title: qsTr("DNS Servers")
                description: qsTr("Primary & secondary name resolvers")
                Row {
                    spacing: Tokens.spacing.small
                    StyledTextField {
                        width: Math.max(115, Math.round(contentWidth + leftPadding + rightPadding + 16))
                        text: root.primaryDns
                        placeholderText: "8.8.8.8"
                        font.family: Tokens.font.family.mono || "monospace"
                        onTextChanged: root.primaryDns = text
                    }
                    StyledTextField {
                        width: Math.max(115, Math.round(contentWidth + leftPadding + rightPadding + 16))
                        text: root.secondaryDns
                        placeholderText: "8.8.4.4"
                        font.family: Tokens.font.family.mono || "monospace"
                        onTextChanged: root.secondaryDns = text
                    }
                }
            }

            SettingRow {
                Layout.fillWidth: true
                visible: root.isManual
                title: qsTr("Apply Changes")
                description: qsTr("Save static network configuration to interface")
                StyledRect {
                    implicitWidth: saveLbl.implicitWidth + Tokens.padding.large * 2
                    implicitHeight: 36
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3primary

                    StyledText {
                        id: saveLbl
                        anchors.centerIn: parent
                        text: qsTr("Save Config")
                        color: Colours.palette.m3onPrimary
                        font.weight: Font.Medium
                        textPointSize: Tokens.font.size.small
                    }

                    StateLayer {
                        radius: parent.radius
                        color: Colours.palette.m3onPrimary
                        onClicked: {
                            root.staticIpConfigChanged({
                                ip: root.staticIpAddress,
                                subnet: root.staticSubnet,
                                gateway: root.staticGateway,
                                dns1: root.primaryDns,
                                dns2: root.secondaryDns
                            });
                        }
                    }
                }
            }
        }

        // ── Hardware Information ────────────────────────────────────────────
        Section {
            title: qsTr("Hardware Information")
            description: qsTr("Physical controller details and MAC address")
            icon: "memory"
            accentColor: Colours.palette.m3primary

            SettingRow {
                Layout.fillWidth: true
                title: qsTr("MAC Address")
                description: (Nmcli.ethernetDeviceDetails && (Nmcli.ethernetDeviceDetails.macAddress || Nmcli.ethernetDeviceDetails.hwAddress)) || "00:00:00:00:00:00"

                IconButton {
                    id: copyMacBtn
                    type: IconButton.Tonal
                    icon: copiedTimer.running ? "check" : "content_copy"

                    Timer {
                        id: copiedTimer
                        interval: 1500
                    }

                    onClicked: {
                        root.copyMacToClipboard();
                        copiedTimer.restart();
                    }
                }
            }
        }
    }
}
