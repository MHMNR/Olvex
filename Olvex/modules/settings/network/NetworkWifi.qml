
import ".."
import "../chrome"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Olvex.Config
import qs.services
import qs.utils

Item {
    id: root
    
    property Session session
    
    property string selectedSsid: ""
    property bool showAddNetwork: false
    property var networkList: []

    readonly property string connectingSsid: Nmcli.pendingConnection?.ssid ?? ""

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
        cascadeIn.start();
    }

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

    opacity: 0
    y: 10

    
    ParallelAnimation {
        id: cascadeIn
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens.anim.durations.slow; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens.anim.durations.slow; easing.type: Easing.OutCubic }
    }

    // We must define implicitHeight based on children because Loader uses it
    implicitHeight: (col ? col.implicitHeight : 0) + Tokens.padding.large * 2
    
    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Tokens.padding.large
        anchors.rightMargin: Tokens.padding.large
        anchors.topMargin: Tokens.padding.large
        spacing: Tokens.spacing.large

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
            divider: true

            Row {
                spacing: Tokens.spacing.small

                Item {
                    id: wifiScanCtl
                    readonly property bool scanning: Nmcli.scanning
                    readonly property bool canScan: Nmcli.wifiEnabled
                    implicitWidth: 36
                    implicitHeight: 36

                    CircularIndicator {
                        anchors.centerIn: parent
                        implicitSize: 24
                        running: wifiScanCtl.scanning
                        opacity: wifiScanCtl.scanning ? 1 : 0

                        Behavior on opacity { Anim { type: Anim.FastEffects } }
                    }

                    IconButton {
                        anchors.centerIn: parent
                        type: IconButton.Text
                        icon: "refresh"
                        disabled: !wifiScanCtl.canScan
                        opacity: wifiScanCtl.scanning ? 0 : 1
                        visible: opacity > 0.01
                        enabled: wifiScanCtl.canScan && !wifiScanCtl.scanning

                        Behavior on opacity { Anim { type: Anim.FastEffects } }
                        onClicked: if (Nmcli.wifiEnabled) Nmcli.rescanWifi()
                    }
                }

                StyledSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Nmcli.wifiEnabled
                    onToggled: Nmcli.enableWifi(checked)
                }
            }
        }

        Column {
            Layout.fillWidth: true
            visible: Nmcli.wifiEnabled
            spacing: 0

            Item {
                width: parent.width
                height: 96
                visible: root.networkList.length === 0

                Column {
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.normal

                    CircularIndicator {
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitSize: 32
                        running: Nmcli.scanning
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

                    RowLayout {
                        id: wifiRow
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.normal
                        anchors.rightMargin: Tokens.padding.normal
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

                        StyledRect {
                            id: wifiPill
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: wifiPillRow.implicitWidth + Tokens.padding.normal * 2
                            implicitHeight: 26
                            radius: height / 2
                            opacity: network.textOpacity
                            color: {
                                if (network.isConnecting) return Qt.alpha(Colours.palette.m3primary, 0.16);
                                if (network.modelData.active) return Colours.palette.m3primaryContainer;
                                return Colours.palette.m3surfaceContainerHighest;
                            }

                            Row {
                                id: wifiPillRow
                                anchors.centerIn: parent
                                spacing: Tokens.spacing.extraSmall

                                CircularIndicator {
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitSize: 14
                                    running: network.isConnecting
                                    visible: network.isConnecting
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        if (network.isConnecting) return qsTr("Connecting");
                                        if (network.modelData.active) return qsTr("Connected");
                                        return qsTr("Available");
                                    }
                                    color: {
                                        if (network.isConnecting) return Colours.palette.m3primary;
                                        if (network.modelData.active) return Colours.palette.m3onPrimaryContainer;
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
                        height: 1
                        color: Qt.alpha(Colours.palette.m3outlineVariant, 0.35)
                    }
                }
            }
        }

        Column {
            Layout.fillWidth: true
            visible: Nmcli.wifiEnabled
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

    WirelessPasswordDialog {
        anchors.fill: parent
        z: 100
        session: root.session
    }
}
