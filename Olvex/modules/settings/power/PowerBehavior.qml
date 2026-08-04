import ".."
import "../chrome"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.controls

ColumnLayout {
    id: root

    property var session
    spacing: Tokens.spacing.large
    implicitHeight: hardwareSection.implicitHeight + spacing

    function idxOf(list, val) {
        for (let i = 0; i < list.length; i++) {
            if (list[i] === val) return i;
        }
        return 0;
    }

    Section {
        id: hardwareSection
        Layout.fillWidth: true
        title: qsTr("Hardware Controls & Lid Actions")
        description: qsTr("System reaction when closing laptop lid or pressing physical buttons")
        icon: "power_settings_new"
        accentColor: Colours.palette.m3secondary

        SettingRow {
            title: qsTr("Laptop lid close action")
            description: qsTr("Action executed when closing the laptop lid")
            divider: true
            OptionPicker {
                id: lidPicker
                model: [qsTr("Suspend"), qsTr("Lock screen"), qsTr("Turn off screen"), qsTr("Do nothing")]
                currentIndex: {
                    const act = GlobalConfig.general.lidAction || "Suspend";
                    return root.idxOf(lidPicker.model, act);
                }
                onSelected: i => {
                    GlobalConfig.general.lidAction = lidPicker.model[i];
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Power button action")
            description: qsTr("Action executed when physical power button is pressed")
            divider: false
            OptionPicker {
                id: pwrBtnPicker
                model: [qsTr("Show power menu"), qsTr("Suspend"), qsTr("Shutdown"), qsTr("Do nothing")]
                currentIndex: {
                    const act = GlobalConfig.general.powerButtonAction || "Show power menu";
                    return root.idxOf(pwrBtnPicker.model, act);
                }
                onSelected: i => {
                    GlobalConfig.general.powerButtonAction = pwrBtnPicker.model[i];
                    GlobalConfig.save();
                }
            }
        }
    }
}
