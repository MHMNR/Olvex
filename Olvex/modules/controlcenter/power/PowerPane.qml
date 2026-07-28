pragma ComponentBehavior: Bound

import ".."
import "../components"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Olvex.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    required property Session session

    readonly property bool keepAwake: IdleInhibitor.enabled
    property bool lockBeforeSleep: GlobalConfig.general.idle.lockBeforeSleep ?? true
    property bool inhibitWhenAudio: GlobalConfig.general.idle.inhibitWhenAudio ?? true

    property bool lockEnabled: true
    property int lockTimeoutMinutes: 3
    property bool screenOffEnabled: true
    property int screenOffTimeoutMinutes: 5
    property bool suspendEnabled: true
    property int suspendTimeoutMinutes: 10

    function cloneEntry(entry) {
        const copy = {};
        for (const key in entry)
            copy[key] = entry[key];
        return copy;
    }

    function actionKey(entry) {
        const action = entry?.idleAction;
        if (action === "lock")
            return "lock";
        if (action === "dpms off")
            return "dpms";
        if (Array.isArray(action))
            return "suspend";
        return "";
    }

    function defaultEntry(key) {
        if (key === "lock")
            return { timeout: 180, idleAction: "lock" };
        if (key === "dpms")
            return { timeout: 300, idleAction: "dpms off", returnAction: "dpms on" };
        return { timeout: 600, idleAction: ["systemctl", "suspend-then-hibernate"] };
    }

    function findEntry(key) {
        const list = GlobalConfig.general.idle.timeouts ?? [];
        for (let i = 0; i < list.length; i++) {
            if (actionKey(list[i]) === key)
                return cloneEntry(list[i]);
        }
        return null;
    }

    function sortTimeouts(list) {
        const order = { lock: 0, dpms: 1, suspend: 2 };
        return list.slice().sort((a, b) => (order[actionKey(a)] ?? 99) - (order[actionKey(b)] ?? 99));
    }

    function dedupeTimeouts(list) {
        if (!list || !list.length)
            return [];
        const seen = {};
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const key = actionKey(list[i]);
            if (!key || seen[key])
                continue;
            seen[key] = true;
            out.push(list[i]);
        }
        return out;
    }

    function loadFromConfig() {
        const raw = GlobalConfig.general.idle.timeouts ?? [];
        const deduped = dedupeTimeouts(raw);
        if (deduped.length !== raw.length)
            GlobalConfig.general.idle.timeouts = deduped;

        const lockEntry = findEntry("lock");
        const dpmsEntry = findEntry("dpms");
        const suspendEntry = findEntry("suspend");

        root.lockEnabled = lockEntry ? (lockEntry.enabled ?? true) : true;
        root.lockTimeoutMinutes = Math.max(1, Math.round((lockEntry?.timeout ?? 180) / 60));

        root.screenOffEnabled = dpmsEntry ? (dpmsEntry.enabled ?? true) : true;
        root.screenOffTimeoutMinutes = Math.max(1, Math.round((dpmsEntry?.timeout ?? 300) / 60));

        root.suspendEnabled = suspendEntry ? (suspendEntry.enabled ?? true) : true;
        root.suspendTimeoutMinutes = Math.max(5, Math.round((suspendEntry?.timeout ?? 600) / 60));
    }

    function normalizedMinutes() {
        let lockMin = root.lockEnabled ? root.lockTimeoutMinutes : 0;
        let screenMin = root.screenOffEnabled ? root.screenOffTimeoutMinutes : 0;
        let suspendMin = root.suspendEnabled ? root.suspendTimeoutMinutes : 0;

        if (root.lockEnabled && root.screenOffEnabled && screenMin < lockMin)
            screenMin = lockMin;
        if (root.screenOffEnabled && root.suspendEnabled && suspendMin < screenMin)
            suspendMin = screenMin;
        if (root.lockEnabled && root.suspendEnabled && !root.screenOffEnabled && suspendMin < lockMin)
            suspendMin = lockMin;

        return { lockMin, screenMin, suspendMin };
    }

    function upsertEntry(list, key, enabled, minutes, patch) {
        const next = [];
        let found = false;
        for (let i = 0; i < list.length; i++) {
            const entry = cloneEntry(list[i]);
            if (actionKey(entry) !== key) {
                next.push(entry);
                continue;
            }
            if (found)
                continue;
            found = true;
            if (enabled) {
                entry.enabled = true;
                entry.timeout = minutes * 60;
                for (const prop in patch)
                    entry[prop] = patch[prop];
                next.push(entry);
            } else {
                entry.enabled = false;
                next.push(entry);
            }
        }
        if (!found && enabled) {
            const entry = defaultEntry(key);
            entry.timeout = minutes * 60;
            for (const prop in patch)
                entry[prop] = patch[prop];
            next.push(entry);
        } else if (!found && !enabled) {
            const entry = defaultEntry(key);
            entry.enabled = false;
            next.push(entry);
        }
        return next;
    }

    function saveConfig() {
        const mins = normalizedMinutes();

        if (root.screenOffEnabled && mins.screenMin !== root.screenOffTimeoutMinutes)
            root.screenOffTimeoutMinutes = mins.screenMin;
        if (root.suspendEnabled && mins.suspendMin !== root.suspendTimeoutMinutes)
            root.suspendTimeoutMinutes = mins.suspendMin;

        GlobalConfig.general.idle.lockBeforeSleep = root.lockBeforeSleep;
        GlobalConfig.general.idle.inhibitWhenAudio = root.inhibitWhenAudio;

        let timeouts = GlobalConfig.general.idle.timeouts ?? [];
        timeouts = upsertEntry(timeouts, "lock", root.lockEnabled, mins.lockMin || root.lockTimeoutMinutes, {});
        timeouts = upsertEntry(timeouts, "dpms", root.screenOffEnabled, mins.screenMin || root.screenOffTimeoutMinutes, {
            returnAction: "dpms on"
        });
        timeouts = upsertEntry(timeouts, "suspend", root.suspendEnabled, mins.suspendMin || root.suspendTimeoutMinutes, {});

        GlobalConfig.general.idle.timeouts = sortTimeouts(dedupeTimeouts(timeouts));
    }

    Component.onCompleted: {
        loadFromConfig();
    }

    Connections {
        target: GlobalConfig.general.idle
        function onTimeoutsChanged(): void {
            root.loadFromConfig();
        }
    }

    anchors.fill: parent

    ClippingRectangle {
        anchors.fill: parent
        anchors.margins: Tokens.padding.normal
        anchors.leftMargin: 0
        anchors.rightMargin: Tokens.padding.normal

        radius: powerBorder.innerRadius
        color: "transparent"

        StyledFlickable {
            id: powerFlickable

            anchors.fill: parent
            anchors.margins: Tokens.padding.large + Tokens.padding.normal
            anchors.leftMargin: Tokens.padding.large
            anchors.rightMargin: Tokens.padding.large

            flickableDirection: Flickable.VerticalFlick
            contentHeight: powerLayout.height

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: powerFlickable
            }

            ColumnLayout {
                id: powerLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top

                spacing: Tokens.spacing.normal

                StyledText {
                    text: qsTr("Power")
                    textPointSize: Tokens.font.size.large
                    font.weight: 500
                }

                IdleSettings {
                    pane: root
                }
            }
        }
    }

    InnerBorder {
        id: powerBorder

        leftThickness: 0
        rightThickness: Tokens.padding.normal
    }

    component IdleSettings: SectionContainer {
        id: idleSettings

        required property var pane

        Layout.fillWidth: true
        alignTop: true

        StyledText {
            text: qsTr("Idle & power")
            textPointSize: Tokens.font.size.normal
        }

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("Times apply after keyboard and pointer inactivity. Keep Awake overrides all idle actions.")
            textPointSize: Tokens.font.size.small
            color: Colours.palette.m3onSurfaceVariant
        }

        SwitchRow {
            label: qsTr("Keep awake")
            checked: IdleInhibitor.enabled
            onToggled: checked => {
                IdleInhibitor.enabled = checked;
            }
        }

        SwitchRow {
            label: qsTr("Lock before sleep")
            checked: idleSettings.pane.lockBeforeSleep
            onToggled: checked => {
                idleSettings.pane.lockBeforeSleep = checked;
                idleSettings.pane.saveConfig();
            }
        }

        SwitchRow {
            label: qsTr("Pause idle timers while audio plays")
            checked: idleSettings.pane.inhibitWhenAudio
            onToggled: checked => {
                idleSettings.pane.inhibitWhenAudio = checked;
                idleSettings.pane.saveConfig();
            }
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Colours.tileInnerLine
        }

        SwitchRow {
            label: qsTr("Auto lock")
            checked: idleSettings.pane.lockEnabled
            onToggled: checked => {
                idleSettings.pane.lockEnabled = checked;
                idleSettings.pane.saveConfig();
            }
        }

        SliderInput {
            Layout.fillWidth: true
            visible: idleSettings.pane.lockEnabled

            label: qsTr("Lock after")
            value: idleSettings.pane.lockTimeoutMinutes
            from: 1
            to: 120
            stepSize: 1
            suffix: qsTr("min")
            validator: IntValidator {
                bottom: 1
                top: 120
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                idleSettings.pane.lockTimeoutMinutes = Math.round(newValue);
                idleSettings.pane.saveConfig();
            }
        }

        SwitchRow {
            label: qsTr("Turn off screen")
            checked: idleSettings.pane.screenOffEnabled
            onToggled: checked => {
                idleSettings.pane.screenOffEnabled = checked;
                idleSettings.pane.saveConfig();
            }
        }

        SliderInput {
            Layout.fillWidth: true
            visible: idleSettings.pane.screenOffEnabled

            label: qsTr("Screen off after")
            value: idleSettings.pane.screenOffTimeoutMinutes
            from: 1
            to: 180
            stepSize: 1
            suffix: qsTr("min")
            validator: IntValidator {
                bottom: 1
                top: 180
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                idleSettings.pane.screenOffTimeoutMinutes = Math.round(newValue);
                idleSettings.pane.saveConfig();
            }
        }

        SwitchRow {
            label: qsTr("Suspend system")
            checked: idleSettings.pane.suspendEnabled
            onToggled: checked => {
                idleSettings.pane.suspendEnabled = checked;
                idleSettings.pane.saveConfig();
            }
        }

        SliderInput {
            Layout.fillWidth: true
            visible: idleSettings.pane.suspendEnabled

            label: qsTr("Suspend after")
            value: idleSettings.pane.suspendTimeoutMinutes
            from: 5
            to: 240
            stepSize: 1
            suffix: qsTr("min")
            validator: IntValidator {
                bottom: 5
                top: 240
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                idleSettings.pane.suspendTimeoutMinutes = Math.round(newValue);
                idleSettings.pane.saveConfig();
            }
        }
    }
}