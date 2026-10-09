
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Olvex.Config
import qs.components
import qs.components.icons
import qs.services
import qs.utils

StyledRect {
    id: root

    property color colour: Colours.light ? Colours.palette.m3onSurface : Colours.palette.m3secondary
    readonly property real iconSize: 20
    readonly property alias items: iconColumn

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

            sourceComponent: Loader {
                active: true
                sourceComponent: (Nmcli.hasEthernetHw && !!Nmcli.activeEthernet) ? ethIconComp : wifiIconComp

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
                BluetoothLottieIcon {
                    Layout.alignment: Qt.AlignHCenter
                    visible: !btCol.hasConnectedDevices
                    size: root.iconSize
                    connected: (Bluetooth.defaultAdapter?.enabled ?? false) // qmllint disable unresolved-type
                    color: root.colour
                    disabledColor: Qt.alpha(root.colour, 0.42)
                }

                // Connected bluetooth devices (unified icon + battery ring)
                Repeater {
                    model: ScriptModel {
                        values: btCol.connectedDevices
                    }

                    BluetoothDeviceBatteryIcon {
                        id: device
                        required property BluetoothDevice modelData
                        Layout.alignment: Qt.AlignHCenter
                        device: modelData
                        size: root.iconSize
                        color: Colours.light ? Colours.palette.m3primary : root.colour
                        trackColor: Qt.alpha(root.colour, 0.20)
                        lowBatteryColor: Colours.palette.m3error
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

            sourceComponent: Loader {
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
        }
    }

    component WrappedLoader: Loader {
        required property string name

        asynchronous: true
        Layout.alignment: Qt.AlignHCenter
        visible: active
    }
}
