pragma ComponentBehavior: Bound

import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import qs.components.filedialog
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.services

Item {
    id: root

    property Session session
    property string targetSoundProp: ""
    property var customSounds: []

    opacity: 0
    y: 10
    Component.onCompleted: cascadeIn.start()

    ParallelAnimation {
        id: cascadeIn
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens?.anim?.durations?.slow ?? 400; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens?.anim?.durations?.slow ?? 400; easing.type: Easing.OutCubic }
    }

    readonly property var defaultSoundOptions: [
        { label: qsTr("Charger In"), val: "charger-in.mp3" },
        { label: qsTr("Charger Out"), val: "charger-out.mp3" },
        { label: qsTr("Device Connect"), val: "device-in.mp3" },
        { label: qsTr("Device Disconnect"), val: "device-out.mp3" },
        { label: qsTr("Notification 1"), val: "notif.mp3" },
        { label: qsTr("Notification 2"), val: "notif2.mp3" },
        { label: qsTr("Notification 3"), val: "notif3.mp3" },
        { label: qsTr("Notification Urgent"), val: "notificationV.mp3" },
        { label: qsTr("Toast Message"), val: "toast.mp3" },
        { label: qsTr("Warning Alert"), val: "warning.mp3" }
    ]

    function getAllOptions(currentVal) {
        let list = [...root.defaultSoundOptions];
        for (let i = 0; i < root.customSounds.length; i++) {
            const p = root.customSounds[i];
            if (!list.some(item => item.val === p)) {
                list.push({ label: UiSounds.soundLabel(p), val: p });
            }
        }
        if (currentVal && currentVal.startsWith("/") && !list.some(item => item.val === currentVal)) {
            list.push({ label: UiSounds.soundLabel(currentVal), val: currentVal });
        }
        list.push({ label: qsTr("Browse custom file..."), val: "__BROWSE__" });
        return list;
    }

    function idxOfSound(options, soundVal, defaultVal) {
        const val = soundVal || defaultVal;
        for (let i = 0; i < options.length; i++) {
            if (options[i].val === val)
                return i;
        }
        return 0;
    }

    function openPickerFor(propName) {
        root.targetSoundProp = propName;
        soundPicker.open();
    }

    readonly property FileDialog soundPicker: FileDialog {
        title: qsTr("Select Custom Audio File")
        filterLabel: qsTr("Audio Files (*.mp3, *.wav, *.ogg, *.flac, *.m4a, *.opus)")
        filters: ["*.mp3", "*.wav", "*.ogg", "*.flac", "*.m4a", "*.opus"]
        initialCwd: ["Home"]

        onAccepted: path => {
            let urlPath = path;
            if (urlPath.startsWith("file://")) {
                urlPath = urlPath.substring(7);
            }
            if (!urlPath) return;

            if (!root.customSounds.includes(urlPath)) {
                root.customSounds = [...root.customSounds, urlPath];
            }

            if (root.targetSoundProp && GlobalConfig.services.uiSounds[root.targetSoundProp] !== undefined) {
                GlobalConfig.services.uiSounds[root.targetSoundProp] = urlPath;
                GlobalConfig.save();
                UiSounds.preview(urlPath);
            }
        }
    }

    implicitHeight: (col ? col.implicitHeight : 0) + Tokens.padding.large * 2

    component SoundControlRow: RowLayout {
        id: scRow
        spacing: Tokens.spacing.small

        required property string propName
        required property string soundValue
        required property bool isEnabled
        property bool showSwitch: true
        signal soundChanged(string newSound)
        signal toggled(bool enabled)

        readonly property var opts: root.getAllOptions(scRow.soundValue)

        OptionPicker {
            id: picker
            model: scRow.opts
            currentIndex: root.idxOfSound(scRow.opts, scRow.soundValue, "")
            enabled: !scRow.showSwitch || scRow.isEnabled
            opacity: enabled ? 1.0 : 0.45

            onSelected: idx => {
                if (idx >= 0 && idx < scRow.opts.length) {
                    const chosen = scRow.opts[idx].val;
                    if (chosen === "__BROWSE__") {
                        root.openPickerFor(scRow.propName);
                    } else {
                        scRow.soundChanged(chosen);
                    }
                }
            }
        }

        IconButton {
            type: IconButton.Tonal
            icon: "play_arrow"
            iconPointSize: Tokens.font.size.small
            enabled: (!scRow.showSwitch || scRow.isEnabled) && GlobalConfig.services.uiSounds.enabled
            opacity: enabled ? 1.0 : 0.45
            onClicked: {
                UiSounds.preview(scRow.soundValue);
            }
        }

        IconButton {
            type: IconButton.Text
            icon: "folder_open"
            iconPointSize: Tokens.font.size.small
            enabled: (!scRow.showSwitch || scRow.isEnabled) && GlobalConfig.services.uiSounds.enabled
            opacity: enabled ? 1.0 : 0.45
            onClicked: {
                root.openPickerFor(scRow.propName);
            }
        }

        StyledSwitch {
            visible: scRow.showSwitch
            checked: scRow.isEnabled
            enabled: GlobalConfig.services.uiSounds.enabled
            onToggled: {
                scRow.toggled(checked);
            }
        }
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Tokens.padding.large
        anchors.rightMargin: Tokens.padding.large
        anchors.topMargin: Tokens.padding.large
        spacing: Tokens.spacing.large

        // ── Master Controls Card ──
        Column {
            Layout.fillWidth: true
            spacing: 0

            SettingRow {
                title: qsTr("UI Sound Effects")
                description: qsTr("Play audio feedback for desktop events")
                icon: "volume_up"
                divider: true
                StyledSwitch {
                    checked: GlobalConfig.services.uiSounds.enabled
                    onToggled: {
                        GlobalConfig.services.uiSounds.enabled = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Effects volume")
                description: qsTr("Volume level for UI sound effects")
                icon: "graphic_eq"
                divider: false
                CustomSpinBox {
                    value: Math.round((GlobalConfig.services.uiSounds.volume || 0.8) * 100)
                    min: 5
                    max: 100
                    step: 5
                    enabled: GlobalConfig.services.uiSounds.enabled
                    onValueModified: v => {
                        GlobalConfig.services.uiSounds.volume = v / 100;
                        GlobalConfig.save();
                    }
                }
            }
        }

        // ── Notifications Section ──
        Section {
            title: qsTr("Notifications")
            description: qsTr("Audio chimes for incoming desktop notifications")
            icon: "notifications"
            accentColor: Colours.palette.m3tertiary

            SettingRow {
                title: qsTr("Notification chime")
                description: qsTr("Sound for regular desktop notifications")
                divider: true
                SoundControlRow {
                    propName: "notificationsSound"
                    soundValue: GlobalConfig.services.uiSounds.notificationsSound || "notif.mp3"
                    isEnabled: GlobalConfig.services.uiSounds.notifications
                    onSoundChanged: s => {
                        GlobalConfig.services.uiSounds.notificationsSound = s;
                        GlobalConfig.save();
                    }
                    onToggled: e => {
                        GlobalConfig.services.uiSounds.notifications = e;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Urgent notification")
                description: qsTr("Sound for high-priority / critical alerts")
                divider: false
                SoundControlRow {
                    propName: "notificationsUrgentSound"
                    soundValue: GlobalConfig.services.uiSounds.notificationsUrgentSound || "notificationV.mp3"
                    isEnabled: GlobalConfig.services.uiSounds.notifications
                    showSwitch: false
                    onSoundChanged: s => {
                        GlobalConfig.services.uiSounds.notificationsUrgentSound = s;
                        GlobalConfig.save();
                    }
                }
            }
        }

        // ── Power & Battery Section ──
        Section {
            title: qsTr("Power & Battery")
            description: qsTr("Sounds for AC adapter state and battery alerts")
            icon: "battery_charging_full"
            accentColor: Colours.palette.m3primary

            SettingRow {
                title: qsTr("Charger connected")
                description: qsTr("Sound when AC adapter is plugged in")
                divider: true
                SoundControlRow {
                    propName: "chargerInSound"
                    soundValue: GlobalConfig.services.uiSounds.chargerInSound || "charger-in.mp3"
                    isEnabled: GlobalConfig.services.uiSounds.charger
                    onSoundChanged: s => {
                        GlobalConfig.services.uiSounds.chargerInSound = s;
                        GlobalConfig.save();
                    }
                    onToggled: e => {
                        GlobalConfig.services.uiSounds.charger = e;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Charger disconnected")
                description: qsTr("Sound when AC adapter is unplugged")
                divider: false
                SoundControlRow {
                    propName: "chargerOutSound"
                    soundValue: GlobalConfig.services.uiSounds.chargerOutSound || "charger-out.mp3"
                    isEnabled: GlobalConfig.services.uiSounds.charger
                    onSoundChanged: s => {
                        GlobalConfig.services.uiSounds.chargerOutSound = s;
                        GlobalConfig.save();
                    }
                    onToggled: e => {
                        GlobalConfig.services.uiSounds.charger = e;
                        GlobalConfig.save();
                    }
                }
            }
        }

        // ── Devices & Peripherals Section ──
        Section {
            title: qsTr("Devices & Peripherals")
            description: qsTr("Sounds for Bluetooth and USB device connections")
            icon: "devices"
            accentColor: Colours.palette.m3secondary

            SettingRow {
                title: qsTr("Device connected")
                description: qsTr("Sound when a peripheral connects")
                divider: true
                SoundControlRow {
                    propName: "deviceInSound"
                    soundValue: GlobalConfig.services.uiSounds.deviceInSound || "device-in.mp3"
                    isEnabled: GlobalConfig.services.uiSounds.device
                    onSoundChanged: s => {
                        GlobalConfig.services.uiSounds.deviceInSound = s;
                        GlobalConfig.save();
                    }
                    onToggled: e => {
                        GlobalConfig.services.uiSounds.device = e;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Device disconnected")
                description: qsTr("Sound when a peripheral disconnects")
                divider: false
                SoundControlRow {
                    propName: "deviceOutSound"
                    soundValue: GlobalConfig.services.uiSounds.deviceOutSound || "device-out.mp3"
                    isEnabled: GlobalConfig.services.uiSounds.device
                    onSoundChanged: s => {
                        GlobalConfig.services.uiSounds.deviceOutSound = s;
                        GlobalConfig.save();
                    }
                    onToggled: e => {
                        GlobalConfig.services.uiSounds.device = e;
                        GlobalConfig.save();
                    }
                }
            }
        }

        // ── Toasts & Alerts Section ──
        Section {
            title: qsTr("Toasts & Alerts")
            description: qsTr("Sounds for toast messages and system warnings")
            icon: "info"
            accentColor: Colours.palette.m3primary

            SettingRow {
                title: qsTr("Toast notification")
                description: qsTr("Sound played when a toast popup message appears")
                divider: true
                SoundControlRow {
                    propName: "toastSound"
                    soundValue: GlobalConfig.services.uiSounds.toastSound || "toast.mp3"
                    isEnabled: GlobalConfig.services.uiSounds.toasts
                    onSoundChanged: s => {
                        GlobalConfig.services.uiSounds.toastSound = s;
                        GlobalConfig.save();
                    }
                    onToggled: e => {
                        GlobalConfig.services.uiSounds.toasts = e;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("System warning / Alert")
                description: qsTr("Sound for low battery and critical warnings")
                divider: false
                SoundControlRow {
                    propName: "warningSound"
                    soundValue: GlobalConfig.services.uiSounds.warningSound || "warning.mp3"
                    isEnabled: GlobalConfig.services.uiSounds.warnings
                    onSoundChanged: s => {
                        GlobalConfig.services.uiSounds.warningSound = s;
                        GlobalConfig.save();
                    }
                    onToggled: e => {
                        GlobalConfig.services.uiSounds.warnings = e;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }
}
