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
    anchors.margins: 14
    spacing: 8

    readonly property string osTitle: {
        const raw = SysInfo.osPrettyName || SysInfo.osName || qsTr("Arch Linux");
        return raw;
    }

    // ── Signature M3 Header Pill ─────────────────────────────────────────────
    StyledRect {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        radius: Tokens.rounding.small
        color: Colours.tileFill

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 3
                Layout.fillHeight: true
                Layout.topMargin: 7
                Layout.bottomMargin: 7
                radius: 1.5
                color: Colours.palette.m3secondary
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: root.osTitle
                color: Colours.palette.m3onSurface
                textPointSize: Tokens.font.size.normal
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                MaterialIcon {
                    text: "person"
                    color: Colours.palette.m3secondary
                    iconPointSize: 12
                }

                StyledText {
                    text: SysInfo.user
                    color: Colours.palette.m3onSurfaceVariant
                    font.family: Tokens.font.family.mono
                    textPointSize: Tokens.font.size.smaller - 2
                    font.weight: Font.Bold
                }
            }
        }
    }

    // ── 2x2 Expressive Tonal Bento Grid ──────────────────────────────────────
    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 6

        InfoTile {
            icon: "desktop_windows"
            label: qsTr("WM")
            value: SysInfo.wm || "Hyprland"
            accent: Colours.palette.m3primary
        }

        InfoTile {
            icon: "terminal"
            label: qsTr("SHELL")
            value: SysInfo.shell || "Fish"
            accent: Colours.palette.m3secondary
        }

        InfoTile {
            icon: "schedule"
            label: qsTr("UPTIME")
            value: SysInfo.uptime || "0m"
            accent: Colours.palette.m3tertiary
            monoValue: true
        }

        InfoTile {
            icon: {
                if (!UPower.displayDevice || !UPower.displayDevice.isLaptopBattery)
                    return "bolt";
                const p = Math.round(UPower.displayDevice.percentage * 100);
                if (UPower.displayDevice.state === UPowerDeviceState.Charging)
                    return "battery_charging_full";
                if (p >= 90) return "battery_full";
                if (p >= 60) return "battery_5_bar";
                if (p >= 30) return "battery_3_bar";
                return "battery_alert";
            }
            label: qsTr("POWER")
            value: UPower.displayDevice && UPower.displayDevice.isLaptopBattery
                ? `${Math.round(UPower.displayDevice.percentage * 100)}%`
                : qsTr("AC")
            accent: Colours.palette.m3primary
            monoValue: true
        }
    }

    component InfoTile: StyledRect {
        id: tile

        required property string icon
        required property string label
        required property string value
        required property color accent
        property bool monoValue: false

        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Tokens.rounding.small
        color: Colours.tileFill

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            StyledRect {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 26
                implicitHeight: 26
                radius: Tokens.rounding.small
                color: Qt.alpha(tile.accent, 0.16)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: tile.icon
                    color: tile.accent
                    iconPointSize: 14
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                StyledText {
                    text: tile.label
                    color: Colours.palette.m3onSurfaceVariant
                    font.family: Tokens.font.family.mono
                    textPointSize: 8
                    font.weight: Font.Bold
                    font.letterSpacing: 0.6
                }

                StyledText {
                    Layout.fillWidth: true
                    text: tile.value
                    color: Colours.palette.m3onSurface
                    font.family: tile.monoValue ? Tokens.font.family.mono : Tokens.font.family.sans
                    textPointSize: Tokens.font.size.smaller
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }
    }
}
