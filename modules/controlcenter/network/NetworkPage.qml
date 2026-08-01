pragma ComponentBehavior: Bound

// Network settings: Wi‑Fi, Bluetooth + AP list.

import ".."
import "../chrome"
import "."
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    property Session session
    signal back

    property string selectedSsid: ""
    property bool showAddNetwork: false
    property var networkList: []

    readonly property string connectingSsid: Nmcli.pendingConnection?.ssid ?? ""

    readonly property bool btEnabled: Bluetooth.defaultAdapter?.enabled ?? false
    readonly property var btDevices: {
        const vals = Bluetooth.devices?.values;
        if (!vals)
            return [];
        return [...vals].sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || (a.name || "").localeCompare(b.name || "")).slice(0, 24);
    }
    readonly property int btConnectedCount: btDevices.filter(d => d.connected).length
    readonly property string btStatusText: {
        if (!Bluetooth.defaultAdapter)
            return qsTr("No adapter");
        if (!root.btEnabled)
            return qsTr("Off");
        if (root.btConnectedCount > 0)
            return qsTr("On · %1 connected").arg(root.btConnectedCount);
        return qsTr("On · %1 device%2").arg(root.btDevices.length).arg(root.btDevices.length === 1 ? "" : "s");
    }


    function toggleBluetooth(on: bool): void {
        const adapter = Bluetooth.defaultAdapter;
        if (!adapter)
            return;
        adapter.enabled = on;
        if (on)
            adapter.discovering = true;
    }


    function refreshNetworkList(): void {
        const connecting = root.connectingSsid;
        const rank = n => {
            if (n.active)
                return 0;
            if (n.ssid === connecting)
                return 1;
            if (Nmcli.hasSavedProfile(n.ssid))
                return 2;
            return 3;
        };
        const src = Nmcli.networks || [];
        const copy = [];
        for (let i = 0; i < src.length; i++)
            copy.push(src[i]);
        copy.sort((a, b) => rank(a) - rank(b) || b.strength - a.strength);
        root.networkList = copy;
    }

    function sortedNetworks(): var {
        return root.networkList;
    }

    function handleApClick(ap): void {
        if (!ap || ap.active)
            return;
        if (root.connectingSsid === ap.ssid)
            return;
        root.selectedSsid = ap.ssid;
        NetworkConnection.handleConnect(ap, root.session);
    }

    function submitAddNetwork(): void {
        const ssid = addSsidField.text.trim();
        if (!ssid)
            return;
        const ap = {
            ssid: ssid,
            bssid: "",
            isSecure: addPasswordField.text.length > 0,
            security: addPasswordField.text.length > 0 ? "WPA" : "",
            strength: 0,
            active: false
        };
        if (addPasswordField.text.length > 0) {
            NetworkConnection.connectWithPassword(ap, addPasswordField.text, () => {
                root.showAddNetwork = false;
                addSsidField.text = "";
                addPasswordField.text = "";
                root.selectedSsid = "";
                Nmcli.rescanWifi();
                root.refreshNetworkList();
            });
        } else {
            // Session handles password dialog if needed
            root.selectedSsid = ssid;
            NetworkConnection.handleConnect(ap, root.session);
            root.showAddNetwork = false;
            addSsidField.text = "";
            addPasswordField.text = "";
        }
    }

    Component.onCompleted: {
        Nmcli.getWifiStatus();
        if (Nmcli.wifiEnabled)
            Nmcli.rescanWifi();
        Nmcli.loadSavedConnections(() => {});
        root.refreshNetworkList();
    }

    // Auto-rescan while visible + wifi on (Caelestia parity)
    Timer {
        running: root.visible && Nmcli.wifiEnabled
        repeat: true
        triggeredOnStart: true
        interval: 10000
        onTriggered: Nmcli.rescanWifi()
    }

    Timer {
        id: wifiScanDelay
        interval: 100
        onTriggered: Nmcli.rescanWifi()
    }

    // Keep list sorted when APs / connect state change
    Timer {
        id: listRefreshTimer
        interval: 250
        running: root.visible
        repeat: true
        onTriggered: root.refreshNetworkList()
    }

    Connections {
        target: Nmcli
        function onWifiEnabledChanged(): void {
            if (Nmcli.wifiEnabled)
                wifiScanDelay.start();
            root.refreshNetworkList();
        }
        function onNetworksChanged(): void {
            root.refreshNetworkList();
        }
        function onPendingConnectionChanged(): void {
            root.refreshNetworkList();
            if (!Nmcli.pendingConnection)
                root.selectedSsid = "";
        }
        function onActiveChanged(): void {
            root.refreshNetworkList();
            if (Nmcli.active)
                root.selectedSsid = "";
        }
    }



    SettingsPage {
        id: page

        anchors.fill: parent
        title: qsTr("Network")
        subtitle: qsTr("Wi‑Fi and Bluetooth")
        icon: "wifi"
        accent: Colours.palette.m3primary
        onBack: root.back()

        // Wi‑Fi → toggle + list · Bluetooth → toggle + devices

        // ── Wi‑Fi ───────────────────────────────────────────────────────
        SettingRow {
            Layout.fillWidth: true
            title: qsTr("Wi‑Fi")
            description: {
                if (!Nmcli.wifiEnabled)
                    return qsTr("Off");
                if (Nmcli.scanning)
                    return Nmcli.active ? qsTr("Scanning… · %1").arg(Nmcli.active.ssid) : qsTr("Scanning…");
                if (Nmcli.active)
                    return qsTr("Connected to %1").arg(Nmcli.active.ssid);
                return qsTr("On · Not connected");
            }
            icon: "wifi"
            divider: false

            // Same M3 Expressive scan UX as Bluetooth
            Row {
                spacing: Tokens.spacing.small

                Item {
                    id: wifiScanCtl

                    readonly property bool scanning: Nmcli.scanning
                    readonly property bool canScan: Nmcli.wifiEnabled

                    implicitWidth: 40
                    implicitHeight: 40

                    LoadingIndicator {
                        anchors.centerIn: parent
                        implicitSize: 32
                        color: Colours.palette.m3primary
                        animated: wifiScanCtl.scanning
                        opacity: wifiScanCtl.scanning ? 1 : 0
                        scale: wifiScanCtl.scanning ? 1 : 0.72
                        visible: opacity > 0.01

                        Behavior on opacity {
                            Anim {
                                type: Anim.FastEffects
                            }
                        }
                        Behavior on scale {
                            Anim {
                                type: Anim.DefaultSpatial
                            }
                        }
                    }

                    IconButton {
                        anchors.centerIn: parent
                        type: IconButton.Text
                        icon: "refresh"
                        disabled: !wifiScanCtl.canScan
                        opacity: wifiScanCtl.scanning ? 0 : 1
                        visible: opacity > 0.01
                        enabled: wifiScanCtl.canScan && !wifiScanCtl.scanning

                        Behavior on opacity {
                            Anim {
                                type: Anim.FastEffects
                            }
                        }

                        onClicked: {
                            if (Nmcli.wifiEnabled)
                                Nmcli.rescanWifi();
                        }
                    }
                }

                StyledSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Nmcli.wifiEnabled
                    onToggled: Nmcli.enableWifi(checked)
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            visible: Nmcli.wifiEnabled
            radius: Tokens.rounding.normal
            color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
            implicitHeight: wifiListCol.implicitHeight + Tokens.padding.normal * 2
            clip: true
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.3)

            Column {
                id: wifiListCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.small
                spacing: 0

                Item {
                    width: parent.width
                    height: 96
                    visible: root.networkList.length === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.normal

                        LoadingIndicator {
                            anchors.horizontalCenter: parent.horizontalCenter
                            implicitSize: 36
                            color: Colours.palette.m3primary
                            animated: Nmcli.scanning
                            opacity: Nmcli.scanning ? 1 : 0.45
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Nmcli.scanning ? qsTr("Scanning for networks…") : qsTr("No networks found · tap refresh")
                            color: Colours.palette.m3onSurfaceVariant
                            font.weight: Font.Normal
                            textPointSize: Tokens.font.size.normal
                        }
                    }
                }

                Repeater {
                    model: root.networkList

                    delegate: Item {
                        id: network

                        required property var modelData
                        readonly property bool isConnecting: root.connectingSsid === modelData.ssid || (root.selectedSsid === modelData.ssid && !modelData.active)
                        readonly property real textOpacity: isConnecting ? 0.55 : 1

                        width: parent ? parent.width : 0
                        height: wifiRow.implicitHeight + Tokens.padding.large * 2

                        StyledRect {
                            anchors.fill: parent
                            radius: Tokens.rounding.small
                            color: modelData.active ? Qt.alpha(Colours.palette.m3primary, 0.10) : "transparent"
                        }

                        RowLayout {
                            id: wifiRow
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.padding.large
                            anchors.rightMargin: Tokens.padding.large
                            anchors.topMargin: Tokens.padding.normal
                            anchors.bottomMargin: Tokens.padding.normal
                            spacing: Tokens.spacing.normal

                            MaterialIcon {
                                text: Icons.getNetworkIcon(network.modelData.strength, network.modelData.isSecure)
                                color: network.modelData.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                iconPointSize: Tokens.font.size.large
                                opacity: network.textOpacity
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                opacity: network.textOpacity

                                StyledText {
                                    Layout.fillWidth: true
                                    text: network.modelData.ssid || qsTr("Hidden network")
                                    elide: Text.ElideRight
                                    font.weight: Font.Normal
                                    color: network.modelData.active ? Colours.palette.m3primary : Colours.palette.m3onSurface
                                    textPointSize: Tokens.font.size.normal
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: {
                                        const sec = network.modelData.security || (network.modelData.isSecure ? qsTr("Secured") : qsTr("Open"));
                                        const saved = Nmcli.hasSavedProfile(network.modelData.ssid) ? qsTr(" · Saved") : "";
                                        return qsTr("%1%2").arg(sec).arg(saved);
                                    }
                                    elide: Text.ElideRight
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.weight: Font.Normal
                                    textPointSize: Tokens.font.size.small
                                }
                            }

                            // Status pill is the only clickable target (not the whole row)
                            StyledRect {
                                id: wifiPill
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: wifiPillRow.implicitWidth + Tokens.padding.normal * 2
                                implicitHeight: 26
                                radius: height / 2
                                opacity: network.textOpacity
                                color: {
                                    if (network.isConnecting)
                                        return Qt.alpha(Colours.palette.m3primary, 0.16);
                                    if (network.modelData.active)
                                        return Colours.palette.m3primaryContainer;
                                    return Colours.palette.m3surfaceContainerHighest;
                                }

                                Row {
                                    id: wifiPillRow
                                    anchors.centerIn: parent
                                    spacing: Tokens.spacing.extraSmall

                                    LoadingIndicator {
                                        anchors.verticalCenter: parent.verticalCenter
                                        implicitSize: 14
                                        color: Colours.palette.m3primary
                                        animated: network.isConnecting
                                        visible: network.isConnecting
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: {
                                            if (network.isConnecting)
                                                return qsTr("Connecting");
                                            if (network.modelData.active)
                                                return qsTr("Connected");
                                            return qsTr("Available");
                                        }
                                        color: {
                                            if (network.isConnecting)
                                                return Colours.palette.m3primary;
                                            if (network.modelData.active)
                                                return Colours.palette.m3onPrimaryContainer;
                                            return Colours.palette.m3onSurfaceVariant;
                                        }
                                        font.weight: Font.Normal
                                        font.letterSpacing: 0.15
                                        textPointSize: Tokens.font.size.small
                                    }
                                }

                                StateLayer {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    interactive: !network.modelData.active && !network.isConnecting
                                    disabled: network.modelData.active || network.isConnecting
                                    onClicked: root.handleApClick(network.modelData)
                                }
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Tokens.padding.large
                            anchors.rightMargin: Tokens.padding.large
                            height: 1
                            color: Qt.alpha(Colours.palette.m3outlineVariant, 0.35)
                        }
                    }
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            visible: Nmcli.wifiEnabled
            radius: Tokens.rounding.normal
            color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
            implicitHeight: addCol.implicitHeight + Tokens.padding.large * 2
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.3)

            Column {
                id: addCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.normal

                Item {
                    width: parent.width
                    height: 44

                    RowLayout {
                        anchors.fill: parent
                        spacing: Tokens.spacing.normal
                        MaterialIcon {
                            text: "add"
                            iconPointSize: Tokens.font.size.large
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Add network")
                            font.weight: Font.Normal
                            textPointSize: Tokens.font.size.normal
                        }
                        MaterialIcon {
                            text: root.showAddNetwork ? "expand_less" : "expand_more"
                            color: Colours.palette.m3onSurfaceVariant
                            iconPointSize: Tokens.font.size.large
                        }
                    }

                    StateLayer {
                        radius: Tokens.rounding.normal
                        onClicked: root.showAddNetwork = !root.showAddNetwork
                    }
                }

                Column {
                    width: parent.width
                    visible: root.showAddNetwork
                    spacing: Tokens.spacing.normal

                    SettingRow {
                        title: qsTr("Network name")
                        description: qsTr("SSID of the hidden or manual network")
                        divider: true
                        StyledTextField {
                            id: addSsidField
                            width: 200
                            placeholderText: qsTr("SSID")
                        }
                    }

                    SettingRow {
                        title: qsTr("Password")
                        description: qsTr("Leave empty for open networks")
                        divider: false
                        StyledTextField {
                            id: addPasswordField
                            width: 200
                            echoMode: TextInput.Password
                            placeholderText: qsTr("Optional")
                            onAccepted: root.submitAddNetwork()
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        StyledRect {
                            implicitWidth: joinLbl.implicitWidth + Tokens.padding.large * 2
                            implicitHeight: 36
                            radius: Tokens.rounding.full
                            color: Colours.palette.m3primary
                            StyledText {
                                id: joinLbl
                                anchors.centerIn: parent
                                text: qsTr("Join")
                                color: Colours.palette.m3onPrimary
                                font.weight: Font.Normal
                                textPointSize: Tokens.font.size.small
                            }
                            StateLayer {
                                radius: parent.radius
                                color: Colours.palette.m3onPrimary
                                onClicked: root.submitAddNetwork()
                            }
                        }
                    }
                }
            }
        }

        // ── Bluetooth ───────────────────────────────────────────────────
        SettingRow {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.large
            title: qsTr("Bluetooth")
            description: {
                if (!root.btEnabled)
                    return root.btStatusText;
                if (Bluetooth.defaultAdapter?.discovering)
                    return qsTr("%1 · Scanning…").arg(root.btStatusText);
                return root.btStatusText;
            }
            icon: "bluetooth"
            divider: false

            // Rescan / M3 Expressive loader beside power toggle
            Row {
                spacing: Tokens.spacing.small

                // Idle: refresh icon · Scanning: Play Store–style LoadingIndicator
                // (M3 Expressive morphing shape — SoftBurst→Cookie→Pill→Sunny…)
                Item {
                    id: btScanCtl

                    readonly property bool scanning: Bluetooth.defaultAdapter?.discovering ?? false
                    readonly property bool canScan: root.btEnabled && !!Bluetooth.defaultAdapter

                    implicitWidth: 40
                    implicitHeight: 40

                    // M3 Expressive loading (same family as Google Play / Material loading)
                    LoadingIndicator {
                        anchors.centerIn: parent
                        implicitSize: 32
                        color: Colours.palette.m3primary
                        animated: btScanCtl.scanning
                        opacity: btScanCtl.scanning ? 1 : 0
                        scale: btScanCtl.scanning ? 1 : 0.72
                        visible: opacity > 0.01

                        Behavior on opacity {
                            Anim {
                                type: Anim.FastEffects
                            }
                        }
                        Behavior on scale {
                            Anim {
                                type: Anim.DefaultSpatial
                            }
                        }
                    }

                    IconButton {
                        anchors.centerIn: parent
                        type: IconButton.Text
                        icon: "refresh"
                        disabled: !btScanCtl.canScan
                        opacity: btScanCtl.scanning ? 0 : 1
                        visible: opacity > 0.01
                        // Keep hit target while idle only
                        enabled: btScanCtl.canScan && !btScanCtl.scanning

                        Behavior on opacity {
                            Anim {
                                type: Anim.FastEffects
                            }
                        }

                        onClicked: {
                            const a = Bluetooth.defaultAdapter;
                            if (!a || !root.btEnabled)
                                return;
                            // Restart discovery → LoadingIndicator takes over
                            if (a.discovering) {
                                a.discovering = false;
                                Qt.callLater(() => {
                                    if (Bluetooth.defaultAdapter)
                                        Bluetooth.defaultAdapter.discovering = true;
                                });
                            } else {
                                a.discovering = true;
                            }
                        }
                    }
                }

                StyledSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: root.btEnabled
                    enabled: !!Bluetooth.defaultAdapter
                    onToggled: root.toggleBluetooth(checked)
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            visible: root.btEnabled
            radius: Tokens.rounding.normal
            color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
            implicitHeight: btListCol.implicitHeight + Tokens.padding.normal * 2
            clip: true
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.3)

            Column {
                id: btListCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.small
                spacing: 0

                Item {
                    width: parent.width
                    height: 96
                    visible: root.btDevices.length === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.normal

                        LoadingIndicator {
                            anchors.horizontalCenter: parent.horizontalCenter
                            implicitSize: 36
                            color: Colours.palette.m3primary
                            animated: Bluetooth.defaultAdapter?.discovering ?? false
                            opacity: (Bluetooth.defaultAdapter?.discovering ?? false) ? 1 : 0.45
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (Bluetooth.defaultAdapter?.discovering ?? false) ? qsTr("Scanning for devices…") : qsTr("No devices yet · tap refresh")
                            color: Colours.palette.m3onSurfaceVariant
                            font.weight: Font.Normal
                            textPointSize: Tokens.font.size.normal
                        }
                    }
                }

                // Same row container as Wi‑Fi list (not SettingRow control slot)
                Repeater {
                    model: root.btDevices

                    delegate: Item {
                        id: btDev

                        required property var modelData
                        // BlueZ state — connected bool alone misses Connecting/Disconnecting
                        readonly property bool isConnecting: {
                            const s = modelData.state;
                            return s === BluetoothDeviceState.Connecting || s === BluetoothDeviceState.Disconnecting;
                        }
                        readonly property bool isConnected: modelData.connected && !btDev.isConnecting
                        readonly property real textOpacity: isConnecting ? 0.7 : 1

                        width: parent ? parent.width : 0
                        height: btRow.implicitHeight + Tokens.padding.large * 2

                        StyledRect {
                            anchors.fill: parent
                            radius: Tokens.rounding.small
                            color: btDev.isConnected ? Qt.alpha(Colours.palette.m3primary, 0.10) : "transparent"
                        }

                        RowLayout {
                            id: btRow
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.padding.large
                            anchors.rightMargin: Tokens.padding.large
                            anchors.topMargin: Tokens.padding.normal
                            anchors.bottomMargin: Tokens.padding.normal
                            spacing: Tokens.spacing.normal

                            MaterialIcon {
                                text: Icons.getBluetoothIcon(btDev.modelData.icon || "")
                                color: btDev.isConnected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                iconPointSize: Tokens.font.size.large
                                opacity: btDev.textOpacity
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                opacity: btDev.textOpacity

                                StyledText {
                                    Layout.fillWidth: true
                                    text: btDev.modelData.name || btDev.modelData.address || qsTr("Unknown device")
                                    elide: Text.ElideRight
                                    font.weight: Font.Normal
                                    color: btDev.isConnected ? Colours.palette.m3primary : Colours.palette.m3onSurface
                                    textPointSize: Tokens.font.size.normal
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: {
                                        if (btDev.modelData.paired || btDev.modelData.bonded)
                                            return qsTr("Paired");
                                        return qsTr("Nearby");
                                    }
                                    elide: Text.ElideRight
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.weight: Font.Normal
                                    textPointSize: Tokens.font.size.small
                                }
                            }

                            // Pill is the only clickable target
                            StyledRect {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: btPillRow.implicitWidth + Tokens.padding.normal * 2
                                implicitHeight: 26
                                radius: height / 2
                                color: {
                                    if (btDev.isConnecting)
                                        return Qt.alpha(Colours.palette.m3primary, 0.16);
                                    if (btDev.isConnected)
                                        return Colours.palette.m3primaryContainer;
                                    return Colours.palette.m3surfaceContainerHighest;
                                }

                                Row {
                                    id: btPillRow
                                    anchors.centerIn: parent
                                    spacing: Tokens.spacing.extraSmall

                                    LoadingIndicator {
                                        anchors.verticalCenter: parent.verticalCenter
                                        implicitSize: 14
                                        color: Colours.palette.m3primary
                                        animated: btDev.isConnecting
                                        visible: btDev.isConnecting
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: {
                                            if (btDev.isConnecting) {
                                                if (btDev.modelData.state === BluetoothDeviceState.Disconnecting)
                                                    return qsTr("Disconnecting");
                                                return qsTr("Connecting");
                                            }
                                            if (btDev.isConnected)
                                                return qsTr("Connected");
                                            return qsTr("Available");
                                        }
                                        color: {
                                            if (btDev.isConnecting)
                                                return Colours.palette.m3primary;
                                            if (btDev.isConnected)
                                                return Colours.palette.m3onPrimaryContainer;
                                            return Colours.palette.m3onSurfaceVariant;
                                        }
                                        font.weight: Font.Normal
                                        font.letterSpacing: 0.15
                                        textPointSize: Tokens.font.size.small
                                    }
                                }

                                StateLayer {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    interactive: !btDev.isConnecting
                                    disabled: btDev.isConnecting
                                    onClicked: {
                                        if (!btDev.isConnecting)
                                            btDev.modelData.connected = !btDev.modelData.connected;
                                    }
                                }
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Tokens.padding.large
                            anchors.rightMargin: Tokens.padding.large
                            height: 1
                            color: Qt.alpha(Colours.palette.m3outlineVariant, 0.35)
                        }
                    }
                }
            }
        }

    }

    // Password dialog overlay (session-driven, same as old control center)
    WirelessPasswordDialog {
        anchors.fill: parent
        z: 100
        session: root.session
    }
}
