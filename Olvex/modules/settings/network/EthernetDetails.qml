import QtQuick
import QtQuick.Layouts
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
    signal copyMacToClipboard()

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    onEthernetDeviceChanged: {
        if (ethernetDevice && ethernetDevice.interface) {
            Nmcli.getEthernetDeviceDetails(ethernetDevice.interface, () => {});
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
            duration: Tokens.anim.durations.long
            easing.type: Easing.OutCubic
        }
    }

    onSessionChanged: {
        if (root.session && !root.session.ethernet.active && Nmcli.ethernetDevices.length > 0) {
            root.session.ethernet.active = Nmcli.ethernetDevices[0];
        }
        if (ethernetDevice && ethernetDevice.interface) {
            Nmcli.getEthernetDeviceDetails(ethernetDevice.interface, () => {});
        }
        animateEntry.restart();
    }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 24

        // Connection State
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                text: qsTr("Connection Status")
                font.family: "Satoshi"
                font.pixelSize: 14
                font.weight: 600
                color: Colours.palette.m3primary
                Layout.leftMargin: 8
            }

            SettingRow {
                Layout.fillWidth: true
                title: root.ethernetDeviceinterface || qsTr("Unknown Interface")
                description: {
                    if (root.ethernetDeviceconnected) {
                        return root.ethernetDeviceconnection || qsTr("Connected - 1000 Mbps, Full Duplex");
                    }
                    return qsTr("Disconnected");
                }
                icon: "cable"
                StyledSwitch {
                    checked: root.ethernetDeviceconnected || false
                    onToggled: {
                        if (checked) {
                            Nmcli.connectEthernet(root.ethernetDeviceconnection || "", root.ethernetDeviceinterface || "", () => {});
                        } else {
                            if (root.ethernetDeviceconnection) {
                                Nmcli.disconnectEthernet(root.ethernetDevice.connection, () => {});
                            }
                        }
                    }
                }
            }
        }

        // IP Configuration
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                text: qsTr("IP Configuration")
                font.family: "Satoshi"
                font.pixelSize: 14
                font.weight: 600
                color: Colours.palette.m3primary
                Layout.leftMargin: 8
            }

            SettingRow {
                Layout.fillWidth: true
                title: qsTr("IP Assignment")
                description: root.isManual ? qsTr("Manual (Static)") : qsTr("DHCP (Automatic)")
                icon: "dns"
                divider: root.isManual
                RowLayout {
                    spacing: 8
                    
                    TextButton {
                        text: qsTr("DHCP")
                        toggle: true
                        checked: !root.isManual
                        activeColour: Colours.palette.m3primaryContainer
                        activeOnColour: Colours.palette.m3onPrimaryContainer
                        inactiveColour: "transparent"
                        onClicked: {
                            root.isManual = false;
                            root.ipAssignmentModeChanged("DHCP");
                        }
                    }
                    TextButton {
                        text: qsTr("Manual")
                        toggle: true
                        checked: root.isManual
                        activeColour: Colours.palette.m3primaryContainer
                        activeOnColour: Colours.palette.m3onPrimaryContainer
                        inactiveColour: "transparent"
                        onClicked: {
                            root.isManual = true;
                            root.ipAssignmentModeChanged("Manual");
                        }
                    }
                }
            }

            // Manual Config Fields
            Item {
                Layout.fillWidth: true
                implicitHeight: root.isManual ? manualFieldsLayout.implicitHeight : 0
                clip: true
                
                Behavior on implicitHeight {
                    NumberAnimation {
                        // Emphasized Curve approximation (0.2, 0, 0, 1) over 400ms
                        duration: 400
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.2, 0, 0, 1]
                    }
                }

                ColumnLayout {
                    id: manualFieldsLayout
                    width: parent.width
                    spacing: 12
                    
                    Item { Layout.preferredHeight: 4 } // Spacer

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        columns: 2
                        rowSpacing: 12
                        columnSpacing: 16
                        
                        StyledText {
                            text: qsTr("IP Address")
                            font.family: "Satoshi"
                            color: Colours.palette.m3onSurfaceVariant
                        }
                        StyledTextField {
                            Layout.fillWidth: true
                            text: root.staticIpAddress
                            font.family: "JetBrains Mono"
                            onTextChanged: root.staticIpAddress = text
                        }
                        
                        StyledText {
                            text: qsTr("Subnet Mask")
                            font.family: "Satoshi"
                            color: Colours.palette.m3onSurfaceVariant
                        }
                        StyledTextField {
                            Layout.fillWidth: true
                            text: root.staticSubnet
                            font.family: "JetBrains Mono"
                            onTextChanged: root.staticSubnet = text
                        }
                        
                        StyledText {
                            text: qsTr("Gateway")
                            font.family: "Satoshi"
                            color: Colours.palette.m3onSurfaceVariant
                        }
                        StyledTextField {
                            Layout.fillWidth: true
                            text: root.staticGateway
                            font.family: "JetBrains Mono"
                            onTextChanged: root.staticGateway = text
                        }
                        
                        StyledText {
                            text: qsTr("Primary DNS")
                            font.family: "Satoshi"
                            color: Colours.palette.m3onSurfaceVariant
                        }
                        StyledTextField {
                            Layout.fillWidth: true
                            text: root.primaryDns
                            font.family: "JetBrains Mono"
                            onTextChanged: root.primaryDns = text
                        }
                        
                        StyledText {
                            text: qsTr("Secondary DNS")
                            font.family: "Satoshi"
                            color: Colours.palette.m3onSurfaceVariant
                        }
                        StyledTextField {
                            Layout.fillWidth: true
                            text: root.secondaryDns
                            font.family: "JetBrains Mono"
                            onTextChanged: root.secondaryDns = text
                        }
                    }
                    
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        Layout.rightMargin: 16
                        
                        ButtonBase {
                            implicitHeight: 36
                            implicitWidth: 100
                            
                            StyledRect {
                                anchors.fill: parent
                                radius: Tokens.rounding.full
                                color: parent.pressed ? Colours.palette.m3primary : (parent.hovered ? Colours.layer(Colours.palette.m3primaryContainer, 1) : Colours.palette.m3primaryContainer)
                                
                                StyledText {
                                    anchors.centerIn: parent
                                    text: qsTr("Save Config")
                                    font.family: "Satoshi"
                                    font.weight: 600
                                    color: Colours.palette.m3onPrimaryContainer
                                }
                                
                                scale: parent.pressed ? 0.96 : (parent.hovered ? 1.02 : 1.0)
                                Behavior on scale {
                                    NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                                }
                            }
                            
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
        }

        // Hardware Section
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                text: qsTr("Hardware Information")
                font.family: "Satoshi"
                font.pixelSize: 14
                font.weight: 600
                color: Colours.palette.m3primary
                Layout.leftMargin: 8
            }

            SettingRow {
                Layout.fillWidth: true
                title: qsTr("MAC Address")
                description: Nmcli.ethernetDeviceDetailshwAddress || "00:00:00:00:00:00"
                icon: "memory"
                divider: false
                
                IconButton {
                    icon: "content_copy"
                    
                    onClicked: {
                        root.copyMacToClipboard();
                    }
                }
            }
        }
    }
}
