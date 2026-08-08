
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Olvex.Config
import qs.components
import qs.services
import qs.utils

ColumnLayout {
    id: root

    anchors.fill: parent
    anchors.margins: Tokens.padding.large
    spacing: Tokens.spacing.normal

    // ── Header Chip ───────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        StyledRect {
            implicitWidth: 24
            implicitHeight: 24
            color: Qt.alpha(Colours.palette.m3primary, 0.15)
            radius: Tokens.rounding.small

            MaterialIcon {
                anchors.centerIn: parent
                text: "computer"
                color: Colours.palette.m3primary
                iconPointSize: 14
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: (SysInfo.osPrettyName || SysInfo.osName || qsTr("CACHYOS")).toUpperCase()
            color: Colours.palette.m3outline
            font.family: Tokens.font.family.mono
            textPointSize: Tokens.font.size.smaller
            font.weight: Font.Bold
            font.letterSpacing: 1
            elide: Text.ElideRight
        }
    }

    // ── Grid Stats List ───────────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        // WM Row
        RowLayout {
            Layout.fillWidth: true

            RowLayout {
                spacing: 6
                MaterialIcon {
                    text: "desktop_windows"
                    color: Colours.palette.m3primary
                    iconPointSize: 14
                }
                StyledText {
                    text: "WM"
                    color: Colours.palette.m3outline
                    textPointSize: Tokens.font.size.small
                    font.weight: Font.Medium
                }
            }

            Item { Layout.fillWidth: true }

            StyledText {
                text: SysInfo.wm || "Hyprland"
                color: Colours.palette.m3primary
                textPointSize: Tokens.font.size.small
                font.weight: Font.Bold
            }
        }

        // User Row
        RowLayout {
            Layout.fillWidth: true

            RowLayout {
                spacing: 6
                MaterialIcon {
                    text: "person"
                    color: Colours.palette.m3secondary
                    iconPointSize: 14
                }
                StyledText {
                    text: "User"
                    color: Colours.palette.m3outline
                    textPointSize: Tokens.font.size.small
                    font.weight: Font.Medium
                }
            }

            Item { Layout.fillWidth: true }

            StyledText {
                text: SysInfo.user || "abm"
                color: Colours.palette.m3secondary
                textPointSize: Tokens.font.size.small
                font.weight: Font.Bold
            }
        }

        // Uptime Row
        RowLayout {
            Layout.fillWidth: true

            RowLayout {
                spacing: 6
                MaterialIcon {
                    text: "schedule"
                    color: Colours.palette.m3tertiary
                    iconPointSize: 14
                }
                StyledText {
                    text: "Uptime"
                    color: Colours.palette.m3outline
                    textPointSize: Tokens.font.size.small
                    font.weight: Font.Medium
                }
            }

            Item { Layout.fillWidth: true }

            StyledText {
                text: SysInfo.uptime || "4h 26m"
                color: Colours.palette.m3tertiary
                textPointSize: Tokens.font.size.small
                font.weight: Font.Bold
            }
        }

        // Battery / Power Row
        RowLayout {
            Layout.fillWidth: true

            RowLayout {
                spacing: 6
                MaterialIcon {
                    text: UPower.displayDevice && UPower.displayDevice.state === UPowerDeviceState.Charging ? "battery_charging_full" : "battery_full"
                    color: Colours.palette.m3primary
                    iconPointSize: 14
                }
                StyledText {
                    text: "Power"
                    color: Colours.palette.m3outline
                    textPointSize: Tokens.font.size.small
                    font.weight: Font.Medium
                }
            }

            Item { Layout.fillWidth: true }

            StyledText {
                text: UPower.displayDevice ? (UPower.displayDevice.state === UPowerDeviceState.Charging ? `${Math.round(UPower.displayDevice.percentage * 100)}% ⚡` : `${Math.round(UPower.displayDevice.percentage * 100)}%`) : "AC Power"
                color: Colours.palette.m3primary
                textPointSize: Tokens.font.size.small
                font.weight: Font.Bold
            }
        }
    }
}
