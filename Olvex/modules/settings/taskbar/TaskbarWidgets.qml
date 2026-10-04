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

    property Session session
    spacing: Tokens.spacing.large

    // Inline component MUST be at root level (QML spec)
    component StatusChip : StyledRect {
        id: chip
        required property string labelText
        required property string iconText
        required property bool isChecked
        signal toggled()

        implicitWidth: content.implicitWidth + Tokens.padding.large * 2
        implicitHeight: 34
        radius: height / 2
        color: isChecked ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest

        Behavior on color { CAnim {} }

        Row {
            id: content
            anchors.centerIn: parent
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.iconText
                iconPointSize: Tokens.font.size.normal
                color: chip.isChecked ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                
                Behavior on color { CAnim {} }
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.labelText
                color: chip.isChecked ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                font.weight: chip.isChecked ? Font.Medium : Font.Normal
                textPointSize: Tokens.font.size.small

                Behavior on color { CAnim {} }
            }
        }

        StateLayer {
            radius: parent.radius
            color: chip.isChecked ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
            onClicked: chip.toggled()
        }
    }

    Section {
        Layout.fillWidth: true
        title: qsTr("Clock")
        description: qsTr("Time format and display options")
        icon: "schedule"

        SettingRow {
            title: qsTr("Show date")
            description: qsTr("Display current date next to time")
            divider: true
            StyledSwitch {
                checked: Config.bar.clock.showDate ?? false
                onToggled: {
                    GlobalConfig.bar.clock.showDate = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Use 12-hour clock")
            description: qsTr("AM/PM format instead of 24-hour")
            divider: true
            StyledSwitch {
                checked: GlobalConfig.services.useTwelveHourClock ?? false
                onToggled: {
                    GlobalConfig.services.useTwelveHourClock = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Pill background")
            description: qsTr("Show container background behind clock")
            divider: false
            StyledSwitch {
                checked: Config.bar.clock.background ?? false
                onToggled: {
                    GlobalConfig.bar.clock.background = checked;
                    GlobalConfig.save();
                }
            }
        }
    }

    Section {
        Layout.fillWidth: true
        title: qsTr("Status Icons")
        description: qsTr("Toggle indicators shown in the system pill")
        icon: "info"

        SettingRow {
            id: indicatorRow
            title: qsTr("Visible indicators")
            description: qsTr("Select which system icons to display")
            divider: false

            Flow {
                width: Math.max(200, indicatorRow.width * 0.60)
                spacing: Tokens.spacing.small

                StatusChip {
                    labelText: qsTr("Speakers")
                    iconText: "volume_up"
                    isChecked: Config.bar.status.showAudio
                    onToggled: { GlobalConfig.bar.status.showAudio = !Config.bar.status.showAudio; GlobalConfig.save(); }
                }
                StatusChip {
                    labelText: qsTr("Microphone")
                    iconText: "mic"
                    isChecked: Config.bar.status.showMicrophone
                    onToggled: { GlobalConfig.bar.status.showMicrophone = !Config.bar.status.showMicrophone; GlobalConfig.save(); }
                }
                StatusChip {
                    labelText: qsTr("Keyboard")
                    iconText: "keyboard"
                    isChecked: Config.bar.status.showKbLayout
                    onToggled: { GlobalConfig.bar.status.showKbLayout = !Config.bar.status.showKbLayout; GlobalConfig.save(); }
                }
                StatusChip {
                    labelText: qsTr("Network")
                    iconText: "lan"
                    isChecked: Config.bar.status.showNetwork
                    onToggled: { GlobalConfig.bar.status.showNetwork = !Config.bar.status.showNetwork; GlobalConfig.save(); }
                }
                StatusChip {
                    labelText: qsTr("Wifi")
                    iconText: "wifi"
                    isChecked: Config.bar.status.showWifi
                    onToggled: { GlobalConfig.bar.status.showWifi = !Config.bar.status.showWifi; GlobalConfig.save(); }
                }
                StatusChip {
                    labelText: qsTr("Bluetooth")
                    iconText: "bluetooth"
                    isChecked: Config.bar.status.showBluetooth
                    onToggled: { GlobalConfig.bar.status.showBluetooth = !Config.bar.status.showBluetooth; GlobalConfig.save(); }
                }
                StatusChip {
                    labelText: qsTr("Battery")
                    iconText: "battery_charging_full"
                    isChecked: Config.bar.status.showBattery
                    onToggled: { GlobalConfig.bar.status.showBattery = !Config.bar.status.showBattery; GlobalConfig.save(); }
                }
                StatusChip {
                    labelText: qsTr("Capslock")
                    iconText: "keyboard_capslock"
                    isChecked: Config.bar.status.showLockStatus
                    onToggled: { GlobalConfig.bar.status.showLockStatus = !Config.bar.status.showLockStatus; GlobalConfig.save(); }
                }
            }
        }
    }

    Section {
        Layout.fillWidth: true
        title: qsTr("Network Speed")
        description: qsTr("Current download/upload speeds")
        icon: "speed"

        SettingRow {
            title: qsTr("Enabled")
            description: qsTr("Show real-time network activity monitor")
            divider: true
            StyledSwitch {
                checked: (GlobalConfig.bar && GlobalConfig.bar.netSpeed) ? GlobalConfig.bar.netSpeed.enabled : true
                onToggled: {
                    if (GlobalConfig.bar && GlobalConfig.bar.netSpeed) {
                        GlobalConfig.bar.netSpeed.enabled = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Layout mode")
            description: qsTr("Separate upload/download rows or combined single line")
            divider: true
            Segmented {
                model: [qsTr("Separate"), qsTr("Combined")]
                currentIndex: ((GlobalConfig.bar && GlobalConfig.bar.netSpeed && GlobalConfig.bar.netSpeed.mode) || "separate") === "combined" ? 1 : 0
                onSelected: i => {
                    if (GlobalConfig.bar && GlobalConfig.bar.netSpeed) {
                        GlobalConfig.bar.netSpeed.mode = i === 1 ? "combined" : "separate";
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Show icons")
            description: qsTr("Display direction arrows next to speed numbers")
            divider: true
            StyledSwitch {
                checked: (GlobalConfig.bar && GlobalConfig.bar.netSpeed) ? GlobalConfig.bar.netSpeed.showIcons : true
                onToggled: {
                    if (GlobalConfig.bar && GlobalConfig.bar.netSpeed) {
                        GlobalConfig.bar.netSpeed.showIcons = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Pill background")
            description: qsTr("Show container background behind speed")
            divider: true
            StyledSwitch {
                checked: (GlobalConfig.bar && GlobalConfig.bar.netSpeed) ? GlobalConfig.bar.netSpeed.background : false
                onToggled: {
                    if (GlobalConfig.bar && GlobalConfig.bar.netSpeed) {
                        GlobalConfig.bar.netSpeed.background = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Refresh interval (ms)")
            description: qsTr("Update frequency in milliseconds")
            divider: false
            CustomSpinBox {
                value: (GlobalConfig.bar && GlobalConfig.bar.netSpeed) ? GlobalConfig.bar.netSpeed.refreshInterval : 1000
                min: 100
                max: 5000
                step: 100
                onValueModified: v => {
                    if (GlobalConfig.bar && GlobalConfig.bar.netSpeed) {
                        GlobalConfig.bar.netSpeed.refreshInterval = v;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }

    Section {
        Layout.fillWidth: true
        title: qsTr("System Tray")
        description: qsTr("Background third-party app icons")
        icon: "menu"

        SettingRow {
            title: qsTr("Pill background")
            description: qsTr("Show container background behind tray")
            divider: true
            StyledSwitch {
                checked: Config.bar.tray.background ?? false
                onToggled: {
                    GlobalConfig.bar.tray.background = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Compact mode")
            description: qsTr("Reduce spacing between tray icons")
            divider: true
            StyledSwitch {
                checked: Config.bar.tray.compact ?? false
                onToggled: {
                    GlobalConfig.bar.tray.compact = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Recolor icons to theme")
            description: qsTr("Apply M3 color tinting to tray icons")
            divider: false
            StyledSwitch {
                checked: Config.bar.tray.recolour ?? false
                onToggled: {
                    GlobalConfig.bar.tray.recolour = checked;
                    GlobalConfig.save();
                }
            }
        }
    }
}
