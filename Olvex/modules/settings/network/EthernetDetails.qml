import ".."
import "../chrome"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.services

DeviceDetails {
    id: root

    required property Session session
    readonly property var ethernetDevice: root.session.ethernet.active

    device: ethernetDevice

    Component.onCompleted: {
        if (ethernetDevice && ethernetDevice.interface) {
            Nmcli.getEthernetDeviceDetails(ethernetDevice.interface, () => {});
        }
    }

    onEthernetDeviceChanged: {
        if (ethernetDevice && ethernetDevice.interface) {
            Nmcli.getEthernetDeviceDetails(ethernetDevice.interface, () => {});
        } else {
            Nmcli.ethernetDeviceDetails = null;
        }
    }

    headerComponent: Component {
        ConnectionHeader {
            icon: "cable"
            title: root.ethernetDevice?.interface ?? qsTr("Unknown")
        }
    }

    sections: [
        Component {
            ColumnLayout {
                spacing: Tokens.spacing.normal

                SectionHeader {
                    title: qsTr("Connection status")
                    description: qsTr("Connection settings for this device")
                }

                SectionContainer {
                    ToggleRow {
                        label: qsTr("Connected")
                        checked: root.ethernetDevice?.connected ?? false
                        toggle.onToggled: {
                            if (checked) {
                                Nmcli.connectEthernet(root.ethernetDevice?.connection || "", root.ethernetDevice?.interface || "", () => {});
                            } else {
                                if (root.ethernetDevice?.connection) {
                                    Nmcli.disconnectEthernet(root.ethernetDevice.connection, () => {});
                                }
                            }
                        }
                    }
                }
            }
        },
        Component {
            ColumnLayout {
                spacing: Tokens.spacing.normal

                SectionHeader {
                    title: qsTr("Device properties")
                    description: qsTr("Additional information")
                }

                SectionContainer {
                    contentSpacing: Tokens.spacing.small / 2

                    PropertyRow {
                        label: qsTr("Interface")
                        value: root.ethernetDevice?.interface ?? qsTr("Unknown")
                    }

                    PropertyRow {
                        showTopMargin: true
                        label: qsTr("Connection")
                        value: root.ethernetDevice?.connection || qsTr("Not connected")
                    }

                    PropertyRow {
                        showTopMargin: true
                        label: qsTr("State")
                        value: root.ethernetDevice?.state ?? qsTr("Unknown")
                    }
                }
            }
        },
        Component {
            ColumnLayout {
                spacing: Tokens.spacing.normal

                SectionHeader {
                    title: qsTr("Connection information")
                    description: qsTr("Network connection details")
                }

                SectionContainer {
                    ConnectionInfoSection {
                        deviceDetails: Nmcli.ethernetDeviceDetails
                    }
                }
            }
        }
    ]
}
