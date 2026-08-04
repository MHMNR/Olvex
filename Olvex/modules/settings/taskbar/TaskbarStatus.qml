import ".."
import "../chrome"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    property var session
    spacing: Tokens.spacing.large

    Section {
        Layout.fillWidth: true
        title: qsTr("Popouts")
        description: qsTr("Interactive areas on the bar")
        icon: "ads_click"



        SettingRow {
            title: qsTr("Tray popout")
            description: qsTr("Expand system tray overflow panel")
            divider: true
            StyledSwitch {
                checked: Config.bar.popouts.tray ?? true
                onToggled: {
                    GlobalConfig.bar.popouts.tray = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Status icons popout")
            description: qsTr("Expand status indicators popup")
            divider: false
            StyledSwitch {
                checked: Config.bar.popouts.statusIcons ?? true
                onToggled: {
                    GlobalConfig.bar.popouts.statusIcons = checked;
                    GlobalConfig.save();
                }
            }
        }
    }

    Section {
        Layout.fillWidth: true
        title: qsTr("Status Icons")
        description: qsTr("Toggle indicators shown in the right section")
        icon: "info"

        SettingRow {
            title: qsTr("Visible indicators")
            description: qsTr("Select which system icons to display")
            divider: false

            Flow {
                spacing: Tokens.spacing.normal
                Layout.preferredWidth: 320

                component StatusChip : StyledRect {
                    id: chip
                    required property string labelText
                    required property bool isChecked
                    signal toggled()

                    implicitWidth: lbl.implicitWidth + Tokens.padding.large * 2
                    implicitHeight: 36
                    radius: Tokens.rounding.full
                    color: isChecked ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest

                    StyledText {
                        id: lbl
                        anchors.centerIn: parent
                        text: chip.labelText
                        color: isChecked ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                        font.weight: Font.Medium
                        textPointSize: Tokens.font.size.small
                    }

                    StateLayer {
                        radius: parent.radius
                        onClicked: chip.toggled()
                    }
                }

                StatusChip {
                    labelText: qsTr("Speakers")
                    isChecked: Config.bar.status.showAudio
                    onToggled: { GlobalConfig.bar.status.showAudio = !Config.bar.status.showAudio; GlobalConfig.save(); }
                }
                StatusChip {
                    labelText: qsTr("Microphone")
                    isChecked: Config.bar.status.showMicrophone
                    onToggled: { GlobalConfig.bar.status.showMicrophone = !Config.bar.status.showMicrophone; GlobalConfig.save(); }
                }
                StatusChip {
                    labelText: qsTr("Keyboard")
                    isChecked: Config.bar.status.showKbLayout
                    onToggled: { GlobalConfig.bar.status.showKbLayout = !Config.bar.status.showKbLayout; GlobalConfig.save(); }
                }
                StatusChip {
                    labelText: qsTr("Network")
                    isChecked: Config.bar.status.showNetwork
                    onToggled: { GlobalConfig.bar.status.showNetwork = !Config.bar.status.showNetwork; GlobalConfig.save(); }
                }
                StatusChip {
                    labelText: qsTr("Wifi")
                    isChecked: Config.bar.status.showWifi
                    onToggled: { GlobalConfig.bar.status.showWifi = !Config.bar.status.showWifi; GlobalConfig.save(); }
                }
                StatusChip {
                    labelText: qsTr("Bluetooth")
                    isChecked: Config.bar.status.showBluetooth
                    onToggled: { GlobalConfig.bar.status.showBluetooth = !Config.bar.status.showBluetooth; GlobalConfig.save(); }
                }
                StatusChip {
                    labelText: qsTr("Battery")
                    isChecked: Config.bar.status.showBattery
                    onToggled: { GlobalConfig.bar.status.showBattery = !Config.bar.status.showBattery; GlobalConfig.save(); }
                }
                StatusChip {
                    labelText: qsTr("Capslock")
                    isChecked: Config.bar.status.showLockStatus
                    onToggled: { GlobalConfig.bar.status.showLockStatus = !Config.bar.status.showLockStatus; GlobalConfig.save(); }
                }
            }
        }
    }
}
