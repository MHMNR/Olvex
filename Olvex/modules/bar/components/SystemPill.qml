
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Olvex.Config
import qs.components
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

    readonly property real iconSize: Tokens.font.size.normal
    readonly property real slotGap: 6
    readonly property real padV: Tokens.padding.normal
    readonly property real padH: Math.max(4, Tokens.padding.small / 2)

    // ── Live flags (for spacers) ──
    readonly property bool showNet: Config.bar.status.showNetwork && (!Nmcli.activeEthernet || Config.bar.status.showWifi)
    readonly property bool showEth: Config.bar.status.showNetwork && Nmcli.activeEthernet
    readonly property bool showBt: Config.bar.status.showBluetooth
    readonly property bool showBat: Config.bar.status.showBattery
    readonly property bool showAud: Config.bar.status.showAudio
    readonly property bool showMic: Config.bar.status.showMicrophone
    readonly property bool showSpeed: root.netSpeedEnabled
    readonly property bool showLock: Config.bar.status.showLockStatus && (Hypr.capsLock || Hypr.numLock)
    readonly property bool showKb: Config.bar.status.showKbLayout

    readonly property bool tierLink: showNet || showEth || showBt
    readonly property bool tierPower: showBat
    readonly property bool tierMedia: showAud || showMic
    readonly property bool tierTelemetry: showSpeed
    readonly property bool tierEphemeral: showLock || showKb

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full
    border.width: 1
    border.color: pillHover.containsMouse
        ? Qt.alpha(Colours.palette.m3primary, 0.3)
        : Qt.alpha(Colours.palette.m3outlineVariant, 0.14)
    scale: pillHover.containsMouse ? 1.02 : 1.0

    Behavior on scale {
        SpringAnimation {
            spring: 4.2
            damping: 0.7
            mass: 1.0
            epsilon: 0.005
        }
    }
    Behavior on border.color {
        CAnim {}
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

    // Inner rim (quiet depth)
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, parent.radius - 1)
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3onSurface, 0.04)
        z: 0
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
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - root.padH * 2
        spacing: root.slotGap

        // ── Link ──
        StatusSlot {
            name: "network"
            active: root.showNet

            MaterialIcon {
                anchors.centerIn: parent
                animate: true
                text: Nmcli.active ? Icons.getNetworkIcon(Nmcli.active.strength ?? 0) : "wifi_off"
                color: Nmcli.active ? root.colourIdle : root.colourMuted
                iconPointSize: root.iconSize
            }
        }

        StatusSlot {
            name: "ethernet"
            active: root.showEth

            MaterialIcon {
                anchors.centerIn: parent
                animate: true
                text: "settings_ethernet"
                color: root.colourIdle
                iconPointSize: root.iconSize
            }
        }

        StatusSlot {
            id: btSlot
            name: "bluetooth"
            active: root.showBt
            contentHeight: Math.max(root.iconSize + 4, btCol.implicitHeight)

            Column {
                id: btCol
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                spacing: 4

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    animate: true
                    text: {
                        if (!Bluetooth.defaultAdapter?.enabled)
                            return "bluetooth_disabled";
                        if (Bluetooth.devices.values.some(d => d.connected))
                            return "bluetooth_connected";
                        return "bluetooth";
                    }
                    color: {
                        if (!Bluetooth.defaultAdapter?.enabled)
                            return root.colourMuted;
                        if (Bluetooth.devices.values.some(d => d.connected))
                            return root.colourActive;
                        return root.colourIdle;
                    }
                    iconPointSize: root.iconSize
                }

                Repeater {
                    model: ScriptModel {
                        values: Bluetooth.devices.values.filter(d => d.state !== BluetoothDeviceState.Disconnected)
                    }

                    MaterialIcon {
                        id: btDev
                        required property BluetoothDevice modelData
                        anchors.horizontalCenter: parent.horizontalCenter
                        animate: true
                        text: Icons.getBluetoothIcon(modelData?.icon)
                        color: root.colourIdle
                        fill: 1
                        iconPointSize: Math.max(10, root.iconSize - 2)

                        SequentialAnimation on opacity {
                            running: (btDev.modelData?.state === BluetoothDeviceState.Connecting || btDev.modelData?.state === BluetoothDeviceState.Disconnecting) && root.visible
                            alwaysRunToEnd: true
                            loops: Animation.Infinite
                            Anim {
                                from: 1
                                to: 0.35
                                duration: Tokens.anim.durations.large
                                easing: Tokens.anim.standardAccel
                            }
                            Anim {
                                from: 0.35
                                to: 1
                                duration: Tokens.anim.durations.large
                                easing: Tokens.anim.standardDecel
                            }
                        }
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
            contentHeight: Math.max(root.iconSize + 4, batInner.implicitHeight || 0)

            Loader {
                id: batInner
                anchors.centerIn: parent
                active: true
                sourceComponent: UPower.displayDevice.isLaptopBattery ? laptopBattery : profileIcon

                Component {
                    id: laptopBattery
                    BatteryIcon {
                        percentage: UPower.displayDevice.percentage
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

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    animate: true
                    text: Icons.getVolumeIcon(Audio.volume, Audio.muted)
                    color: Audio.muted ? root.colourDanger : root.colourIdle
                    iconPointSize: root.iconSize
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

            MaterialIcon {
                anchors.centerIn: parent
                animate: true
                text: Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted)
                color: Audio.sourceMuted ? root.colourDanger : root.colourIdle
                iconPointSize: root.iconSize
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
        // Override when content is taller than a single icon (BT devices, lock pair)
        property real contentHeight: root.iconSize + 4

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

        visible: active
        width: iconColumn.width
        height: active ? 9 : 0

        // Soft horizontal hairline
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(12, parent.width * 0.45)
            height: 1
            radius: 0.5
            color: Qt.alpha(root.colourIdle, 0.2)
            visible: parent.active
        }
    }
}
