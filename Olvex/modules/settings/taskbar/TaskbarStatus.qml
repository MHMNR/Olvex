import ".."
import "../chrome"
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

    // Taskbar accent = m3primary (pink/rose)
    readonly property color accent: Colours.palette.m3primary

    // Inline component MUST be at root level (QML spec)
    component StatusChip : StyledRect {
        id: chip
        required property string labelText
        required property bool isChecked
        signal toggled()

        implicitWidth: lbl.implicitWidth + Tokens.padding.large * 2
        implicitHeight: 34
        radius: height / 2
        color: isChecked ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHighest

        Behavior on color { CAnim {} }

        StyledText {
            id: lbl
            anchors.centerIn: parent
            text: chip.labelText
            color: chip.isChecked ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
            font.weight: chip.isChecked ? Font.Medium : Font.Normal
            textPointSize: Tokens.font.size.small

            Behavior on color { CAnim {} }
        }

        StateLayer {
            radius: parent.radius
            color: Colours.palette.m3onPrimaryContainer
            onClicked: chip.toggled()
        }
    }

    Section {
        Layout.fillWidth: true
        title: qsTr("Popouts")
        description: qsTr("Interactive areas on the bar")
        icon: "ads_click"
        accentColor: root.accent

        SettingRow {
            title: qsTr("Active window popout")
            description: qsTr("Expand active window title menu on click")
            descriptionColor: Qt.alpha(root.accent, 0.65)
            divider: true
            StyledSwitch {
                checked: Config.bar.popouts.activeWindow ?? false
                onToggled: {
                    GlobalConfig.bar.popouts.activeWindow = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Tray popout")
            description: qsTr("Expand system tray overflow panel")
            descriptionColor: Qt.alpha(root.accent, 0.65)
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
            descriptionColor: Qt.alpha(root.accent, 0.65)
            divider: false
            StyledSwitch {
                checked: true
            }
        }
    }

    Section {
        Layout.fillWidth: true
        title: qsTr("Status Icons")
        description: qsTr("Toggle indicators shown in the right section")
        icon: "info"
        accentColor: root.accent

        // Chips are in the control slot (right side) — matches SS3 design
        SettingRow {
            title: qsTr("Visible indicators")
            description: qsTr("Select which system icons to display")
            descriptionColor: Qt.alpha(root.accent, 0.65)
            divider: false

            Flow {
                width: 300
                spacing: Tokens.spacing.small

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
