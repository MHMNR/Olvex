pragma ComponentBehavior: Bound

import ".."
import "../chrome"
import QtQuick
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    property Session session
    signal back

    // Idle timeouts are a list of maps: { timeout: seconds, idleAction: string|list }
    function timeoutAt(index: int): int {
        const list = GlobalConfig.general.idle.timeouts || [];
        if (index < 0 || index >= list.length)
            return 0;
        return list[index].timeout ?? list[index]["timeout"] ?? 0;
    }

    function actionAt(index: int): string {
        const list = GlobalConfig.general.idle.timeouts || [];
        if (index < 0 || index >= list.length)
            return "";
        const a = list[index].idleAction ?? list[index]["idleAction"];
        if (typeof a === "string")
            return a;
        if (a && a.length !== undefined) {
            const parts = [];
            for (let i = 0; i < a.length; i++)
                parts.push(String(a[i]));
            return parts.join(" ");
        }
        return String(a || "");
    }

    function updateTimeoutSeconds(index: int, seconds: int): void {
        const list = [];
        const src = GlobalConfig.general.idle.timeouts || [];
        for (let i = 0; i < src.length; i++) {
            const item = Object.assign({}, src[i]);
            if (i === index)
                item.timeout = seconds;
            list.push(item);
        }
        GlobalConfig.general.idle.timeouts = list;
        GlobalConfig.save();
    }

    SettingsPage {
        anchors.fill: parent
        title: qsTr("Power & Idle")
        subtitle: qsTr("Sleep, idle actions and battery")
        icon: "battery_charging_full"
        accent: Colours.palette.m3secondary
        onBack: root.back()

        Section {
            title: qsTr("Idle behavior")
            description: qsTr("What happens after a period of inactivity")
            icon: "bedtime"

            SettingRow {
                title: qsTr("Lock before sleep")
                description: qsTr("Require unlock after the system suspends")
                StyledSwitch {
                    checked: GlobalConfig.general.idle.lockBeforeSleep
                    onToggled: {
                        GlobalConfig.general.idle.lockBeforeSleep = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Stay awake during audio")
                description: qsTr("Don't idle while media is playing")
                StyledSwitch {
                    checked: GlobalConfig.general.idle.inhibitWhenAudio
                    onToggled: {
                        GlobalConfig.general.idle.inhibitWhenAudio = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Keep awake")
                description: qsTr("Manually prevent all idle actions")
                divider: false
                StyledSwitch {
                    checked: GlobalConfig.utilities.keepAwake
                    onToggled: {
                        GlobalConfig.utilities.keepAwake = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            title: qsTr("Idle timeouts")
            description: qsTr("Configured idle actions (seconds)")
            icon: "timer"

            Repeater {
                model: GlobalConfig.general.idle.timeouts || []

                delegate: SettingRow {
                    required property var modelData
                    required property int index

                    title: qsTr("Step %1").arg(index + 1)
                    description: root.actionAt(index) || qsTr("Idle action")
                    divider: index < (GlobalConfig.general.idle.timeouts || []).length - 1
                    CustomSpinBox {
                        value: root.timeoutAt(index)
                        min: 30
                        max: 7200
                        step: 30
                        onValueModified: v => root.updateTimeoutSeconds(index, v)
                    }
                }
            }

            SettingRow {
                visible: !(GlobalConfig.general.idle.timeouts && GlobalConfig.general.idle.timeouts.length)
                title: qsTr("No timeouts")
                description: qsTr("No idle timeouts configured in shell.json")
                divider: false
            }
        }

        Section {
            title: qsTr("Battery")
            description: qsTr("Low-battery warnings")
            icon: "battery_alert"

            SettingRow {
                title: qsTr("Critical level")
                description: qsTr("Warn when the battery drops below this charge")
                divider: false
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
        }
    }
}
