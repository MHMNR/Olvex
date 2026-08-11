pragma ComponentBehavior: Bound


import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.services

ColumnLayout {
    id: root

    required property Session session

    spacing: Tokens.spacing.normal

    SettingsHeader {
        icon: "cable"
        title: qsTr("Ethernet settings")
    }

    StyledText {
        Layout.topMargin: Tokens.spacing.large
        text: qsTr("Ethernet devices")
        textPointSize: Tokens.font.size.larger
        font.weight: 400
    }

    StyledText {
        text: qsTr("Available ethernet devices")
        color: Colours.palette.m3outline
    }

    StyledRect {
        Layout.fillWidth: true
        implicitHeight: ethernetInfo.implicitHeight + Tokens.padding.large * 2

        radius: Tokens.rounding.normal
        color: Colours.tPalette.m3surfaceContainer

        ColumnLayout {
            id: ethernetInfo

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Tokens.padding.large

            spacing: Tokens.spacing.small / 2

            StyledText {
                text: qsTr("Total devices")
            }

            StyledText {
                text: qsTr("%1").arg(Nmcli.ethernetDevices.length)
                color: Colours.palette.m3outline
                textPointSize: Tokens.font.size.small
            }

            StyledText {
                Layout.topMargin: Tokens.spacing.normal
                text: qsTr("Connected devices")
            }

            StyledText {
                text: qsTr("%1").arg(Nmcli.ethernetDevices.filter(d => d.connected).length)
                color: Colours.palette.m3outline
                textPointSize: Tokens.font.size.small
            }
        }
    }
}
