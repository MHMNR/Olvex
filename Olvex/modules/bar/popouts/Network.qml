
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

ColumnLayout {
    id: root

    required property PopoutState popouts

    property string connectingToSsid: ""
    property string view: "wireless" // "wireless" or "ethernet"
    property var passwordNetwork: null
    property bool showPasswordDialog: false

    spacing: 0
    width: Tokens.sizes.bar.networkWidth

    // Wireless section
    StyledText {
        visible: root.view === "wireless"
        Layout.preferredHeight: visible ? implicitHeight : 0
        Layout.topMargin: 0
        Layout.bottomMargin: Tokens.spacing.small
        Layout.rightMargin: Tokens.padding.small
        text: qsTr("%1 networks available").arg(Nmcli.networks.length)
        color: Colours.palette.m3onSurfaceVariant
        textPointSize: Tokens.font.size.small
    }

    ScrollView {
        id: wifiScroll
        visible: root.view === "wireless"
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(wifiContent.implicitHeight, 350)
        clip: true
        
        ColumnLayout {
            id: wifiContent
            width: wifiScroll.width
            spacing: Tokens.spacing.small

            Repeater {
                model: ScriptModel {
                    values: [...Nmcli.networks].sort((a, b) => {
                        if (a.active !== b.active) return b.active - a.active;
                        return b.strength - a.strength;
                    }).slice(0, 20)
                }

                StyledRect {
                    id: networkItem
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    Layout.rightMargin: Tokens.padding.small
                    radius: Tokens.rounding.large
                    
                    required property Nmcli.AccessPoint modelData
                    readonly property bool isConnecting: root.connectingToSsid === modelData.ssid
                    readonly property bool loading: networkItem.isConnecting

                    color: modelData.active ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.05)
                    border.width: modelData.active ? 0 : 1
                    border.color: Qt.alpha(Colours.palette.m3onSurface, 0.1)

                    visible: modelData.ssid !== ""

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.normal
                        anchors.rightMargin: Tokens.padding.normal
                        spacing: Tokens.spacing.normal

                        Item {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            
                            MaterialIcon {
                                anchors.centerIn: parent
                                text: Icons.getNetworkIcon(networkItem.modelData.strength)
                                color: networkItem.modelData.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                opacity: networkItem.loading ? 0 : 1
                            }

                            CircularIndicator {
                                anchors.fill: parent
                                running: networkItem.loading
                                opacity: networkItem.loading ? 1 : 0
                                fgColour: networkItem.modelData.active ? Colours.palette.m3onPrimary : Colours.palette.m3primary
                            }
                        }

                        MaterialIcon {
                            visible: networkItem.modelData.isSecure
                            text: "lock"
                            iconPointSize: Tokens.font.size.small
                            color: networkItem.modelData.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: networkItem.modelData.ssid
                            elide: Text.ElideRight
                            font.weight: networkItem.modelData.active ? 600 : 400
                            color: networkItem.modelData.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        }

                        MaterialIcon {
                            text: networkItem.modelData.active ? "link_off" : "link"
                            color: networkItem.modelData.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                            opacity: networkItem.loading ? 0 : 0.6
                            iconPointSize: Tokens.font.size.normal
                        }
                    }

                    StateLayer {
                        anchors.fill: parent
                        color: networkItem.modelData.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        disabled: networkItem.loading || !Nmcli.wifiEnabled

                        onClicked: {
                            if (networkItem.modelData.active) {
                                Nmcli.disconnectFromNetwork();
                            } else {
                                root.connectingToSsid = networkItem.modelData.ssid;
                                NetworkConnection.handleConnect(networkItem.modelData, null, network => {
                                    root.passwordNetwork = network;
                                    root.showPasswordDialog = true;
                                    root.popouts.currentName = "wirelesspassword";
                                });
                            }
                        }
                    }
                }
            }
        }
    }

    // Ethernet section
    StyledText {
        visible: root.view === "ethernet"
        Layout.preferredHeight: visible ? implicitHeight : 0
        Layout.topMargin: visible ? Tokens.padding.normal : 0
        Layout.rightMargin: Tokens.padding.small
        text: qsTr("Ethernet")
        font.weight: 500
    }

    ScrollView {
        id: ethScroll
        visible: root.view === "ethernet"
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(ethContent.implicitHeight, 200)
        clip: true

        ColumnLayout {
            id: ethContent
            width: ethScroll.width
            spacing: Tokens.spacing.small

            Repeater {
                model: ScriptModel {
                    values: [...Nmcli.ethernetDevices].sort((a, b) => {
                        if (a.connected !== b.connected) return b.connected - a.connected;
                        return (a.interface || "").localeCompare(b.interface || "");
                    }).slice(0, 8)
                }

                StyledRect {
                    id: ethernetItem
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    Layout.rightMargin: Tokens.padding.small
                    radius: Tokens.rounding.large
                    color: modelData.connected ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.05)
                    
                    required property var modelData

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.normal
                        anchors.rightMargin: Tokens.padding.normal
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: "cable"
                            color: ethernetItem.modelData.connected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: ethernetItem.modelData.interface || qsTr("Unknown")
                            elide: Text.ElideRight
                            font.weight: ethernetItem.modelData.connected ? 600 : 400
                            color: ethernetItem.modelData.connected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        }

                        MaterialIcon {
                            text: ethernetItem.modelData.connected ? "link_off" : "link"
                            color: ethernetItem.modelData.connected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                            opacity: 0.6
                        }
                    }

                    StateLayer {
                        anchors.fill: parent
                        color: ethernetItem.modelData.connected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                    }
                }
            }
        }
    }

    Connections {
        function onActiveChanged(): void {
            if (Nmcli.active && root.connectingToSsid === Nmcli.active.ssid) {
                root.connectingToSsid = "";
                if (root.showPasswordDialog && root.passwordNetwork && Nmcli.active.ssid === root.passwordNetwork.ssid) {
                    root.showPasswordDialog = false;
                    root.passwordNetwork = null;
                    if (root.popouts.currentName === "wirelesspassword") {
                        root.popouts.currentName = "network";
                    }
                }
            }
        }
        target: Nmcli
    }

    Connections {
        function onCurrentNameChanged(): void {
            if (root.popouts.currentName !== "wirelesspassword" && root.showPasswordDialog) {
                root.showPasswordDialog = false;
                root.passwordNetwork = null;
            }
        }
        target: root.popouts
    }
}
