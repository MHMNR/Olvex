
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Olvex.Config
import qs.components
import qs.components.controls as Controls
import qs.components.icons
import qs.services
import qs.utils

StyledRect {
    id: root

    property color colour: Colours.light ? Colours.palette.m3onSurface : Colours.palette.m3secondary
    readonly property real iconSize: 20
    readonly property alias items: iconColumn

    property Item activeHoveredItem: null
    property string activeTooltipText: ""

    Timer {
        id: clearActiveHoverTimer
        interval: 180
        onTriggered: {
            root.activeHoveredItem = null;
            root.activeTooltipText = "";
        }
    }

    function setHoveredItem(item, text) {
        if (item) {
            clearActiveHoverTimer.stop();
            activeHoveredItem = item;
            activeTooltipText = text;
        } else {
            clearActiveHoverTimer.restart();
        }
    }

    readonly property var netSpeedConfig: GlobalConfig.bar?.netSpeed ?? null
    readonly property bool netSpeedEnabled: netSpeedConfig?.enabled ?? true
    readonly property bool netSpeedShowIcons: netSpeedConfig?.showIcons ?? true
    readonly property int netSpeedFontSize: netSpeedConfig?.fontSize ?? 10
    readonly property int netSpeedMaxDigits: netSpeedConfig?.maxDigits ?? 0
    readonly property bool showSpeed: root.netSpeedEnabled

    color: Colours.tileSurface
    radius: Tokens.rounding.full

    clip: true
    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: iconColumn.implicitHeight + Tokens.spacing.small * 2

    Component.onCompleted: NetworkUsage.refCount++
    Component.onDestruction: NetworkUsage.refCount--

    ColumnLayout {
        id: iconColumn

        anchors.centerIn: parent
        width: parent.width
        spacing: Tokens.spacing.extraSmall

        // Recording status
        WrappedLoader {
            name: "recording"
            active: Recorder.running || Recorder.selecting

            sourceComponent: Item {
                implicitWidth: recIcon.implicitWidth
                implicitHeight: recIcon.implicitHeight

                MaterialIcon {
                    id: recIcon

                    anchors.centerIn: parent
                    text: Recorder.selecting ? "crop" : (Recorder.paused ? "pause_circle" : "fiber_manual_record")
                    color: Colours.palette.m3error

                    SequentialAnimation on opacity {
                        running: (Recorder.running && !Recorder.paused) || Recorder.selecting
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.25; duration: 600; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 0.25; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Recorder.stop()
                }
            }
        }

        // Lock keys status
        WrappedLoader {
            name: "lockstatus"
            active: Config.bar.status.showLockStatus

            sourceComponent: ColumnLayout {
                spacing: 0

                Item {
                    implicitWidth: capslockIcon.implicitWidth
                    implicitHeight: Hypr.capsLock ? capslockIcon.implicitHeight : 0

                    MaterialIcon {
                        id: capslockIcon

                        anchors.centerIn: parent

                        scale: Hypr.capsLock ? 1 : 0.5
                        opacity: Hypr.capsLock ? 1 : 0

                        text: "keyboard_capslock_badge"
                        color: root.colour

                        Behavior on opacity {
                            Anim {}
                        }

                        Behavior on scale {
                            Anim {}
                        }
                    }

                    Behavior on implicitHeight {
                        Anim {}
                    }
                }

                Item {
                    Layout.topMargin: Hypr.capsLock && Hypr.numLock ? iconColumn.spacing : 0

                    implicitWidth: numlockIcon.implicitWidth
                    implicitHeight: Hypr.numLock ? numlockIcon.implicitHeight : 0

                    MaterialIcon {
                        id: numlockIcon

                        anchors.centerIn: parent

                        scale: Hypr.numLock ? 1 : 0.5
                        opacity: Hypr.numLock ? 1 : 0

                        text: "looks_one"
                        color: root.colour

                        Behavior on opacity {
                            Anim {}
                        }

                        Behavior on scale {
                            Anim {}
                        }
                    }

                    Behavior on implicitHeight {
                        Anim {}
                    }
                }
            }
        }


        // Keyboard layout icon
        WrappedLoader {
            name: "kblayout"
            active: Config.bar.status.showKbLayout

            sourceComponent: StyledText {
                animate: true
                text: Hypr.kbLayout
                color: root.colour
                font.family: Tokens.font.family.mono
            }
        }

        // Unified Network icon (Ethernet Priority -> Wi-Fi -> Disconnected)
        WrappedLoader {
            name: "network"
            active: Config.bar.status.showNetwork && (Nmcli.hasWifiHw || Nmcli.hasEthernetHw)

            sourceComponent: Item {
                id: netWrap
                implicitWidth: root.iconSize
                implicitHeight: root.iconSize

                Loader {
                    anchors.centerIn: parent
                    active: true
                    sourceComponent: (Nmcli.hasEthernetHw && !!Nmcli.activeEthernet) ? ethIconComp : wifiIconComp
                }

                readonly property string tooltipStr: {
                    if (Nmcli.hasEthernetHw && Nmcli.activeEthernet && Nmcli.activeEthernet.connected) {
                        const name = Nmcli.activeEthernet.connection || qsTr("Ethernet");
                        const ip = Nmcli.currentIp;
                        return ip ? `${name}\n${ip}` : name;
                    }
                    if (Nmcli.wifiEnabled && Nmcli.active && Nmcli.active.ssid) {
                        const name = Nmcli.active.ssid;
                        const ip = Nmcli.currentIp;
                        return ip ? `${name}\n${ip}` : name;
                    }
                    return Nmcli.wifiEnabled ? qsTr("Wi-Fi: Disconnected") : qsTr("Wi-Fi: Disabled");
                }

                MouseArea {
                    id: netMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: root.setHoveredItem(netWrap, netWrap.tooltipStr)
                    onExited: root.setHoveredItem(null, "")
                }

                Component {
                    id: ethIconComp
                    Item {
                        implicitWidth: root.iconSize
                        implicitHeight: root.iconSize
                        MaterialIcon {
                            anchors.centerIn: parent
                            animate: true
                            text: "settings_ethernet"
                            color: root.colour
                            iconPointSize: 16
                        }
                    }
                }

                Component {
                    id: wifiIconComp
                    WifiLottieIcon {
                        size: root.iconSize
                        wifiEnabled: Nmcli.wifiEnabled
                        connected: Boolean(Nmcli.active)
                        signalStrength: (Nmcli.active?.strength ?? 0) / 100.0
                        color: Nmcli.active ? root.colour : Qt.alpha(root.colour, 0.42)
                        disabledColor: Qt.alpha(root.colour, 0.42)
                    }
                }
            }
        }

        // Bluetooth section
        WrappedLoader {
            Layout.preferredHeight: implicitHeight

            name: "bluetooth"
            active: Config.bar.status.showBluetooth && (Bluetooth.defaultAdapter !== null)

            sourceComponent: ColumnLayout {
                id: btCol
                spacing: Tokens.spacing.extraSmall

                readonly property var connectedDevices: Bluetooth.devices.values.filter(d => d.state !== BluetoothDeviceState.Disconnected) // qmllint disable unresolved-type
                readonly property bool hasConnectedDevices: connectedDevices.length > 0

                // Bluetooth icon (shown when no devices connected)
                Item {
                    id: btWrap
                    Layout.alignment: Qt.AlignHCenter
                    visible: !btCol.hasConnectedDevices
                    implicitWidth: root.iconSize
                    implicitHeight: root.iconSize

                    BluetoothLottieIcon {
                        anchors.centerIn: parent
                        size: root.iconSize
                        connected: (Bluetooth.defaultAdapter?.enabled ?? false) // qmllint disable unresolved-type
                        color: root.colour
                        disabledColor: Qt.alpha(root.colour, 0.42)
                    }

                    readonly property string tooltipStr: (Bluetooth.defaultAdapter?.enabled ?? false) ? qsTr("Bluetooth: On (No devices)") : qsTr("Bluetooth: Off") // qmllint disable unresolved-type

                    MouseArea {
                        id: btMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        onEntered: root.setHoveredItem(btWrap, btWrap.tooltipStr)
                        onExited: root.setHoveredItem(null, "")
                    }
                }

                // Connected bluetooth devices (unified icon + battery ring)
                Repeater {
                    model: ScriptModel {
                        values: btCol.connectedDevices
                    }

                    Item {
                        id: devWrap
                        required property BluetoothDevice modelData
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: root.iconSize
                        implicitHeight: root.iconSize

                        BluetoothDeviceBatteryIcon {
                            anchors.centerIn: parent
                            device: devWrap.modelData
                            size: root.iconSize
                            color: Colours.light ? Colours.palette.m3primary : root.colour
                            trackColor: Qt.alpha(root.colour, 0.20)
                            lowBatteryColor: Colours.palette.m3error
                        }

                        readonly property string tooltipStr: {
                            const d = devWrap.modelData;
                            const name = d.name || qsTr("Bluetooth Device");
                            if (d.batteryAvailable && d.battery >= 0) {
                                return `${name} (${Math.round(d.battery * 100)}%)`;
                            }
                            return name;
                        }

                        MouseArea {
                            id: devMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                            onEntered: root.setHoveredItem(devWrap, devWrap.tooltipStr)
                            onExited: root.setHoveredItem(null, "")
                        }
                    }
                }
            }

            Behavior on Layout.preferredHeight {
                Anim {}
            }
        }

        // Battery icon
        WrappedLoader {
            name: "battery"
            active: Config.bar.status.showBattery && UPower.displayDevice.isLaptopBattery

            sourceComponent: Item {
                id: batWrap
                implicitWidth: root.iconSize
                implicitHeight: root.iconSize

                Loader {
                    anchors.centerIn: parent
                    active: true
                    sourceComponent: {
                        if (!UPower.displayDevice.isLaptopBattery)
                            return nonLaptopBattery;
                        return laptopBattery;
                    }

                    Component {
                        id: laptopBattery
                        BatteryLottieIcon {
                            size: root.iconSize
                            level: UPower.displayDevice.percentage
                            charging: [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(UPower.displayDevice.state)
                            color: !UPower.onBattery || UPower.displayDevice.percentage > 0.2 ? root.colour : Colours.palette.m3error
                        }
                    }

                    Component {
                        id: nonLaptopBattery
                        Item {
                            implicitWidth: root.iconSize
                            implicitHeight: root.iconSize
                            MaterialIcon {
                                anchors.centerIn: parent
                                animate: true
                                text: {
                                    if (PowerProfiles.profile === PowerProfile.PowerSaver)
                                        return "energy_savings_leaf";
                                    if (PowerProfiles.profile === PowerProfile.Performance)
                                        return "rocket_launch";
                                    return "balance";
                                }
                                color: root.colour
                                fill: 1
                                iconPointSize: 16
                            }
                        }
                    }
                }

                readonly property string tooltipStr: {
                    const dev = UPower.displayDevice;
                    const pct = Math.round((dev.percentage ?? 0) * 100);
                    if (!dev.isLaptopBattery)
                        return qsTr("Battery: %1%").arg(pct);

                    function formatSeconds(s) {
                        if (!s || s <= 0) return "";
                        const hr = Math.floor(s / 3600);
                        const min = Math.floor((s % 3600) / 60);
                        if (hr > 0) return `${hr}h ${min}m`;
                        return `${min}m`;
                    }

                    const isCharging = [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(dev.state);
                    if (isCharging) {
                        if (dev.state === UPowerDeviceState.FullyCharged || pct >= 100)
                            return qsTr("Battery: 100% (Fully charged)");
                        const timeFull = formatSeconds(dev.timeToFull);
                        return timeFull ? qsTr("Battery: %1% (Charging, %2 left)").arg(pct).arg(timeFull) : qsTr("Battery: %1% (Charging)").arg(pct);
                    } else {
                        const timeEmpty = formatSeconds(dev.timeToEmpty);
                        return timeEmpty ? qsTr("Battery: %1% (%2 remaining)").arg(pct).arg(timeEmpty) : qsTr("Battery: %1%").arg(pct);
                    }
                }

                MouseArea {
                    id: batMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: root.setHoveredItem(batWrap, batWrap.tooltipStr)
                    onExited: root.setHoveredItem(null, "")
                }
            }
        }
    }

    // Single unified sliding tooltip for all Status Icons
    Controls.Tooltip {
        id: statusSlidingTooltip
        target: root.activeHoveredItem || root
        side: Controls.Tooltip.Right
        text: root.activeTooltipText
        tooltipVisible: root.activeHoveredItem !== null && root.activeTooltipText !== ""
    }

    component WrappedLoader: Loader {
        required property string name

        asynchronous: true
        Layout.alignment: Qt.AlignHCenter
        visible: active
    }
}
