import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Olvex.Config
import qs.services

ColumnLayout {
    id: root

    property Session session
    spacing: Tokens.spacing.large
    implicitHeight: heroCard.implicitHeight + modeSection.implicitHeight + protectionSection.implicitHeight + (spacing * 2)

    readonly property bool hasBattery: UPower.displayDevice && UPower.displayDevice.isPresent
    readonly property real battPercent: hasBattery ? Math.round(UPower.displayDevice.percentage * 100) : 100
    readonly property bool isCharging: hasBattery && !UPower.onBattery

    property int activePowerProfile: 1

    Process {
        id: getProfileProc
        command: ["powerprofilesctl", "get"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const p = String(text).trim();
                if (p === "power-saver") root.activePowerProfile = 0;
                else if (p === "performance") root.activePowerProfile = 2;
                else root.activePowerProfile = 1;
            }
        }
    }

    function setPowerProfile(index: int) {
        root.activePowerProfile = index;
        GlobalConfig.general.powerProfile = index;
        GlobalConfig.save();
        const profiles = ["power-saver", "balanced", "performance"];
        Quickshell.execDetached(["powerprofilesctl", "set", profiles[index]]);
    }

    // Live Battery Status Hero Card (Matches Screenshot)
    StyledRect {
        id: heroCard
        Layout.fillWidth: true
        implicitHeight: 96
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainerHigh
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.large

            // Left Battery Icon
            MaterialIcon {
                text: root.isCharging ? "bolt" : (root.battPercent <= 20 ? "battery_saver" : "battery_full")
                color: Colours.palette.m3onSurfaceVariant
                iconPointSize: 24
                Layout.leftMargin: Tokens.padding.small
            }

            // Middle Info Column
            ColumnLayout {
                spacing: 4
                Layout.fillWidth: true

                StyledText {
                    text: root.hasBattery ? (root.battPercent + "% — " + (root.isCharging ? qsTr("Charging") : qsTr("On Battery"))) : qsTr("Desktop PC — AC Power")
                    font.weight: Font.Bold
                    textPointSize: Tokens.font.size.normal
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    text: root.hasBattery ? (root.isCharging ? qsTr("Connected to external power supply") : qsTr("Running on internal battery power")) : qsTr("No battery system detected")
                    font.weight: Font.Normal
                    textPointSize: Tokens.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            // Right Status Text Pill (Matches Screenshot)
            StyledText {
                text: root.isCharging ? qsTr("AC Adapter") : qsTr("Discharging")
                font.weight: Font.Normal
                textPointSize: Tokens.font.size.small
                color: Colours.palette.m3onSurfaceVariant
                Layout.rightMargin: Tokens.padding.small
            }
        }
    }

    Section {
        id: modeSection
        Layout.fillWidth: true
        title: qsTr("Power Mode")
        description: qsTr("System performance and energy savings profiles")
        icon: "bolt"
        accentColor: Colours.palette.m3secondary

        SettingRow {
            title: qsTr("Energy profile")
            description: qsTr("Balance system performance and battery endurance")
            descriptionColor: Qt.alpha(Colours.palette.m3secondary, 0.65)
            divider: true
            
            Segmented {
                Layout.preferredWidth: 320
                minSegmentWidth: 90
                model: [
                    { label: qsTr("Saver"), icon: "energy_savings_leaf" },
                    { label: qsTr("Balanced"), icon: "balance" },
                    { label: qsTr("Performance"), icon: "speed" }
                ]
                currentIndex: root.activePowerProfile
                onSelected: i => root.setPowerProfile(i)
            }
        }

        SettingRow {
            title: qsTr("Automatic battery saver")
            description: qsTr("Turn on power saver mode when battery drops below 20%")
            descriptionColor: Qt.alpha(Colours.palette.m3secondary, 0.65)
            divider: false
            StyledSwitch {
                checked: true
            }
        }
    }

    Section {
        id: protectionSection
        Layout.fillWidth: true
        title: qsTr("Battery Protection & Critical Actions")
        description: qsTr("Automated actions when battery charge drops to critical levels")
        accentColor: Colours.palette.m3secondary
        icon: "battery_alert"

        SettingRow {
            title: qsTr("Critical battery level (%)")
            description: qsTr("Battery percentage threshold that triggers emergency hibernate")
            divider: true
            CustomSpinBox {
                value: GlobalConfig.general.battery.criticalLevel ?? 3
                min: 1
                max: 30
                step: 1
                onValueModified: v => {
                    GlobalConfig.general.battery.criticalLevel = v;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Low battery warning (20%)")
            description: qsTr("Display notification toast when battery drops to 20%")
            divider: true
            StyledSwitch {
                checked: true
            }
        }

        SettingRow {
            title: qsTr("Charger plug/unplug notification")
            description: qsTr("Show popup toast when AC charger is connected or disconnected")
            divider: false
            StyledSwitch {
                checked: GlobalConfig.qspanel?.toasts?.chargingChanged ?? true
                onToggled: {
                    if (GlobalConfig.qspanel && GlobalConfig.qspanel.toasts) {
                        GlobalConfig.qspanel.toasts.chargingChanged = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }
}
