pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Olvex.Config
import qs.components
import qs.services
import qs.utils

ColumnLayout {
    id: root

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 10
    spacing: 10

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.padding.large
        Layout.bottomMargin: Tokens.padding.small

        StyledRect {
            implicitWidth:  sysIcon.implicitWidth  + 8
            implicitHeight: sysIcon.implicitHeight + 8
            color: Qt.alpha(Colours.palette.m3primary, 0.15)
            radius: Tokens.rounding.small

            MaterialIcon {
                id: sysIcon
                anchors.centerIn: parent
                text: "code"
                color: Colours.palette.m3primary
                font.pointSize: Tokens.font.size.smaller
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: (SysInfo.osPrettyName || SysInfo.osName || qsTr("System")).toUpperCase()
            color: Colours.palette.m3outline
            font.family: Tokens.font.family.mono
            font.pointSize: Tokens.font.size.smaller
            font.weight: 600
        }
    }

    GridLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.padding.large
        columns: 2
        columnSpacing: Tokens.spacing.large
        rowSpacing: Tokens.spacing.small

        MonoText {
            text: "WM:"
            color: Colours.palette.m3primary
            font.pointSize: Tokens.font.size.smaller
        }
        MonoText {
            Layout.fillWidth: true
            text: SysInfo.wm || "Hyprland"
            color: Colours.palette.m3primary
            font.pointSize: Tokens.font.size.smaller
            horizontalAlignment: Text.AlignRight
        }

        MonoText {
            text: "User:"
            color: Colours.palette.m3primary
            font.pointSize: Tokens.font.size.smaller
        }
        MonoText {
            Layout.fillWidth: true
            text: SysInfo.user || "admin"
            color: Colours.palette.m3primary
            font.pointSize: Tokens.font.size.smaller
            horizontalAlignment: Text.AlignRight
        }

        MonoText {
            text: "Up:"
            color: Colours.palette.m3primary
            font.pointSize: Tokens.font.size.smaller
        }
        MonoText {
            Layout.fillWidth: true
            text: SysInfo.uptime || "0m"
            color: Colours.palette.m3primary
            font.pointSize: Tokens.font.size.smaller
            horizontalAlignment: Text.AlignRight
        }

        MonoText {
            text: "Batt:"
            color: Colours.palette.m3primary
            font.pointSize: Tokens.font.size.smaller
        }
        MonoText {
            Layout.fillWidth: true
            text: UPower.displayDevice ? (UPower.displayDevice.state === UPowerDeviceState.Charging ? `${Math.round(UPower.displayDevice.percentage * 100)}% Charging` : `${Math.round(UPower.displayDevice.percentage * 100)}%`) : "AC Power"
            color: Colours.palette.m3primary
            font.pointSize: Tokens.font.size.smaller
            horizontalAlignment: Text.AlignRight
        }
    }

    component MonoText: StyledText {
        font.family: Tokens.font.family.mono
    }
}
