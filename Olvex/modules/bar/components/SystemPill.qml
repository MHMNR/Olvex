
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

// Premium status stack — glass capsule, tiered icons, mono telemetry.
// Contracts for Bar.checkPopout:
//   - `items` is a flat Column of StatusSlots (+ spacers / net block)
//   - StatusSlot exposes `name` for popout ids
//   - Net speed has no name (never opens a popout)
StyledRect {
    id: root

    // ── Theme ──
    readonly property color colourIdle: Colours.light ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
    readonly property color colourActive: Colours.palette.m3primary
    readonly property color colourDanger: Colours.palette.m3error
    readonly property color colourMuted: Colours.light ? Qt.alpha(colourIdle, 0.65) : Qt.alpha(colourIdle, 0.42)

    readonly property alias items: iconColumn

    readonly property var netSpeedConfig: GlobalConfig.bar?.netSpeed ?? null
    readonly property bool netSpeedEnabled: netSpeedConfig?.enabled ?? true
    readonly property bool netSpeedShowIcons: netSpeedConfig?.showIcons ?? true
    readonly property int netSpeedFontSize: netSpeedConfig?.fontSize ?? 10
    readonly property int netSpeedMaxDigits: netSpeedConfig?.maxDigits ?? 0

    readonly property real iconSize: 20
    readonly property real slotGap: Tokens.spacing.extraSmall
    readonly property real padV: Tokens.spacing.small
    readonly property real padH: Math.max(4, Tokens.padding.small / 2)

    // ── Live flags (for spacers) ──
    readonly property bool isEthernetActive: Nmcli.hasEthernetHw && !!Nmcli.activeEthernet
    readonly property bool showNet: Config.bar.status.showNetwork && (Nmcli.hasWifiHw || Nmcli.hasEthernetHw)
    readonly property bool showBt: Config.bar.status.showBluetooth && (Bluetooth.defaultAdapter !== null)
    readonly property bool showBat: Config.bar.status.showBattery && UPower.displayDevice.isLaptopBattery
    readonly property bool showAud: Config.bar.status.showAudio
    readonly property bool showMic: Config.bar.status.showMicrophone
    readonly property bool showSpeed: root.netSpeedEnabled
    readonly property bool showLock: Config.bar.status.showLockStatus && (Hypr.capsLock || Hypr.numLock)
    readonly property bool showKb: Config.bar.status.showKbLayout

    readonly property bool tierLink: showNet || showBt
    readonly property bool tierPower: showBat
    readonly property bool tierMedia: showAud || showMic
    readonly property bool tierTelemetry: showSpeed
    readonly property bool tierEphemeral: showLock || showKb

    color: Colours.tileSurface
    radius: Tokens.rounding.full

    border.width: 0
    border.color: "transparent"
    scale: pillHover.containsMouse ? 1.02 : 1.0

    Behavior on scale {
        SpringAnimation {
            spring: 4.2
            damping: 0.7
            mass: 1.0
            epsilon: 0.005
        }
    }

    // Soft top sheen
    Rectangle {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 1
        }
        height: Math.min(parent.height * 0.26, 28)
        radius: parent.radius
        z: 0
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.alpha(Colours.palette.m3onSurface, 0.07)
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }

    MouseArea {
        id: pillHover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: {
            const vis = Visibilities.getForActive();
            if (vis) {
                vis.qspanel = !vis.qspanel;
            }
        }
        z: 1
    }

    clip: true
    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: iconColumn.implicitHeight + root.padV * 2

    Component.onCompleted: NetworkUsage.refCount++
    Component.onDestruction: NetworkUsage.refCount--

    // ── Flat column — direct StatusSlot children for childAt hit-test ──
    Column {
        id: iconColumn

        z: 2
        anchors.centerIn: parent
        width: parent.width - root.padH * 2
        spacing: root.slotGap

        // ── Unified Network (Ethernet Priority -> Wi-Fi -> Disconnected) ──
        StatusSlot {
            name: "network"
            active: root.showNet

            Loader {
                anchors.centerIn: parent
                sourceComponent: root.isEthernetActive ? ethIconComp : wifiIconComp
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
                        color: root.colourIdle
                        iconPointSize: 16
                    }
                }
            }

            Component {
                id: wifiIconComp
                WifiLottieIcon {
                    anchors.centerIn: parent
                    size: root.iconSize
                    wifiEnabled: Nmcli.wifiEnabled
                    connected: Boolean(Nmcli.active)
                    signalStrength: (Nmcli.active?.strength ?? 0) / 100.0
                    color: Nmcli.active ? root.colourIdle : root.colourMuted
                    disabledColor: root.colourMuted
                }
            }
        }

        StatusSlot {
            id: btSlot
            name: "bluetooth"
            active: root.showBt
            contentHeight: Math.max(root.iconSize + 2, btCol.implicitHeight)

            Column {
                id: btCol
                anchors.centerIn: parent
                spacing: 4

                readonly property var connectedDevices: Bluetooth.devices.values.filter(d => d.state !== BluetoothDeviceState.Disconnected)
                readonly property bool hasConnectedDevices: connectedDevices.length > 0

                // Bluetooth icon (shown when no devices connected)
                BluetoothLottieIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !btCol.hasConnectedDevices
                    size: root.iconSize
                    connected: (Bluetooth.defaultAdapter?.enabled ?? false)
                    color: root.colourIdle
                    disabledColor: root.colourMuted
                }

                // Connected bluetooth devices (unified icon + battery ring)
                Repeater {
                    model: ScriptModel {
                        values: btCol.connectedDevices
                    }

                    BluetoothDeviceBatteryIcon {
                        id: btDevItem
                        required property BluetoothDevice modelData
                        anchors.horizontalCenter: parent.horizontalCenter
                        device: modelData
                        size: root.iconSize
                        color: root.colourActive
                        trackColor: Qt.alpha(root.colourIdle, 0.22)
                        lowBatteryColor: root.colourDanger
                    }
                }
            }
        }

        TierSpacer {
            active: root.tierLink && (root.tierPower || root.tierMedia || root.tierTelemetry || root.tierEphemeral)
        }

        // ── Power ──
        StatusSlot {
            name: "battery"
            active: root.showBat
            contentHeight: root.iconSize + 2

            Loader {
                id: batInner
                anchors.centerIn: parent
                active: true
                sourceComponent: UPower.displayDevice.isLaptopBattery ? laptopBattery : profileIcon

                Component {
                    id: laptopBattery
                    BatteryLottieIcon {
                        size: root.iconSize
                        level: UPower.displayDevice.percentage
                        charging: [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(UPower.displayDevice.state)
                        color: !UPower.onBattery || UPower.displayDevice.percentage > 0.2
                            ? root.colourIdle
                            : root.colourDanger
                    }
                }

                Component {
                    id: profileIcon
                    MaterialIcon {
                        animate: true
                        text: {
                            if (PowerProfiles.profile === PowerProfile.PowerSaver)
                                return "energy_savings_leaf";
                            if (PowerProfiles.profile === PowerProfile.Performance)
                                return "rocket_launch";
                            return "balance";
                        }
                        color: root.colourIdle
                        fill: 1
                        iconPointSize: root.iconSize
                    }
                }
            }
        }

        TierSpacer {
            active: root.tierPower && (root.tierMedia || root.tierTelemetry || root.tierEphemeral)
        }

        // ── Media: volume (level + scroll to change) ──
        StatusSlot {
            id: audioSlot
            name: "audio"
            active: root.showAud
            contentHeight: Math.max(root.iconSize + 4, audioCol.implicitHeight)

            // Scroll over icon → volume up/down
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (event.angleDelta.y > 0 || event.pixelDelta.y > 0)
                        Audio.incrementVolume();
                    else if (event.angleDelta.y < 0 || event.pixelDelta.y < 0)
                        Audio.decrementVolume();
                    event.accepted = true;
                }
            }

            Column {
                id: audioCol
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                VolumeLottieIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size: root.iconSize
                    volumeLevel: Audio.volume
                    muted: Audio.muted
                    color: Audio.muted ? root.colourDanger : root.colourIdle
                    activeMutedColor: root.colourDanger
                }

                // Current level % (quiet mono caption)
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    animate: true
                    text: Audio.muted
                        ? "—"
                        : `${Math.round(Math.min(1, Audio.volume) * 100)}`
                    textPointSize: Math.max(8, root.netSpeedFontSize - 1)
                    font.family: Tokens.font.family.mono
                    font.weight: Font.Medium
                    color: Audio.muted
                        ? root.colourDanger
                        : Qt.alpha(root.colourIdle, 0.88)
                }
            }
        }

        StatusSlot {
            name: "audio"
            active: root.showMic

            MicLottieIcon {
                anchors.centerIn: parent
                size: root.iconSize
                muted: Audio.sourceMuted
                inputLevel: Audio.sourceVolume
                color: Audio.sourceMuted ? root.colourDanger : root.colourIdle
                activeMutedColor: root.colourDanger
            }
        }

        TierSpacer {
            active: (root.tierMedia || root.tierPower || root.tierLink)
                && (root.tierTelemetry || root.tierEphemeral)
                && root.tierTelemetry
        }

        // ── Telemetry (no name → no popout) ──
        Item {
            id: speedBlock
            visible: root.showSpeed
            width: parent.width
            height: visible ? speedCol.implicitHeight : 0

            Column {
                id: speedCol
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 1

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.netSpeedShowIcons
                    text: "arrow_upward"
                    iconPointSize: Math.max(8, root.netSpeedFontSize)
                    color: Qt.alpha(root.colourIdle, 0.65)
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property var fmt: NetworkUsage.formatBytes(NetworkUsage.uploadSpeed)
                    readonly property int decimals: fmt.unit.startsWith("B") ? 0 : root.netSpeedMaxDigits
                    text: `${fmt.value.toFixed(decimals)}${fmt.unit.charAt(0)}`
                    textPointSize: root.netSpeedFontSize
                    font.family: Tokens.font.family.mono
                    font.weight: Font.Medium
                    color: root.colourIdle
                    opacity: 0.9
                }

                Item {
                    width: 1
                    height: 3
                }

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.netSpeedShowIcons
                    text: "arrow_downward"
                    iconPointSize: Math.max(8, root.netSpeedFontSize)
                    color: Qt.alpha(root.colourIdle, 0.65)
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property var fmt: NetworkUsage.formatBytes(NetworkUsage.downloadSpeed)
                    readonly property int decimals: fmt.unit.startsWith("B") ? 0 : root.netSpeedMaxDigits
                    text: `${fmt.value.toFixed(decimals)}${fmt.unit.charAt(0)}`
                    textPointSize: root.netSpeedFontSize
                    font.family: Tokens.font.family.mono
                    font.weight: Font.Medium
                    color: root.colourIdle
                    opacity: 0.9
                }
            }
        }

        TierSpacer {
            active: (root.tierTelemetry || root.tierMedia || root.tierPower || root.tierLink)
                && root.tierEphemeral
        }

        // ── Ephemeral ──
        StatusSlot {
            name: "lockstatus"
            active: root.showLock
            contentHeight: Math.max(root.iconSize + 4, lockCol.implicitHeight)

            Column {
                id: lockCol
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                spacing: 4

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Hypr.capsLock
                    text: "keyboard_capslock_badge"
                    color: root.colourActive
                    iconPointSize: root.iconSize
                }

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Hypr.numLock
                    text: "looks_one"
                    color: root.colourActive
                    iconPointSize: root.iconSize
                }
            }
        }

        StatusSlot {
            name: "kblayout"
            active: root.showKb

            StyledText {
                anchors.centerIn: parent
                animate: true
                text: Hypr.kbLayout
                color: root.colourIdle
                font.family: Tokens.font.family.mono
                textPointSize: Tokens.font.size.small
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // ── Local primitives ──
    component StatusSlot: Item {
        id: slot

        property string name: ""
        property bool active: true
        // Standard icon slot height
        property real contentHeight: root.iconSize

        // Bar.checkPopout reads child.name on items.childAt(...)
        visible: active
        width: iconColumn.width
        height: active ? contentHeight : 0
        implicitHeight: height
        opacity: active ? 1 : 0
        clip: false
    }

    component TierSpacer: Item {
        property bool active: false
        visible: false
        width: 0
        height: 0
    }
}
