
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.bar.popouts as BarPopouts
import qs.modules.settings
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick.Effects

StyledRect {
    id: root

    required property var props
    required property DrawerVisibilities visibilities
    required property BarPopouts.Wrapper popouts
    property Item contentRoot

    property bool warpConnected: false
    readonly property bool warpToggleEnabled: root.quickToggles.some(item => item.id === "warp")
    readonly property bool warpStatusActive: root.visibilities.qspanel && warpToggleEnabled

    Process {
        id: warpStatusProc
        command: ["/usr/bin/warp-cli", "status"]
        running: root.warpStatusActive
        stdout: SplitParser {
            onRead: line => {
                const lower = line.toLowerCase();
                if (lower.includes("disconnected")) root.warpConnected = false;
                else if (lower.includes("connected")) root.warpConnected = true;
            }
        }
    }

    Process {
        id: warpActionProc
        onExited: code => {
            if (root.warpStatusActive)
                warpStatusProc.running = true;
        }
    }

    readonly property var quickToggles: {
        const seenIds = new Set();
        let filtered = Config.qspanel.quickToggles.filter(item => {
            if (!(item.enabled ?? true)) return false;
            if (seenIds.has(item.id)) return false;
            if (item.id === "vpn") return GlobalConfig.qspanel.vpn.provider.some(p => typeof p === "object" ? (p.enabled === true) : false);
            if (item.id === "settings" || item.id === "flashlight") return false;
            seenIds.add(item.id);
            return true;
        });

        const forceIds = ["airplane", "idleInhibit", "gameMode", "dnd"];
        forceIds.forEach(id => {
            if (!seenIds.has(id)) filtered.push({ id: id, enabled: true });
        });
        return filtered;
    }

    function toggleStagger(toggleId: string): int {
        return 0;
    }

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2
    radius: (typeof Config !== "undefined" && Config && Config.border) ? Config.border.drawerRounding : Tokens.rounding.normal
    
    color: Colours.tileGlassStrong

    StyledRect {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.color: Colours.tileShine
        border.width: 1
    }

    StyledRect {
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius - 1
        color: "transparent"
        border.color: Colours.tileShineSoft
        border.width: 1
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.normal

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                text: qsTr("Quick Toggles")
                textPointSize: Tokens.font.size.normal
                Layout.fillWidth: true
            }
            IconButton {
                icon: "settings"
                onClicked: {
                    root.visibilities.qspanel = false;
                    // Real floating window (same as IPC / shortcut), not bar overlay
                    WindowFactory.create();
                }
            }
            IconButton {
                icon: "keyboard"
                onClicked: {
                    const willOpen = !root.visibilities.osk;
                    root.visibilities.osk = willOpen;
                    if (willOpen) {
                        root.visibilities.qspanel = false;
                    }
                }
            }
            IconButton {
                icon: "power_settings_new"
                onClicked: {
                    root.visibilities.qspanel = false;
                    root.visibilities.powermenu = !root.visibilities.powermenu;
                }
            }
        }

        GridLayout {
            id: grid
            Layout.fillWidth: true
            columns: 3
            columnSpacing: Tokens.spacing.small
            rowSpacing: Tokens.spacing.small

            Repeater {
                model: root.quickToggles
                delegate: DelegateChooser {
                    role: "id"
                    DelegateChoice {
                        roleValue: "wifi"
                        delegate: QuickToggleTile {
                            staggerIndex: root.toggleStagger("wifi")
                            isPanelVisible: root.visibilities.qspanel
                            id: wifiTile
                            Layout.fillWidth: true
                            icon: {
                                if (Nmcli.activeEthernet && Nmcli.activeEthernet.connected) return "settings_ethernet";
                                if (Nmcli.wifiEnabled && Nmcli.active) return "wifi";
                                if (!Nmcli.hasWifiHw && Nmcli.hasEthernetHw) return "settings_ethernet";
                                return "wifi";
                            }
                            label: {
                                if (!Nmcli.hasWifiHw && !Nmcli.hasEthernetHw) return qsTr("Internet");
                                if (Nmcli.activeEthernet && Nmcli.activeEthernet.connected) {
                                    return (Nmcli.activeEthernet.connection && Nmcli.activeEthernet.connection.length > 0) ? Nmcli.activeEthernet.connection : qsTr("Ethernet");
                                }
                                if (Nmcli.wifiEnabled && Nmcli.active && Nmcli.active.ssid) {
                                    return Nmcli.active.ssid;
                                }
                                return qsTr("Internet");
                            }
                            stateText: {
                                if (!Nmcli.hasWifiHw && !Nmcli.hasEthernetHw) {
                                    return qsTr("Compatible HW not found");
                                }
                                if (Nmcli.activeEthernet && Nmcli.activeEthernet.connected) {
                                    return qsTr("Connected");
                                }
                                if (Nmcli.hasWifiHw) {
                                    if (Nmcli.wifiEnabled) {
                                        return Nmcli.active ? qsTr("Connected") : qsTr("On");
                                    }
                                    return qsTr("Off");
                                }
                                if (Nmcli.hasEthernetHw) {
                                    return qsTr("Disconnected");
                                }
                                return qsTr("Off");
                            }
                            disabled: !Nmcli.hasWifiHw && !Nmcli.hasEthernetHw
                            checked: (Nmcli.hasWifiHw && Nmcli.wifiEnabled) || (Nmcli.hasEthernetHw && Nmcli.activeEthernet && Nmcli.activeEthernet.connected)
                            isExpanding: root.props.expansionActive === "network" || (root.props.isTransitioning && root.props.expansionSourceItem === wifiTile)
                            onClicked: {
                                if (!Nmcli.hasWifiHw && !Nmcli.hasEthernetHw) return;
                                if (Nmcli.hasWifiHw) {
                                    Nmcli.toggleWifi();
                                } else if (Nmcli.hasEthernetHw) {
                                    Nmcli.toggleEthernet();
                                }
                            }
                            onHeld: {
                                if (!Nmcli.hasWifiHw && !Nmcli.hasEthernetHw) return;
                                const pos = wifiTile.mapToItem(null, 0, 0);
                                const localPos = wifiTile.mapToItem(root.contentRoot, 0, 0);
                                root.props.expansionSource = Qt.rect(pos.x, pos.y, wifiTile.width, wifiTile.height);
                                root.props.expansionLocalSource = Qt.point(localPos.x, localPos.y);
                                root.props.expansionSourceItem = wifiTile;
                                root.props.expansionActive = "network";
                            }
                        }
                    }
                    DelegateChoice {
                        roleValue: "bluetooth"
                        delegate: QuickToggleTile {
                            staggerIndex: root.toggleStagger("bluetooth")
                            isPanelVisible: root.visibilities.qspanel
                            id: btTile
                            Layout.fillWidth: true
                            icon: "bluetooth"
                            label: {
                                const connected = [...Bluetooth.devices.values].find(d => d.connected);
                                return connected ? (connected.name || connected.address || qsTr("Device")) : qsTr("Bluetooth");
                            }
                            stateText: {
                                if (!(Bluetooth.defaultAdapter?.enabled ?? false)) {
                                    return qsTr("Off");
                                }
                                const connectedDevices = [...Bluetooth.devices.values].filter(d => d.connected);
                                if (connectedDevices.length === 1) {
                                    const dev = connectedDevices[0];
                                    if (dev.batteryAvailable) {
                                        return `${Math.round(dev.battery * 100)}%`;
                                    }
                                    return qsTr("Connected");
                                } else if (connectedDevices.length > 1) {
                                    return qsTr("%1 Connected").arg(connectedDevices.length);
                                }
                                return qsTr("On");
                            }
                            checked: Bluetooth.defaultAdapter?.enabled ?? false
                            deviceConnected: (Bluetooth.defaultAdapter?.enabled ?? false) && Bluetooth.devices.values.some(d => d.connected)
                            isExpanding: root.props.expansionActive === "bluetooth" || (root.props.isTransitioning && root.props.expansionSourceItem === btTile)
                            onClicked: {
                                const adapter = Bluetooth.defaultAdapter;
                                if (adapter) adapter.enabled = !adapter.enabled;
                            }
                            onHeld: {
                                const pos = btTile.mapToItem(null, 0, 0);
                                const localPos = btTile.mapToItem(root.contentRoot, 0, 0);
                                root.props.expansionSource = Qt.rect(pos.x, pos.y, btTile.width, btTile.height);
                                root.props.expansionLocalSource = Qt.point(localPos.x, localPos.y);
                                root.props.expansionSourceItem = btTile;
                                root.props.expansionActive = "bluetooth";
                            }
                        }
                    }
                    DelegateChoice {
                        roleValue: "mic"
                        delegate: QuickToggleTile {
                            staggerIndex: root.toggleStagger("mic")
                            isPanelVisible: root.visibilities.qspanel
                            Layout.fillWidth: true
                            icon: "mic"
                            label: qsTr("Microphone")
                            stateText: !Audio.sourceMuted ? qsTr("Active") : qsTr("Off")
                            checked: !Audio.sourceMuted
                            onClicked: {
                                const src = Audio.source;
                                if (src?.ready && src?.audio) src.audio.muted = !src.audio.muted;
                            }
                        }
                    }
                    DelegateChoice {
                        roleValue: "warp"
                        delegate: QuickToggleTile {
                            staggerIndex: root.toggleStagger("warp")
                            isPanelVisible: root.visibilities.qspanel
                            Layout.fillWidth: true
                            icon: "vpn_lock"
                            label: qsTr("1.1.1.1")
                            stateText: checked ? qsTr("Connected") : qsTr("Disconnected")
                            checked: root.warpConnected
                            onClicked: {
                                const targetState = !root.warpConnected;
                                warpActionProc.command = ["/usr/bin/warp-cli", targetState ? "connect" : "disconnect"];
                                warpActionProc.running = true;
                                root.warpConnected = targetState;
                            }
                        }
                    }
                    DelegateChoice {
                        roleValue: "airplane"
                        delegate: QuickToggleTile {
                            staggerIndex: root.toggleStagger("airplane")
                            isPanelVisible: root.visibilities.qspanel
                            Layout.fillWidth: true
                            icon: checked ? "airplanemode_active" : "airplanemode_inactive"
                            label: qsTr("Airplane Mode")
                            stateText: checked ? qsTr("On") : qsTr("Off")
                            property bool airplaneEnabled: false
                            checked: airplaneEnabled
                            onClicked: airplaneEnabled = !airplaneEnabled
                        }
                    }
                    DelegateChoice {
                        roleValue: "gameMode"
                        delegate: QuickToggleTile {
                            staggerIndex: root.toggleStagger("gameMode")
                            isPanelVisible: root.visibilities.qspanel
                            Layout.fillWidth: true
                            icon: "gamepad"
                            label: qsTr("Game Mode")
                            stateText: GameMode.enabled ? qsTr("On") : qsTr("Off")
                            checked: GameMode.enabled
                            onClicked: GameMode.enabled = !GameMode.enabled
                        }
                    }
                    DelegateChoice {
                        roleValue: "dnd"
                        delegate: QuickToggleTile {
                            staggerIndex: root.toggleStagger("dnd")
                            isPanelVisible: root.visibilities.qspanel
                            Layout.fillWidth: true
                            icon: "notifications_off"
                            label: qsTr("DND")
                            stateText: Notifs.dnd ? qsTr("On") : qsTr("Off")
                            checked: Notifs.dnd
                            onClicked: Notifs.dnd = !Notifs.dnd
                        }
                    }
                    DelegateChoice {
                        roleValue: "idleInhibit"
                        delegate: QuickToggleTile {
                            staggerIndex: root.toggleStagger("idleInhibit")
                            isPanelVisible: root.visibilities.qspanel
                            Layout.fillWidth: true
                            icon: "coffee"
                            label: qsTr("Keep Awake")
                            stateText: IdleInhibitor.enabled ? qsTr("On") : qsTr("Off")
                            checked: IdleInhibitor.enabled
                            onClicked: IdleInhibitor.enabled = !IdleInhibitor.enabled
                        }
                    }
                    DelegateChoice {
                        roleValue: "vpn"
                        delegate: QuickToggleTile {
                            staggerIndex: root.toggleStagger("vpn")
                            isPanelVisible: root.visibilities.qspanel
                            Layout.fillWidth: true
                            icon: "vpn_key"
                            label: qsTr("VPN")
                            stateText: VPN.connected ? qsTr("On") : qsTr("Off")
                            checked: VPN.connected && VPN.status.state !== "needs-auth" && VPN.status.state !== "error"
                            onClicked: VPN.toggle()
                        }
                    }
                }
            }

            // Grouped Custom Pills Column in Row 2, Column 2 next to Keep Awake
            ColumnLayout {
                id: customPillsColumn
                Layout.row: 2
                Layout.column: 2
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Tokens.spacing.small

                // Power Profile Switcher Pill
                StyledRect {
                    id: powerProfilePill
                    Layout.fillWidth: true
                    implicitHeight: (110 - customPillsColumn.spacing) / 2
                    color: Colours.tileFill
                    border.color: "transparent"
                    border.width: 0
                    radius: Tokens.rounding.full

                    property string current: {
                        const p = PowerProfiles.profile;
                        if (p === PowerProfile.PowerSaver)
                            return saver.icon;
                        if (p === PowerProfile.Performance)
                            return perf.icon;
                        return balance.icon;
                    }

                    StyledRect {
                        id: profileIndicator
                        height: saver.implicitHeight
                        width: height
                        color: Colours.palette.m3primary
                        radius: Tokens.rounding.full
                        anchors.verticalCenter: parent.verticalCenter

                        x: {
                            if (powerProfilePill.current === saver.icon)
                                return saver.x;
                            if (powerProfilePill.current === perf.icon)
                                return perf.x;
                            return balance.x;
                        }

                        Behavior on x {
                            Anim { type: Anim.DefaultSpatial }
                        }
                    }

                    ProfileBtn {
                        id: saver
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: Tokens.padding.small
                        profile: PowerProfile.PowerSaver
                        icon: "energy_savings_leaf"
                    }

                    ProfileBtn {
                        id: balance
                        anchors.centerIn: parent
                        profile: PowerProfile.Balanced
                        icon: "balance"
                    }

                    ProfileBtn {
                        id: perf
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: Tokens.padding.small
                        profile: PowerProfile.Performance
                        icon: "rocket_launch"
                    }
                }

                // Expandable Display Projection Pill
                StyledRect {
                    id: displayProjectionPill
                    Layout.fillWidth: true
                    implicitHeight: (110 - customPillsColumn.spacing) / 2
                    color: Colours.tileFill
                    border.color: "transparent"
                    border.width: 0
                    radius: Tokens.rounding.full
                    clip: true

                    // Required properties so it acts exactly like a tile for ExpansionOverlay!
                    property bool checked: true
                    property bool isExpanding: root.props.expansionActive === "displayprojection" || (root.props.isTransitioning && root.props.expansionSourceItem === displayProjectionPill)

                    opacity: isExpanding ? 0 : 1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }

                    StateLayer {
                        radius: parent.radius
                        onClicked: {
                            const pos = displayProjectionPill.mapToItem(null, 0, 0);
                            const localPos = displayProjectionPill.mapToItem(root.contentRoot, 0, 0);
                            root.props.expansionSource = Qt.rect(pos.x, pos.y, displayProjectionPill.width, displayProjectionPill.height);
                            root.props.expansionLocalSource = Qt.point(localPos.x, localPos.y);
                            root.props.expansionSourceItem = displayProjectionPill;
                            root.props.expansionActive = "displayprojection";
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.normal
                        anchors.rightMargin: Tokens.padding.normal
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: {
                                const mode = DisplayProjection.activeProjection;
                                if (mode === "primary") return "laptop";
                                if (mode === "secondary") return "tv";
                                if (mode === "mirror") return "sync";
                                return "grid_view";
                            }
                            color: Colours.palette.m3onSurface
                            iconPointSize: Tokens.font.size.normal
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item {
                            id: dpMarqueeContainer
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            readonly property bool needsMarquee: dpLabelText.implicitWidth > width
                            readonly property real speed: 30 // pixels per second

                            // Edge Fading Mask
                            layer.enabled: needsMarquee
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: ShaderEffectSource {
                                    sourceItem: Rectangle {
                                        width: dpMarqueeContainer.width
                                        height: dpMarqueeContainer.height
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: "transparent" }
                                            GradientStop { position: 0.1; color: "black" }
                                            GradientStop { position: 0.9; color: "black" }
                                            GradientStop { position: 1.0; color: "transparent" }
                                        }
                                    }
                                }
                            }

                            Row {
                                id: dpMarqueeRow
                                spacing: 40
                                property real marqueeX: 0
                                height: parent.height

                                anchors.horizontalCenter: dpMarqueeContainer.needsMarquee ? undefined : dpMarqueeContainer.horizontalCenter
                                x: dpMarqueeContainer.needsMarquee ? dpMarqueeRow.marqueeX : 0

                                StyledText {
                                    id: dpLabelText
                                    text: {
                                        const mode = DisplayProjection.activeProjection;
                                        if (mode === "primary") return qsTr("Primary");
                                        if (mode === "secondary") return qsTr("Secondary Only");
                                        if (mode === "mirror") return qsTr("Mirror");
                                        return qsTr("Extend");
                                    }
                                    color: Colours.palette.m3onSurface
                                    textPointSize: Tokens.font.size.small
                                    font.bold: true
                                    verticalAlignment: Text.AlignVCenter
                                    height: parent.height
                                }

                                // Duplicate text for seamless loop
                                StyledText {
                                    text: dpLabelText.text
                                    textPointSize: dpLabelText.textPointSize
                                    font.bold: dpLabelText.font.bold
                                    color: dpLabelText.color
                                    visible: dpMarqueeContainer.needsMarquee
                                    verticalAlignment: Text.AlignVCenter
                                    height: parent.height
                                }

                                SequentialAnimation {
                                    id: dpMarqueeAnim
                                    running: dpMarqueeContainer.needsMarquee && root.visibilities.qspanel
                                    loops: Animation.Infinite

                                    PauseAnimation { duration: 1200 }

                                    NumberAnimation {
                                        target: dpMarqueeRow
                                        property: "marqueeX"
                                        from: 0
                                        to: -(dpLabelText.implicitWidth + 40)
                                        duration: Math.max(1800, (dpLabelText.implicitWidth) * 1000 / dpMarqueeContainer.speed)
                                        easing.type: Easing.Linear
                                    }
                                }
                            }
                        }

                        MaterialIcon {
                            text: "chevron_right"
                            color: Colours.palette.m3onSurfaceVariant
                            iconPointSize: Tokens.font.size.normal
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }
        }
    }

    component ProfileBtn: Item {
        required property string icon
        required property int profile

        implicitWidth: icon.implicitHeight + Tokens.padding.small * 2
        implicitHeight: icon.implicitHeight + Tokens.padding.small * 2

        StateLayer {
            radius: Tokens.rounding.full
            color: powerProfilePill.current === parent.icon ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            onClicked: PowerProfiles.profile = parent.profile
        }

        MaterialIcon {
            id: icon

            anchors.centerIn: parent

            text: parent.icon
            iconPointSize: Tokens.font.size.large
            color: powerProfilePill.current === text ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            fill: powerProfilePill.current === text ? 1 : 0

            Behavior on fill {
                Anim {}
            }
        }
    }
}
