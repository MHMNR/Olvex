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
import Olvex.Config
import qs.services

ColumnLayout {
    id: root

    property Session session
    spacing: Tokens.spacing.large
    implicitHeight: hardwareSection.implicitHeight + spacing

    property bool hasLidSwitch: false

    Process {
        id: lidCheckProc
        command: ["sh", "-c", "test -d /proc/acpi/button/lid || grep -qi 'lid' /proc/bus/input/devices 2>/dev/null"]
        running: true
        onExited: exitCode => {
            root.hasLidSwitch = (exitCode === 0);
        }
    }

    function idxOf(list, val) {
        for (let i = 0; i < list.length; i++) {
            if (list[i] === val) return i;
        }
        return 0;
    }

    Section {
        id: hardwareSection
        Layout.fillWidth: true
        title: root.hasLidSwitch ? qsTr("Hardware Controls & Lid Actions") : qsTr("Hardware Button Actions")
        description: root.hasLidSwitch ? qsTr("System reaction when closing laptop lid or pressing physical buttons") : qsTr("System reaction when pressing physical hardware buttons")
        icon: "power_settings_new"
        accentColor: Colours.palette.m3secondary

        SettingRow {
            visible: root.hasLidSwitch
            title: qsTr("Laptop lid close action")
            description: qsTr("Action executed when closing the laptop lid")
            divider: true
            OptionPicker {
                id: lidPicker
                model: [qsTr("Suspend"), qsTr("Lock screen"), qsTr("Turn off screen"), qsTr("Do nothing")]
                currentIndex: 0
            }
        }

        SettingRow {
            title: qsTr("Power button action")
            description: qsTr("Action executed when physical power button is pressed")
            divider: false
            OptionPicker {
                id: pwrBtnPicker
                model: [qsTr("Show power menu"), qsTr("Suspend"), qsTr("Shutdown"), qsTr("Do nothing")]
                currentIndex: 0
            }
        }
    }
}
