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
    implicitHeight: actionsSection.implicitHeight + safeguardsSection.implicitHeight + spacing

    function getTimeoutItem(key: string): var {
        const list = GlobalConfig.general.idle.timeouts || [];
        for (let i = 0; i < list.length; i++) {
            const a = list[i].idleAction;
            const aStr = typeof a === "string" ? a : (a ? a.join(" ") : "");
            if (aStr.includes(key)) return list[i];
        }
        return null;
    }

    function isTimeoutEnabled(key: string): bool {
        const item = getTimeoutItem(key);
        return item ? (item.enabled !== false) : false;
    }

    function getTimeoutMinutes(key: string, defaultMin: int): int {
        const item = getTimeoutItem(key);
        return item ? Math.round((item.timeout || 0) / 60) : defaultMin;
    }

    function updateTimeout(key: string, enabled: bool, minutes: int, defaultAction: var): void {
        const list = (GlobalConfig.general.idle.timeouts || []).map(x => Object.assign({}, x));
        let found = false;
        for (let i = 0; i < list.length; i++) {
            const a = list[i].idleAction;
            const aStr = typeof a === "string" ? a : (a ? a.join(" ") : "");
            if (aStr.includes(key)) {
                list[i].enabled = enabled;
                list[i].timeout = minutes * 60;
                found = true;
                break;
            }
        }
        if (!found) {
            list.push({ idleAction: defaultAction, timeout: minutes * 60, enabled: enabled });
        }
        list.sort((a, b) => (a.timeout || 0) - (b.timeout || 0));
        GlobalConfig.general.idle.timeouts = list;
        GlobalConfig.save();
    }

    Section {
        id: actionsSection
        Layout.fillWidth: true
        title: qsTr("Automated Idle Actions")
        description: qsTr("Configure automatic screen off, lock screen, and suspend behaviors")
        icon: "schedule"
        accentColor: Colours.palette.m3secondary

        SettingRow {
            title: qsTr("Turn off screen")
            description: qsTr("Automatically turn off display output when idle")
            divider: root.isTimeoutEnabled("dpms off") ? false : true
            StyledSwitch {
                checked: root.isTimeoutEnabled("dpms off")
                onToggled: root.updateTimeout("dpms off", checked, root.getTimeoutMinutes("dpms off", 5), "dpms off")
            }
        }

        Item {
            id: dpmsWrapper
            property bool isEnabled: root.isTimeoutEnabled("dpms off")
            width: parent.width
            implicitHeight: isEnabled ? innerDpms.implicitHeight : 0
            visible: opacity > 0 || heightAnimDpms.running
            opacity: isEnabled ? 1 : 0
            clip: true

            Behavior on implicitHeight {
                Anim { id: heightAnimDpms; type: Anim.DefaultSpatial }
            }
            Behavior on opacity {
                Anim { type: Anim.DefaultEffects }
            }

            SettingRow {
                id: innerDpms
                width: parent.width
                title: qsTr("Delay before turning off")
                icon: "subdirectory_arrow_right"
                divider: true
                CustomSpinBox {
                    value: root.getTimeoutMinutes("dpms off", 5)
                    min: 1
                    max: 120
                    step: 1
                    onValueModified: v => root.updateTimeout("dpms off", true, v, "dpms off")
                }
            }
        }

        SettingRow {
            title: qsTr("Lock screen")
            description: qsTr("Automatically lock the desktop session when idle")
            divider: root.isTimeoutEnabled("lock") ? false : true
            StyledSwitch {
                checked: root.isTimeoutEnabled("lock")
                onToggled: root.updateTimeout("lock", checked, root.getTimeoutMinutes("lock", 3), "lock")
            }
        }

        Item {
            id: lockWrapper
            property bool isEnabled: root.isTimeoutEnabled("lock")
            width: parent.width
            implicitHeight: isEnabled ? innerLock.implicitHeight : 0
            visible: opacity > 0 || heightAnimLock.running
            opacity: isEnabled ? 1 : 0
            clip: true

            Behavior on implicitHeight {
                Anim { id: heightAnimLock; type: Anim.DefaultSpatial }
            }
            Behavior on opacity {
                Anim { type: Anim.DefaultEffects }
            }

            SettingRow {
                id: innerLock
                width: parent.width
                title: qsTr("Delay before locking")
                icon: "subdirectory_arrow_right"
                divider: true
                CustomSpinBox {
                    value: root.getTimeoutMinutes("lock", 3)
                    min: 1
                    max: 60
                    step: 1
                    onValueModified: v => root.updateTimeout("lock", true, v, "lock")
                }
            }
        }

        SettingRow {
            title: qsTr("System sleep")
            description: qsTr("Automatically place system into sleep mode when idle")
            divider: false
            StyledSwitch {
                checked: root.isTimeoutEnabled("suspend")
                onToggled: root.updateTimeout("suspend", checked, root.getTimeoutMinutes("suspend", 10), ["systemctl", "suspend"])
            }
        }

        Item {
            id: suspendWrapper
            property bool isEnabled: root.isTimeoutEnabled("suspend")
            width: parent.width
            implicitHeight: isEnabled ? innerSuspend.implicitHeight : 0
            visible: opacity > 0 || heightAnimSuspend.running
            opacity: isEnabled ? 1 : 0
            clip: true

            Behavior on implicitHeight {
                Anim { id: heightAnimSuspend; type: Anim.DefaultSpatial }
            }
            Behavior on opacity {
                Anim { type: Anim.DefaultEffects }
            }

            SettingRow {
                id: innerSuspend
                width: parent.width
                title: qsTr("Delay before sleeping")
                icon: "subdirectory_arrow_right"
                divider: false
                CustomSpinBox {
                    value: root.getTimeoutMinutes("suspend", 10)
                    min: 2
                    max: 240
                    step: 2
                    onValueModified: v => root.updateTimeout("suspend", true, v, ["systemctl", "suspend"])
                }
            }
        }
    }

    Section {
        id: safeguardsSection
        Layout.fillWidth: true
        title: qsTr("Idle & Sleep Safeguards")
        description: qsTr("Security and media playback sleep prevention rules")
        icon: "security"
        accentColor: Colours.palette.m3secondary

        SettingRow {
            title: qsTr("Lock before sleep")
            description: qsTr("Require password unlock after the system suspends")
            divider: true
            StyledSwitch {
                checked: GlobalConfig.general.idle.lockBeforeSleep ?? true
                onToggled: {
                    GlobalConfig.general.idle.lockBeforeSleep = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Inhibit idle during media playback")
            description: qsTr("Prevent screen dimming and suspend while playing audio or video")
            divider: true
            StyledSwitch {
                checked: GlobalConfig.general.idle.inhibitWhenAudio ?? true
                onToggled: {
                    GlobalConfig.general.idle.inhibitWhenAudio = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Keep awake (Caffeine mode)")
            description: qsTr("Manually prevent system from dimming, locking, or suspending")
            divider: false
            StyledSwitch {
                checked: GlobalConfig.qspanel?.keepAwake ?? false
                onToggled: {
                    if (GlobalConfig.qspanel) {
                        GlobalConfig.qspanel.keepAwake = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }
}
