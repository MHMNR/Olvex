pragma ComponentBehavior: Bound

import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Olvex.Config
import qs.services

Item {
    id: root

    property Session session

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
            title: qsTr("Ethernet")
            description: qsTr("Wired connection information")
            icon: "cable"
            divider: true

            Column {
                spacing: Tokens.spacing.extraSmall
                anchors.verticalCenter: parent.verticalCenter
                StyledText {
                    text: qsTr("Total: %1").arg(Nmcli.ethernetDevices.length)
                    color: Colours.palette.m3onSurfaceVariant
                    textPointSize: Tokens.font.size.small
                }
                StyledText {
                    text: qsTr("Connected: %1").arg(Nmcli.ethernetDevices.filter(d => d.connected).length)
                    color: Colours.palette.m3onSurfaceVariant
                    textPointSize: Tokens.font.size.small
                }
            }
        }

        SettingRow {
            Layout.fillWidth: true
            title: qsTr("Wi-Fi")
            description: qsTr("Enable or disable wireless networking")
            icon: "wifi"
            divider: true

            StyledSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: Nmcli.wifiEnabled
                onToggled: {
                    Nmcli.enableWifi(checked);
                }
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: 0
            visible: GlobalConfig.qspanel.vpn.enabled || GlobalConfig.qspanel.vpn.provider.length > 0

            SettingRow {
                title: qsTr("VPN")
                description: qsTr("Virtual private network connection")
                icon: "vpn_key"
                divider: true

                StyledSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: GlobalConfig.qspanel.vpn.enabled
                    onToggled: {
                        GlobalConfig.qspanel.vpn.enabled = checked;
                    }
                }
            }

            SettingRow {
                title: qsTr("VPN Providers")
                description: qsTr("%1 providers configured").arg(GlobalConfig.qspanel.vpn.provider.length)
                divider: true

                TextButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Manage")
                    inactiveColour: Colours.palette.m3secondaryContainer
                    inactiveOnColour: Colours.palette.m3onSecondaryContainer
                    onClicked: vpnSettingsDialog.open()
                }
            }
        }

        SettingRow {
            Layout.fillWidth: true
            title: qsTr("Current Connection")
            description: Nmcli.active ? Nmcli.active.ssid : (Nmcli.activeEthernet ? Nmcli.activeEthernet.interface : qsTr("Not connected"))
            icon: "info"
            divider: false

            Column {
                spacing: Tokens.spacing.extraSmall
                anchors.verticalCenter: parent.verticalCenter
                visible: Nmcli.active !== null

                StyledText {
                    text: qsTr("Strength: %1%").arg(Nmcli.active ? Nmcli.active.strength : 0)
                    color: Colours.palette.m3onSurfaceVariant
                    textPointSize: Tokens.font.size.small
                }
                StyledText {
                    text: qsTr("Security: %1").arg(Nmcli.active ? (Nmcli.active.isSecure ? qsTr("Secured") : qsTr("Open")) : "")
                    color: Colours.palette.m3onSurfaceVariant
                    textPointSize: Tokens.font.size.small
                }
                StyledText {
                    text: qsTr("Freq: %1 MHz").arg(Nmcli.active ? Nmcli.active.frequency : 0)
                    color: Colours.palette.m3onSurfaceVariant
                    textPointSize: Tokens.font.size.small
                }
            }
        }
    }

    Popup {
        id: vpnSettingsDialog

        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(600, parent.width - Tokens.padding.large * 2)
        height: Math.min(700, parent.height - Tokens.padding.large * 2)

        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: StyledRect {
            color: Colours.palette.m3surface
            radius: Tokens.rounding.large
        }

        StyledFlickable {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large * 1.5
            flickableDirection: Flickable.VerticalFlick
            contentHeight: vpnSettingsContent.height
            clip: true

            VpnSettings {
                id: vpnSettingsContent

                anchors.left: parent.left
                anchors.right: parent.right
                session: root.session
            }
        }
    }
}
