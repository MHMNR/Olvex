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

    property bool activeWindowCompact: Config.bar.activeWindow.compact ?? false
    property bool activeWindowInverted: Config.bar.activeWindow.inverted ?? false
    property bool clockShowIcon: Config.bar.clock.showIcon ?? true
    property bool clockBackground: Config.bar.clock.background ?? false
    property bool clockShowDate: Config.bar.clock.showDate ?? false
    property bool useTwelveHourClock: GlobalConfig.services.useTwelveHourClock ?? false
    property bool persistent: Config.bar.persistent ?? true
    property bool showOnHover: Config.bar.showOnHover ?? true
    property int dragThreshold: Config.bar.dragThreshold ?? 20
    property bool showAudio: Config.bar.status.showAudio ?? true
    property bool showMicrophone: Config.bar.status.showMicrophone ?? true
    property bool showKbLayout: Config.bar.status.showKbLayout ?? false
    property bool showNetwork: Config.bar.status.showNetwork ?? true
    property bool showWifi: Config.bar.status.showWifi ?? true
    property bool showBluetooth: Config.bar.status.showBluetooth ?? true
    property bool showBattery: Config.bar.status.showBattery ?? true
    property bool showLockStatus: Config.bar.status.showLockStatus ?? true
    property bool trayBackground: Config.bar.tray.background ?? false
    property bool trayCompact: Config.bar.tray.compact ?? false
    property bool trayRecolour: Config.bar.tray.recolour ?? false
    property int workspacesShown: Config.bar.workspaces.shown ?? 5
    property bool workspacesActiveIndicator: Config.bar.workspaces.activeIndicator ?? true
    property bool workspacesOccupiedBg: Config.bar.workspaces.occupiedBg ?? false
    property bool workspacesShowWindows: Config.bar.workspaces.showWindows ?? false
    property int workspacesMaxWindowIcons: Config.bar.workspaces.maxWindowIcons ?? 0
    property bool workspacesPerMonitor: GlobalConfig.bar.workspaces.perMonitorWorkspaces ?? true
    property bool scrollWorkspaces: Config.bar.scrollActions.workspaces ?? true
    property bool scrollVolume: Config.bar.scrollActions.volume ?? true
    property bool scrollBrightness: Config.bar.scrollActions.brightness ?? true
    property bool popoutActiveWindow: Config.bar.popouts.activeWindow ?? true
    property bool popoutTray: Config.bar.popouts.tray ?? true
    property bool popoutStatusIcons: Config.bar.popouts.statusIcons ?? true
    property bool netSpeedShowIcons: GlobalConfig.bar?.netSpeed?.showIcons ?? true
    property bool netSpeedBackground: GlobalConfig.bar?.netSpeed?.background ?? false
    property int netSpeedInterval: GlobalConfig.bar?.netSpeed?.refreshInterval ?? 1000
    property int netSpeedFontSize: GlobalConfig.bar?.netSpeed?.fontSize ?? 11
    property int netSpeedMaxDigits: GlobalConfig.bar?.netSpeed?.maxDigits ?? 0
    property bool netSpeedEnabled: false
    property list<string> monitorNames: Hypr.monitorNames()
    property list<string> excludedScreens: Config.bar.excludedScreens ?? []
    property bool bottomPanelEnabled: Config.bar.bottomPanel.enabled ?? true
    property string bottomPanelVisibilityMode: Config.bar.bottomPanel.visibilityMode ?? "always"

    function saveConfig(entryIndex, entryEnabled) {
        GlobalConfig.bar.activeWindow.compact = root.activeWindowCompact;
        GlobalConfig.bar.activeWindow.inverted = root.activeWindowInverted;
        GlobalConfig.bar.clock.background = root.clockBackground;
        GlobalConfig.bar.clock.showDate = root.clockShowDate;
        GlobalConfig.bar.clock.showIcon = root.clockShowIcon;
        GlobalConfig.bar.persistent = root.persistent;
        GlobalConfig.bar.showOnHover = root.showOnHover;
        GlobalConfig.bar.dragThreshold = root.dragThreshold;
        GlobalConfig.bar.status.showAudio = root.showAudio;
        GlobalConfig.bar.status.showMicrophone = root.showMicrophone;
        GlobalConfig.bar.status.showKbLayout = root.showKbLayout;
        GlobalConfig.bar.status.showNetwork = root.showNetwork;
        GlobalConfig.bar.status.showWifi = root.showWifi;
        GlobalConfig.bar.status.showBluetooth = root.showBluetooth;
        GlobalConfig.bar.status.showBattery = root.showBattery;
        GlobalConfig.bar.status.showLockStatus = root.showLockStatus;
        GlobalConfig.bar.tray.background = root.trayBackground;
        GlobalConfig.bar.tray.compact = root.trayCompact;
        GlobalConfig.bar.tray.recolour = root.trayRecolour;
        GlobalConfig.bar.workspaces.shown = root.workspacesShown;
        GlobalConfig.bar.workspaces.activeIndicator = root.workspacesActiveIndicator;
        GlobalConfig.bar.workspaces.occupiedBg = root.workspacesOccupiedBg;
        GlobalConfig.bar.workspaces.showWindows = root.workspacesShowWindows;
        GlobalConfig.bar.workspaces.maxWindowIcons = root.workspacesMaxWindowIcons;
        GlobalConfig.bar.workspaces.perMonitorWorkspaces = root.workspacesPerMonitor;
        GlobalConfig.bar.scrollActions.workspaces = root.scrollWorkspaces;
        GlobalConfig.bar.scrollActions.volume = root.scrollVolume;
        GlobalConfig.bar.scrollActions.brightness = root.scrollBrightness;
        GlobalConfig.bar.popouts.activeWindow = root.popoutActiveWindow;
        GlobalConfig.bar.popouts.tray = root.popoutTray;
        GlobalConfig.bar.popouts.statusIcons = root.popoutStatusIcons;
        if (GlobalConfig.bar?.netSpeed) {
            GlobalConfig.bar.netSpeed.showIcons = root.netSpeedShowIcons;
            GlobalConfig.bar.netSpeed.background = root.netSpeedBackground;
            GlobalConfig.bar.netSpeed.refreshInterval = root.netSpeedInterval;
            GlobalConfig.bar.netSpeed.fontSize = root.netSpeedFontSize;
            GlobalConfig.bar.netSpeed.maxDigits = root.netSpeedMaxDigits;
        }
        GlobalConfig.services.useTwelveHourClock = root.useTwelveHourClock;
        GlobalConfig.bar.excludedScreens = root.excludedScreens;
        GlobalConfig.bar.bottomPanel.enabled = root.bottomPanelEnabled;
        GlobalConfig.bar.bottomPanel.visibilityMode = root.bottomPanelVisibilityMode;

        const entries = [];
        for (let i = 0; i < entriesModel.count; i++) {
            const entry = entriesModel.get(i);
            let enabled = entry.enabled;
            if (entryIndex !== undefined && i === entryIndex) {
                enabled = entryEnabled;
            }
            entries.push({
                id: entry.id,
                enabled: enabled
            });
        }
        GlobalConfig.bar.entries = entries;
    }

    anchors.fill: parent

    Component.onCompleted: {
        if (Config.bar.entries) {
            entriesModel.clear();
            let netSpeedFound = false;
            for (let i = 0; i < Config.bar.entries.length; i++) {
                const entry = Config.bar.entries[i];
                if (entry.id === "netSpeed") {
                    netSpeedFound = true;
                    root.netSpeedEnabled = entry.enabled !== false;
                }
                entriesModel.append({
                    id: entry.id,
                    enabled: entry.enabled !== false
                });
            }

            if (!netSpeedFound) {
                root.netSpeedEnabled = false;
                let clockIdx = -1;
                for (let j = 0; j < entriesModel.count; j++) {
                    if (entriesModel.get(j).id === "clock") {
                        clockIdx = j;
                        break;
                    }
                }

                if (clockIdx !== -1)
                    entriesModel.insert(clockIdx, { id: "netSpeed", enabled: false });
                else
                    entriesModel.append({ id: "netSpeed", enabled: false });
            }
        }
    }

    ListModel {
        id: entriesModel
    }

    ClippingRectangle {
        id: taskbarClippingRect

        anchors.fill: parent
        anchors.margins: Tokens.padding.normal
        anchors.leftMargin: 0
        anchors.rightMargin: Tokens.padding.normal

        radius: taskbarBorder.innerRadius
        color: "transparent"

        Loader {
            id: taskbarLoader

            anchors.fill: parent
            anchors.margins: Tokens.padding.large + Tokens.padding.normal
            anchors.leftMargin: Tokens.padding.large
            anchors.rightMargin: Tokens.padding.large

            asynchronous: true
            sourceComponent: taskbarContentComponent
        }
    }

    InnerBorder {
        id: taskbarBorder

        leftThickness: 0
        rightThickness: Tokens.padding.normal
    }

    Component {
        id: taskbarContentComponent

        StyledFlickable {
            id: sidebarFlickable

            flickableDirection: Flickable.VerticalFlick
            contentHeight: sidebarLayout.height

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: sidebarFlickable
            }

            ColumnLayout {
                id: sidebarLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top

                spacing: Tokens.spacing.normal

                RowLayout {
                    spacing: Tokens.spacing.smaller

                    StyledText {
                        text: qsTr("Taskbar")
                        textPointSize: Tokens.font.size.large
                        font.weight: 500
                    }
                }

                SectionContainer {
                    Layout.fillWidth: true
                    alignTop: true

                    StyledText {
                        text: qsTr("Status Icons")
                        textPointSize: Tokens.font.size.normal
                    }

                    ConnectedButtonGroup {
                        rootItem: root

                        options: [
                            {
                                label: qsTr("Speakers"),
                                propertyName: "showAudio",
                                onToggled: function (checked) {
                                    root.showAudio = checked;
                                    root.saveConfig();
                                }
                            },
                            {
                                label: qsTr("Microphone"),
                                propertyName: "showMicrophone",
                                onToggled: function (checked) {
                                    root.showMicrophone = checked;
                                    root.saveConfig();
                                }
                            },
                            {
                                label: qsTr("Keyboard"),
                                propertyName: "showKbLayout",
                                onToggled: function (checked) {
                                    root.showKbLayout = checked;
                                    root.saveConfig();
                                }
                            },
                            {
                                label: qsTr("Network"),
                                propertyName: "showNetwork",
                                onToggled: function (checked) {
                                    root.showNetwork = checked;
                                    root.saveConfig();
                                }
                            },
                            {
                                label: qsTr("Wifi"),
                                propertyName: "showWifi",
                                onToggled: function (checked) {
                                    root.showWifi = checked;
                                    root.saveConfig();
                                }
                            },
                            {
                                label: qsTr("Bluetooth"),
                                propertyName: "showBluetooth",
                                onToggled: function (checked) {
                                    root.showBluetooth = checked;
                                    root.saveConfig();
                                }
                            },
                            {
                                label: qsTr("Battery"),
                                propertyName: "showBattery",
                                onToggled: function (checked) {
                                    root.showBattery = checked;
                                    root.saveConfig();
                                }
                            },
                            {
                                label: qsTr("Capslock"),
                                propertyName: "showLockStatus",
                                onToggled: function (checked) {
                                    root.showLockStatus = checked;
                                    root.saveConfig();
                                }
                            }
                        ]
                    }
                }

                RowLayout {
                    id: mainRowLayout

                    Layout.fillWidth: true
                    spacing: Tokens.spacing.normal

                    ColumnLayout {
                        id: leftColumnLayout

                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: Tokens.spacing.normal

                        SectionContainer {
                            Layout.fillWidth: true
                            alignTop: true

                            StyledText {
                                text: qsTr("Workspaces")
                                textPointSize: Tokens.font.size.normal
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: workspacesShownRow.implicitHeight + Tokens.padding.large * 2
                                radius: Tokens.rounding.normal
                                color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

                                Behavior on implicitHeight {
                                    Anim {}
                                }

                                RowLayout {
                                    id: workspacesShownRow

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: Tokens.padding.large
                                    spacing: Tokens.spacing.normal

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: qsTr("Shown")
                                    }

                                    CustomSpinBox {
                                        min: 1
                                        max: 20
                                        value: root.workspacesShown
                                        onValueModified: value => {
                                            root.workspacesShown = value;
                                            root.saveConfig();
                                        }
                                    }
                                }
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: workspacesActiveIndicatorRow.implicitHeight + Tokens.padding.large * 2
                                radius: Tokens.rounding.normal
                                color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

                                Behavior on implicitHeight {
                                    Anim {}
                                }

                                RowLayout {
                                    id: workspacesActiveIndicatorRow

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: Tokens.padding.large
                                    spacing: Tokens.spacing.normal

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: qsTr("Active indicator")
                                    }

                                    StyledSwitch {
                                        checked: root.workspacesActiveIndicator
                                        onToggled: {
                                            root.workspacesActiveIndicator = checked;
                                            root.saveConfig();
                                        }
                                    }
                                }
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: workspacesOccupiedBgRow.implicitHeight + Tokens.padding.large * 2
                                radius: Tokens.rounding.normal
                                color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

                                Behavior on implicitHeight {
                                    Anim {}
                                }

                                RowLayout {
                                    id: workspacesOccupiedBgRow

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: Tokens.padding.large
                                    spacing: Tokens.spacing.normal

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: qsTr("Occupied background")
                                    }

                                    StyledSwitch {
                                        checked: root.workspacesOccupiedBg
                                        onToggled: {
                                            root.workspacesOccupiedBg = checked;
                                            root.saveConfig();
                                        }
                                    }
                                }
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: workspacesShowWindowsRow.implicitHeight + Tokens.padding.large * 2
                                radius: Tokens.rounding.normal
                                color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

                                Behavior on implicitHeight {
                                    Anim {}
                                }

                                RowLayout {
                                    id: workspacesShowWindowsRow

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: Tokens.padding.large
                                    spacing: Tokens.spacing.normal

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: qsTr("Show windows")
                                    }

                                    StyledSwitch {
                                        checked: root.workspacesShowWindows
                                        onToggled: {
                                            root.workspacesShowWindows = checked;
                                            root.saveConfig();
                                        }
                                    }
                                }
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: workspacesMaxWindowIconsRow.implicitHeight + Tokens.padding.large * 2
                                radius: Tokens.rounding.normal
                                color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

                                Behavior on implicitHeight {
                                    Anim {}
                                }

                                RowLayout {
                                    id: workspacesMaxWindowIconsRow

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: Tokens.padding.large
                                    spacing: Tokens.spacing.normal

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: qsTr("Max window icons")
                                    }

                                    CustomSpinBox {
                                        min: 0
                                        max: 20
                                        value: root.workspacesMaxWindowIcons
                                        onValueModified: value => {
                                            root.workspacesMaxWindowIcons = value;
                                            root.saveConfig();
                                        }
                                    }
                                }
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: workspacesPerMonitorRow.implicitHeight + Tokens.padding.large * 2
                                radius: Tokens.rounding.normal
                                color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

                                Behavior on implicitHeight {
                                    Anim {}
                                }

                                RowLayout {
                                    id: workspacesPerMonitorRow

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: Tokens.padding.large
                                    spacing: Tokens.spacing.normal

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: qsTr("Per monitor workspaces")
                                    }

                                    StyledSwitch {
                                        checked: root.workspacesPerMonitor
                                        onToggled: {
                                            root.workspacesPerMonitor = checked;
                                            root.saveConfig();
                                        }
                                    }
                                }
                            }
                        }

                        SectionContainer {
                            Layout.fillWidth: true
                            alignTop: true

                            StyledText {
                                text: qsTr("Active window")
                                textPointSize: Tokens.font.size.normal
                            }

                            SwitchRow {
                                label: qsTr("Compact")
                                checked: root.activeWindowCompact
                                onToggled: checked => {
                                    root.activeWindowCompact = checked;
                                    root.saveConfig();
                                }
                            }

                            SwitchRow {
                                label: qsTr("Inverted")
                                checked: root.activeWindowInverted
                                onToggled: checked => {
                                    root.activeWindowInverted = checked;
                                    root.saveConfig();
                                }
                            }
                        }

                        SectionContainer {
                            Layout.fillWidth: true
                            alignTop: true

                            StyledText {
                                text: qsTr("Clock")
                                textPointSize: Tokens.font.size.normal
                            }

                            SwitchRow {
                                label: qsTr("Background")
                                checked: root.clockBackground
                                onToggled: checked => {
                                    root.clockBackground = checked;
                                    root.saveConfig();
                                }
                            }

                            SwitchRow {
                                label: qsTr("Show date")
                                checked: root.clockShowDate
                                onToggled: checked => {
                                    root.clockShowDate = checked;
                                    root.saveConfig();
                                }
                            }

                            SwitchRow {
                                label: qsTr("Show clock icon")
                                checked: root.clockShowIcon
                                onToggled: checked => {
                                    root.clockShowIcon = checked;
                                    root.saveConfig();
                                }
                            }

                            SwitchRow {
                                label: qsTr("Use 12-hour clock")
                                checked: root.useTwelveHourClock
                                onToggled: checked => {
                                    root.useTwelveHourClock = checked;
                                    root.saveConfig();
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        id: middleColumnLayout

                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: Tokens.spacing.normal

                        SectionContainer {
                            Layout.fillWidth: true
                            alignTop: true

                            StyledText {
                                text: qsTr("Scroll Actions")
                                textPointSize: Tokens.font.size.normal
                            }

                            ConnectedButtonGroup {
                                rootItem: root

                                options: [
                                    {
                                        label: qsTr("Workspaces"),
                                        propertyName: "scrollWorkspaces",
                                        onToggled: function (checked) {
                                            root.scrollWorkspaces = checked;
                                            root.saveConfig();
                                        }
                                    },
                                    {
                                        label: qsTr("Volume"),
                                        propertyName: "scrollVolume",
                                        onToggled: function (checked) {
                                            root.scrollVolume = checked;
                                            root.saveConfig();
                                        }
                                    },
                                    {
                                        label: qsTr("Brightness"),
                                        propertyName: "scrollBrightness",
                                        onToggled: function (checked) {
                                            root.scrollBrightness = checked;
                                            root.saveConfig();
                                        }
                                    }
                                ]
                            }
                        }

                        SectionContainer {
                            Layout.fillWidth: true
                            alignTop: true

                            StyledText {
                                text: qsTr("Tray Settings")
                                textPointSize: Tokens.font.size.normal
                            }

                            ConnectedButtonGroup {
                                rootItem: root

                                options: [
                                    {
                                        label: qsTr("Background"),
                                        propertyName: "trayBackground",
                                        onToggled: function (checked) {
                                            root.trayBackground = checked;
                                            root.saveConfig();
                                        }
                                    },
                                    {
                                        label: qsTr("Compact"),
                                        propertyName: "trayCompact",
                                        onToggled: function (checked) {
                                            root.trayCompact = checked;
                                            root.saveConfig();
                                        }
                                    },
                                    {
                                        label: qsTr("Recolour"),
                                        propertyName: "trayRecolour",
                                        onToggled: function (checked) {
                                            root.trayRecolour = checked;
                                            root.saveConfig();
                                        }
                                    }
                                ]
                            }
                        }

                        SectionContainer {
                            Layout.fillWidth: true
                            alignTop: true

                            StyledText {
                                text: qsTr("Bottom Panel")
                                textPointSize: Tokens.font.size.normal
                            }

                            SwitchRow {
                                label: qsTr("Enabled")
                                checked: root.bottomPanelEnabled
                                onToggled: checked => {
                                    root.bottomPanelEnabled = checked;
                                    root.saveConfig();
                                }
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: bpModeLayout.implicitHeight + Tokens.padding.large * 2
                                radius: Tokens.rounding.normal
                                color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

                                ColumnLayout {
                                    id: bpModeLayout
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: Tokens.padding.large
                                    spacing: Tokens.spacing.normal

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: qsTr("Visibility Mode")
                                    }

                                    StyledRadioButton {
                                        text: qsTr("Always Show")
                                        checked: root.bottomPanelVisibilityMode === "always"
                                        onClicked: {
                                            root.bottomPanelVisibilityMode = "always";
                                            root.saveConfig();
                                        }
                                    }
                                    StyledRadioButton {
                                        text: qsTr("Auto Hide")
                                        checked: root.bottomPanelVisibilityMode === "autohide"
                                        onClicked: {
                                            root.bottomPanelVisibilityMode = "autohide";
                                            root.saveConfig();
                                        }
                                    }
                                    StyledRadioButton {
                                        text: qsTr("Smart Hide")
                                        checked: root.bottomPanelVisibilityMode === "smarthide"
                                        onClicked: {
                                            root.bottomPanelVisibilityMode = "smarthide";
                                            root.saveConfig();
                                        }
                                    }
                                }
                            }
                        }

                        SectionContainer {
                            Layout.fillWidth: true
                            alignTop: true

                            StyledText {
                                text: qsTr("Network Speed")
                                textPointSize: Tokens.font.size.normal
                            }

                            SwitchRow {
                                label: qsTr("Enabled")
                                checked: root.netSpeedEnabled
                                onToggled: checked => {
                                    root.netSpeedEnabled = checked;
                                    for (let i = 0; i < entriesModel.count; i++) {
                                        if (entriesModel.get(i).id === "netSpeed") {
                                            entriesModel.setProperty(i, "enabled", checked);
                                            break;
                                        }
                                    }
                                    root.saveConfig();
                                }
                            }

                            SwitchRow {
                                label: qsTr("Show icons")
                                checked: root.netSpeedShowIcons
                                onToggled: checked => {
                                    root.netSpeedShowIcons = checked;
                                    root.saveConfig();
                                }
                            }

                            SwitchRow {
                                label: qsTr("Background")
                                checked: root.netSpeedBackground
                                onToggled: checked => {
                                    root.netSpeedBackground = checked;
                                    root.saveConfig();
                                }
                            }

                            SectionContainer {
                                contentSpacing: Tokens.spacing.normal

                                SliderInput {
                                    Layout.fillWidth: true

                                    label: qsTr("Interval")
                                    value: root.netSpeedInterval
                                    from: 100
                                    to: 5000
                                    suffix: "ms"
                                    validator: IntValidator { bottom: 100; top: 5000 }
                                    formatValueFunction: val => Math.round(val).toString()
                                    parseValueFunction: text => parseInt(text)

                                    onValueModified: newValue => {
                                        root.netSpeedInterval = Math.round(newValue);
                                        root.saveConfig();
                                    }
                                }

                                SliderInput {
                                    Layout.fillWidth: true

                                    label: qsTr("Font size")
                                    value: root.netSpeedFontSize
                                    from: 4
                                    to: 20
                                    suffix: "pt"
                                    validator: IntValidator { bottom: 4; top: 20 }
                                    formatValueFunction: val => Math.round(val).toString()
                                    parseValueFunction: text => parseInt(text)

                                    onValueModified: newValue => {
                                        root.netSpeedFontSize = Math.round(newValue);
                                        root.saveConfig();
                                    }
                                }

                                StyledRect {
                                    Layout.fillWidth: true
                                    implicitHeight: maxDigitsRow.implicitHeight + Tokens.padding.large * 2
                                    radius: Tokens.rounding.normal
                                    color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

                                    RowLayout {
                                        id: maxDigitsRow

                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.margins: Tokens.padding.large
                                        spacing: Tokens.spacing.normal

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: qsTr("Max digits")
                                            }

                                            StyledText {
                                                text: `(Ex: ${(1.2345).toFixed(root.netSpeedMaxDigits)} KB)`
                                                textPointSize: Tokens.font.size.smaller
                                                opacity: 0.6
                                            }
                                        }

                                        CustomSpinBox {
                                            min: 0
                                            max: 3
                                            value: root.netSpeedMaxDigits
                                            onValueModified: value => {
                                                root.netSpeedMaxDigits = value;
                                                root.saveConfig();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: Tokens.spacing.normal

                        SectionContainer {
                            Layout.fillWidth: true
                            alignTop: true

                            StyledText {
                                text: qsTr("Bar Behavior")
                                textPointSize: Tokens.font.size.normal
                            }

                            SwitchRow {
                                label: qsTr("Persistent")
                                checked: root.persistent
                                onToggled: checked => {
                                    root.persistent = checked;
                                    root.saveConfig();
                                }
                            }

                            SwitchRow {
                                label: qsTr("Show on hover")
                                checked: root.showOnHover
                                onToggled: checked => {
                                    root.showOnHover = checked;
                                    root.saveConfig();
                                }
                            }

                            SectionContainer {
                                contentSpacing: Tokens.spacing.normal

                                SliderInput {
                                    Layout.fillWidth: true

                                    label: qsTr("Drag threshold")
                                    value: root.dragThreshold
                                    from: 0
                                    to: 100
                                    suffix: "px"
                                    validator: IntValidator {
                                        bottom: 0
                                        top: 100
                                    }
                                    formatValueFunction: val => Math.round(val).toString()
                                    parseValueFunction: text => parseInt(text)

                                    onValueModified: newValue => {
                                        root.dragThreshold = Math.round(newValue);
                                        root.saveConfig();
                                    }
                                }
                            }
                        }

                        SectionContainer {
                            Layout.fillWidth: true
                            alignTop: true

                            StyledText {
                                text: qsTr("Popouts")
                                textPointSize: Tokens.font.size.normal
                            }

                            SwitchRow {
                                label: qsTr("Active window")
                                checked: root.popoutActiveWindow
                                onToggled: checked => {
                                    root.popoutActiveWindow = checked;
                                    root.saveConfig();
                                }
                            }

                            SwitchRow {
                                label: qsTr("Tray")
                                checked: root.popoutTray
                                onToggled: checked => {
                                    root.popoutTray = checked;
                                    root.saveConfig();
                                }
                            }

                            SwitchRow {
                                label: qsTr("Status icons")
                                checked: root.popoutStatusIcons
                                onToggled: checked => {
                                    root.popoutStatusIcons = checked;
                                    root.saveConfig();
                                }
                            }
                        }

                        SectionContainer {
                            Layout.fillWidth: true
                            alignTop: true

                            StyledText {
                                text: qsTr("Monitors")
                                textPointSize: Tokens.font.size.normal
                            }

                            ConnectedButtonGroup {
                                rootItem: root
                                rows: Math.ceil(root.monitorNames.length / 3)

                                options: root.monitorNames.map(e => ({
                                            label: qsTr(e),
                                            propertyName: `monitor${e}`,
                                            onToggled: function (_) {
                                                let addedBack = excludedScreens.includes(e);
                                                if (addedBack) {
                                                    const index = excludedScreens.indexOf(e);
                                                    if (index !== -1) {
                                                        excludedScreens.splice(index, 1);
                                                    }
                                                } else {
                                                    if (!excludedScreens.includes(e)) {
                                                        excludedScreens.push(e);
                                                    }
                                                }
                                                root.saveConfig();
                                            },
                                            state: !Strings.testRegexList(root.excludedScreens, e)
                                        }))
                                }
                            }
                        }
                    }
            }
        }
    }
}
