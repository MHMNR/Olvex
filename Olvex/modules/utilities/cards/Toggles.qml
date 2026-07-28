pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.bar.popouts as BarPopouts
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

    Process {
        id: warpStatusProc
        command: ["/usr/bin/warp-cli", "status"]
        running: true
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
        onExited: code => warpStatusProc.running = true
    }

    readonly property var quickToggles: {
        const seenIds = new Set();
        let filtered = Config.utilities.quickToggles.filter(item => {
            if (!(item.enabled ?? true)) return false;
            if (seenIds.has(item.id)) return false;
            if (item.id === "vpn") return GlobalConfig.utilities.vpn.provider.some(p => typeof p === "object" ? (p.enabled === true) : false);
            if (item.id === "settings" || item.id === "flashlight") return false;
            seenIds.add(item.id);
            return true;
        });

        const forceIds = ["warp", "airplane", "idleInhibit", "gameMode", "dnd"];
        forceIds.forEach(id => {
            if (!seenIds.has(id)) filtered.push({ id: id, enabled: true });
        });
        return filtered;
    }

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2
    radius: Tokens.rounding.normal
    
    // Premium Glass Background
    color: Qt.rgba(1.0, 1.0, 1.0, 0.06)
    
    // Outer Shine Border
    StyledRect {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.15)
        border.width: 1
    }

    // Inner Soft Glow
    StyledRect {
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius - 1
        color: "transparent"
        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.05)
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
                    root.visibilities.utilities = false;
                    root.popouts.detach("launcher");
                }
            }
            IconButton {
                icon: "keyboard"
                onClicked: {
                    root.visibilities.osk = !root.visibilities.osk;
                }
            }
            IconButton {
                icon: "power_settings_new"
                onClicked: {
                    root.visibilities.utilities = false;
                    root.visibilities.session = !root.visibilities.session;
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
                            staggerIndex: index * 50
                            isPanelVisible: root.visibilities.utilities
                            id: wifiTile
                            Layout.fillWidth: true
                            icon: "wifi"
                            label: (Nmcli.wifiEnabled && Nmcli.active) ? Nmcli.active.ssid : qsTr("Wi-Fi")
                            stateText: Nmcli.wifiEnabled ? qsTr("On") : qsTr("Off")
                            checked: Nmcli.wifiEnabled
                            isExpanding: root.props.expansionActive === "network" || (root.props.isTransitioning && root.props.expansionSourceItem === wifiTile)
                            onClicked: Nmcli.toggleWifi()
                            onHeld: {
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
                            staggerIndex: index * 50
                            isPanelVisible: root.visibilities.utilities
                            id: btTile
                            Layout.fillWidth: true
                            icon: "bluetooth"
                            label: {
                                const connected = [...Bluetooth.devices.values].find(d => d.connected);
                                return connected ? connected.name : qsTr("Bluetooth");
                            }
                            stateText: (Bluetooth.defaultAdapter?.enabled ?? false) ? qsTr("On") : qsTr("Off")
                            checked: Bluetooth.defaultAdapter?.enabled ?? false
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
                            staggerIndex: index * 50
                            isPanelVisible: root.visibilities.utilities
                            Layout.fillWidth: true
                            icon: "mic"
                            label: qsTr("Microphone")
                            stateText: !Audio.sourceMuted ? qsTr("Active") : qsTr("Off")
                            checked: !Audio.sourceMuted
                            onClicked: {
                                const audio = Audio.source?.audio;
                                if (audio) audio.muted = !audio.muted;
                            }
                        }
                    }
                    DelegateChoice {
                        roleValue: "warp"
                        delegate: QuickToggleTile {
                            staggerIndex: index * 50
                            isPanelVisible: root.visibilities.utilities
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
                            staggerIndex: index * 50
                            isPanelVisible: root.visibilities.utilities
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
                            staggerIndex: index * 50
                            isPanelVisible: root.visibilities.utilities
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
                            staggerIndex: index * 50
                            isPanelVisible: root.visibilities.utilities
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
                            staggerIndex: index * 50
                            isPanelVisible: root.visibilities.utilities
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
                            staggerIndex: index
                            isPanelVisible: root.visibilities.utilities
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
                    color: Qt.rgba(1.0, 1.0, 1.0, 0.03)
                    border.color: Qt.alpha("#ff99cc", 0.12)
                    border.width: 1
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
                    color: Qt.rgba(1.0, 1.0, 1.0, 0.03)
                    border.color: Qt.alpha("#ff99cc", 0.12)
                    border.width: 1
                    radius: Tokens.rounding.full
                    clip: true

                    // Required properties so it acts exactly like a tile for ExpansionOverlay!
                    property bool checked: true
                    property bool isExpanding: root.props.expansionActive === "displayprojection" || (root.props.isTransitioning && root.props.expansionSourceItem === displayProjectionPill)
                    opacity: isExpanding ? 0 : 1

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
                                    font: dpLabelText.font
                                    color: dpLabelText.color
                                    visible: dpMarqueeContainer.needsMarquee
                                    verticalAlignment: Text.AlignVCenter
                                    height: parent.height
                                }

                                SequentialAnimation {
                                    id: dpMarqueeAnim
                                    running: dpMarqueeContainer.needsMarquee && root.visibilities.utilities
                                    loops: Animation.Infinite

                                    PauseAnimation { duration: 2500 }

                                    NumberAnimation {
                                        target: dpMarqueeRow
                                        property: "marqueeX"
                                        from: 0
                                        to: -(dpLabelText.implicitWidth + 40)
                                        duration: Math.max(3000, (dpLabelText.implicitWidth) * 1000 / dpMarqueeContainer.speed)
                                        easing.type: Easing.InOutQuad
                                    }

                                    PauseAnimation { duration: 1500 }

                                    PropertyAnimation { target: dpMarqueeRow; property: "opacity"; to: 0; duration: 400 }
                                    PropertyAction { target: dpMarqueeRow; property: "marqueeX"; value: 0 }
                                    PropertyAnimation { target: dpMarqueeRow; property: "opacity"; to: 1; duration: 400 }
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
