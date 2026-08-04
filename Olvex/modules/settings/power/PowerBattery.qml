import ".."
import "../chrome"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    property var session
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

    // Live Battery Status Hero Header Card
    StyledRect {
        id: heroCard
        Layout.fillWidth: true
        implicitHeight: 116
        radius: Tokens.rounding.large
        color: Qt.alpha(Colours.palette.m3primary, 0.12)
        border.color: Qt.alpha(Colours.palette.m3primary, 0.4)
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.large

            // Left Battery Avatar Circle
            StyledRect {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                radius: Tokens.rounding.full
                color: Colours.palette.m3primary

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.isCharging ? "bolt" : (root.battPercent <= 20 ? "battery_saver" : "battery_full")
                    color: Colours.palette.m3onPrimary
                    iconPointSize: 28
                }
            }

            // Middle Info Column with Progress Bar
            ColumnLayout {
                spacing: 6
                Layout.fillWidth: true

                StyledText {
                    text: root.hasBattery ? (root.battPercent + "% — " + (root.isCharging ? qsTr("Charging") : qsTr("On Battery"))) : qsTr("Desktop PC — AC Power")
                    font.weight: Font.Bold
                    textPointSize: Tokens.font.size.large
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    text: root.hasBattery ? (root.isCharging ? qsTr("Connected to external power supply") : qsTr("Running on internal battery power")) : qsTr("No battery system detected")
                    font.weight: Font.Medium
                    textPointSize: Tokens.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                // Battery Level Indicator Bar
                StyledRect {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 340
                    Layout.preferredHeight: 8
                    radius: 4
                    color: Qt.alpha(Colours.palette.m3onSurface, 0.12)

                    StyledRect {
                        width: parent.width * (Math.min(100, Math.max(0, root.battPercent)) / 100)
                        height: parent.height
                        radius: parent.radius
                        color: Colours.palette.m3primary

                        Behavior on width {
                            SpringAnimation { spring: 3.5; damping: 0.74 }
                        }
                    }
                }
            }

            // Right Status Badge Pill
            StyledRect {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 36
                radius: Tokens.rounding.full
                color: Qt.alpha(Colours.palette.m3primary, 0.15)
                border.color: Qt.alpha(Colours.palette.m3primary, 0.35)
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialIcon {
                        text: root.isCharging ? "power" : "battery_saver"
                        color: Colours.palette.m3primary
                        iconPointSize: 16
                    }

                    StyledText {
                        text: root.isCharging ? qsTr("AC Adapter") : qsTr("Discharging")
                        font.weight: Font.SemiBold
                        textPointSize: Tokens.font.size.small
                        color: Colours.palette.m3primary
                    }
                }
            }
        }
    }

    Section {
        id: modeSection
        Layout.fillWidth: true
        title: qsTr("Power Mode")
        description: qsTr("System performance and energy savings profiles")
        icon: "bolt"

        SettingRow {
            title: qsTr("Performance profile")
            description: qsTr("Balance system performance and battery endurance")
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
            divider: false
            StyledSwitch {
                checked: GlobalConfig.general.batterySaverAuto ?? true
                onToggled: {
                    GlobalConfig.general.batterySaverAuto = checked;
                    GlobalConfig.save();
                }
            }
        }
    }

    Section {
        id: protectionSection
        Layout.fillWidth: true
        title: qsTr("Battery Protection & Critical Actions")
        description: qsTr("Automated actions when battery charge drops to critical levels")
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
                checked: GlobalConfig.general.battery.lowWarningEnabled ?? true
                onToggled: {
                    GlobalConfig.general.battery.lowWarningEnabled = checked;
                    GlobalConfig.save();
                }
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
