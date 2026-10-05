import ".."
import "../ui"
import "../components"
import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower

SettingsMasterList {
    id: root

    property string activeSection: "battery"

    readonly property bool hasBattery: UPower.displayDevice && UPower.displayDevice.isPresent
    property bool hasLidSwitch: false

    Process {
        command: ["sh", "-c", "test -d /proc/acpi/button/lid || grep -qi 'lid' /proc/bus/input/devices 2>/dev/null"]
        running: true
        onExited: exitCode => {
            root.hasLidSwitch = (exitCode === 0);
        }
    }

    sections: [
        { id: "battery", label: root.hasBattery ? qsTr("Battery & Power") : qsTr("Power & Performance"), icon: root.hasBattery ? "battery_charging_full" : "bolt" },
        { id: "idle", label: qsTr("Idle & Sleep"), icon: "bedtime" },
        { id: "behavior", label: root.hasLidSwitch ? qsTr("Lid & Buttons") : qsTr("Hardware Buttons"), icon: "power_settings_new" }
    ]
}
