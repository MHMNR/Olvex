
import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import "../../../components/icons"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Olvex.Config
import qs.services
import qs.utils

Item {
    id: root
    width: parent ? parent.width : 0
    height: implicitHeight
    
    property Session session
    
    property string selectedSsid: ""
    property string editingSsid: ""
    property bool showAddNetwork: false
    property bool showSavedNetworks: false
    property var networkList: []

    readonly property var savedWifiList: (Nmcli.savedProfiles || []).filter(p => p.isWireless)
    readonly property string connectingSsid: (Nmcli.pendingConnection && Nmcli.pendingConnection.ssid) ? Nmcli.pendingConnection.ssid : ""
    readonly property bool menuIsOpen: root.session && root.session.wifiConfigMenu && root.session.wifiConfigMenu.isOpen

    function refreshNetworkList() {
        const connecting = root.connectingSsid;
        function rank(n) {
            if (n.active)
                return 0;
            if (n.ssid === connecting)
                return 1;
            if (Nmcli.hasSavedProfile(n.ssid))
                return 2;
            return 3;
        }
        const src = Nmcli.networks || [];
        const copy = [];
        for (let i = 0; i < src.length; i++)
            copy.push(src[i]);
        copy.sort((a, b) => rank(a) - rank(b) || b.strength - a.strength);
        root.networkList = copy;
    }

    function handleApClick(ap) {
        if (!ap)
            return;
        if (ap.active) {
            Nmcli.disconnectFromNetwork();
            return;
        }
        if (root.connectingSsid === ap.ssid)
            return;
        if (ap.isSecure && !Nmcli.hasSavedProfile(ap.ssid)) {
            root.editingSsid = ap.ssid;
            return;
        }
        root.editingSsid = "";
        root.selectedSsid = ap.ssid;
        NetworkConnection.handleConnect(ap, root.session);
    }

    function submitAddNetwork() {
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
        function onWifiEnabledChanged() {
            root.editingSsid = "";
            if (Nmcli.wifiEnabled)
                wifiScanDelay.start();
            root.refreshNetworkList();
        }
        function onNetworksChanged() {
            root.refreshNetworkList();
        }
        function onSavedProfilesChanged() {
            root.refreshNetworkList();
        }
        function onPendingConnectionChanged() {
            root.refreshNetworkList();
            if (!Nmcli.pendingConnection)
                root.selectedSsid = "";
        }
        function onActiveChanged() {
            root.refreshNetworkList();
            if (Nmcli.active) {
                root.selectedSsid = "";
                root.editingSsid = "";
            }
        }
    }

    opacity: 0
    y: 10

    
    ParallelAnimation {
        id: cascadeIn
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens.anim.durations.large; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens.anim.durations.large; easing.type: Easing.OutCubic }
    }

    // Dismiss inline password field when clicking empty space in the page
    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: root.editingSsid !== ""
        onClicked: root.editingSsid = ""
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

        Section {
            title: qsTr("Wi‑Fi")
            description: qsTr("Wireless connections and hotspot")
            icon: "wifi"

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

                Row {
                    spacing: Tokens.spacing.small

                    Item {
                        id: wifiScanCtl
                        readonly property bool scanning: Nmcli.scanning
                        readonly property bool canScan: Nmcli.wifiEnabled
                        implicitWidth: 36
                        implicitHeight: 36

                        LoadingIndicator {
                            anchors.centerIn: parent
                            implicitSize: 32
                            color: Colours.palette.m3primary
                            animated: wifiScanCtl.scanning
                            opacity: wifiScanCtl.scanning ? 1 : 0
                            scale: wifiScanCtl.scanning ? 1 : 0.72
                            visible: opacity > 0.01

                            Behavior on opacity { Anim { type: Anim.FastEffects } }
                            Behavior on scale { Anim { type: Anim.DefaultSpatial } }
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
        }

        Section {
            id: availableNetworksWrapper
            Layout.fillWidth: true
            visible: Nmcli.wifiEnabled && root.networkList.length > 0
            title: qsTr("Available Networks")
            accentColor: Colours.palette.m3primary

            property Item hoveredItem: null

            Timer {
                id: clearHoverTimer
                interval: 75
                onTriggered: availableNetworksWrapper.hoveredItem = null
            }

            Repeater {
                model: root.networkList
                delegate: StyledRect {
                    id: network
                    required property var modelData
                    required property int index
                    readonly property bool isEditing: root.editingSsid === modelData.ssid
                    readonly property bool isConnecting: root.connectingSsid === modelData.ssid || (root.selectedSsid === modelData.ssid && !modelData.active)
                    readonly property real textOpacity: isConnecting ? 0.7 : 1
                    property bool showPasswordText: false

                    function cancelInline() {
                        const ssidToClean = root.editingSsid;
                        root.editingSsid = "";
                        network.showPasswordText = false;
                        if (ssidToClean && !Nmcli.hasSavedProfile(ssidToClean)) {
                            Nmcli.checkAndDeleteConnection(ssidToClean, () => {
                                Nmcli.loadSavedConnections(() => {});
                            });
                        }
                    }

                    function submitInlineConnect(pass) {
                        const trimmed = (pass || "").trim();
                        if (!trimmed) {
                            network.cancelInline();
                            return;
                        }
                        const ssid = network.modelData.ssid;
                        root.editingSsid = "";
                        root.selectedSsid = ssid;
                        network.showPasswordText = false;
                        NetworkConnection.connectWithPassword(network.modelData, trimmed, result => {
                            if (result && !result.success) {
                                console.log("Inline connection failed for:", ssid);
                                if (!Nmcli.hasSavedProfile(ssid)) {
                                    Nmcli.checkAndDeleteConnection(ssid, () => {
                                        Nmcli.loadSavedConnections(() => {});
                                        Nmcli.rescanWifi();
                                    });
                                }
                            }
                            root.selectedSsid = "";
                            Nmcli.rescanWifi();
                            root.refreshNetworkList();
                        });
                    }

                    width: parent ? parent.width : 0
                    height: Math.max(58, Math.max(wifiRow.implicitHeight, wifiPill.implicitHeight) + 16)
                    implicitHeight: height

                    readonly property real topR: (root.networkList.length === 1 || index === 0) ? 22 : 6
                    readonly property real bottomR: (root.networkList.length === 1 || index === root.networkList.length - 1) ? 22 : 6
                    topLeftRadius: topR
                    topRightRadius: topR
                    bottomLeftRadius: bottomR
                    bottomRightRadius: bottomR

                    color: network.modelData.active
                           ? Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
                           : Colours.palette.m3surfaceContainerHigh

                    Behavior on color { CAnim {} }

                    StateLayer {
                        radius: parent.radius
                        color: Colours.palette.m3onSurface
                        showHoverBackground: true
                        interactive: !network.isEditing && !root.menuIsOpen
                        disabled: network.isEditing || root.menuIsOpen
                        onEntered: {
                            clearHoverTimer.stop();
                            availableNetworksWrapper.hoveredItem = network;
                        }
                        onExited: {
                            clearHoverTimer.restart();
                        }
                        onClicked: {
                            if (root.editingSsid !== "") {
                                if (network.isEditing) {
                                    network.cancelInline();
                                } else {
                                    root.editingSsid = "";
                                    root.handleApClick(network.modelData);
                                }
                            } else {
                                root.handleApClick(network.modelData);
                            }
                        }
                    }

                    RowLayout {
                        id: wifiRow
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        spacing: Tokens.spacing.normal

                        WifiLottieIcon {
                            size: 24
                            Layout.alignment: Qt.AlignVCenter
                            visible: !network.isConnecting
                            wifiEnabled: true
                            connected: network.modelData.active
                            signalStrength: (network.modelData.strength || 0) / 100.0
                            color: network.modelData.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            disabledColor: network.modelData.active ? Qt.rgba(1, 1, 1, 0.35) : Qt.alpha(Colours.palette.m3onSurface, 0.28)
                            connecting: network.isConnecting
                            locked: !network.modelData.active && !Nmcli.hasSavedProfile(network.modelData.ssid) && network.modelData.isSecure
                            saved: !network.modelData.active && Nmcli.hasSavedProfile(network.modelData.ssid)
                            showSlashOnDisable: false
                            opacity: network.isConnecting ? 0 : network.textOpacity
                            Behavior on opacity { Anim { type: Anim.FastEffects } }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            opacity: network.textOpacity

                            StyledText {
                                Layout.fillWidth: true
                                text: network.modelData.ssid || qsTr("Hidden network")
                                elide: Text.ElideRight
                                font.weight: Font.DemiBold
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
                            id: settingsBtn
                            z: 1
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 32
                            implicitHeight: 32
                            radius: Tokens.rounding.full
                            color: Colours.palette.m3secondaryContainer

                            visible: !network.isEditing && (network.modelData.active || Nmcli.hasSavedProfile(network.modelData.ssid))

                            opacity: {
                                const menu = root.session ? root.session.wifiConfigMenu : null;
                                if (menu && menu.isOpen && menu.network === network.modelData) return 0.0;
                                return network.textOpacity;
                            }

                            Behavior on color { CAnim {} }
                            Behavior on opacity { NumberAnimation { duration: 80 } }

                            StateLayer {
                                radius: parent.radius
                                color: Colours.palette.m3onSecondaryContainer
                                onClicked: {
                                    if (root.session && root.session.wifiConfigMenu)
                                        root.session.wifiConfigMenu.openFor(network.modelData, settingsBtn);
                                }
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "settings"
                                iconPointSize: Tokens.font.size.small
                                color: Colours.palette.m3onSecondaryContainer
                            }
                        }

                        StyledRect {
                            id: wifiPill
                            z: 1
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: network.isEditing ? Math.min(310, network.width * 0.70) : (wifiPillRow.implicitWidth + Tokens.padding.normal * 2)
                            implicitHeight: network.isEditing ? 36 : 28
                            radius: Tokens.rounding.full
                            clip: true
                            border.width: 0
                            border.color: "transparent"

                            Behavior on implicitWidth { Anim { type: Anim.DefaultSpatial } }
                            Behavior on implicitHeight { Anim { type: Anim.DefaultSpatial } }
                            Behavior on color { CAnim {} }

                            color: {
                                if (network.isEditing) return Qt.alpha(Colours.palette.m3onSurface, 0.12);
                                if (network.isConnecting) return Qt.alpha(Colours.palette.m3primary, 0.16);
                                if (network.modelData.active) return Colours.palette.m3primaryContainer;
                                return Colours.palette.m3surfaceContainerHighest;
                            }

                            Row {
                                id: wifiPillRow
                                anchors.centerIn: parent
                                spacing: Tokens.spacing.extraSmall
                                visible: !network.isEditing
                                opacity: network.isEditing ? 0.0 : 1.0

                                Behavior on opacity { Anim { type: Anim.FastEffects } }

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
                                visible: !network.isEditing
                                interactive: !network.isConnecting && !network.isEditing
                                disabled: network.isConnecting || network.isEditing
                                onClicked: root.handleApClick(network.modelData)
                            }

                            RowLayout {
                                id: editingRow
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.padding.normal
                                anchors.rightMargin: Tokens.padding.small
                                anchors.topMargin: Tokens.padding.small
                                anchors.bottomMargin: Tokens.padding.small
                                spacing: Tokens.spacing.small
                                visible: network.isEditing
                                opacity: network.isEditing ? 1.0 : 0.0

                                Behavior on opacity { Anim { type: Anim.FastEffects } }

                                MaterialIcon {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "lock"
                                    iconPointSize: Tokens.font.size.normal
                                    color: Colours.palette.m3onSurfaceVariant
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    M3PasswordDots {
                                        anchors.fill: parent
                                        text: inlinePassInput.text
                                        dotSize: 18
                                        dotSpacing: 5
                                        hasFocus: inlinePassInput.activeFocus
                                        visible: !network.showPasswordText
                                    }

                                    TextInput {
                                        id: inlinePassInput
                                        anchors.fill: parent
                                        verticalAlignment: TextInput.AlignVCenter
                                        echoMode: TextInput.Normal
                                        color: network.showPasswordText ? Colours.palette.m3onSurface : "transparent"
                                        cursorVisible: network.showPasswordText
                                        font.family: Tokens.font.family.sans
                                        font.pointSize: Tokens.font.size.small
                                        selectByMouse: true
                                        selectionColor: Colours.palette.m3primary
                                        selectedTextColor: Colours.palette.m3onPrimary
                                        clip: true

                                        onAccepted: network.submitInlineConnect(inlinePassInput.text)

                                        HoverHandler {
                                            cursorShape: Qt.IBeamCursor
                                        }

                                        Component.onCompleted: {
                                            forceActiveFocus();
                                        }
                                    }
                                }

                                StyledRect {
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    radius: Tokens.rounding.full
                                    color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
                                    border.width: 0

                                    StateLayer {
                                        radius: parent.radius
                                        color: Colours.palette.m3onSurfaceVariant
                                        onClicked: network.showPasswordText = !network.showPasswordText
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: network.showPasswordText ? "visibility_off" : "visibility"
                                        iconPointSize: Tokens.font.size.smaller
                                        color: Colours.palette.m3onSurfaceVariant
                                    }
                                }

                                StyledRect {
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    radius: Tokens.rounding.full
                                    color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
                                    border.width: 0

                                    StateLayer {
                                        radius: parent.radius
                                        color: Colours.palette.m3onSurfaceVariant
                                        onClicked: network.cancelInline()
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: "close"
                                        iconPointSize: Tokens.font.size.smaller
                                        color: Colours.palette.m3onSurfaceVariant
                                    }
                                }

                                StyledRect {
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    radius: Tokens.rounding.full
                                    color: inlinePassInput.text ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.08)
                                    border.width: 0

                                    Behavior on color { CAnim {} }

                                    StateLayer {
                                        radius: parent.radius
                                        color: inlinePassInput.text ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                        onClicked: network.submitInlineConnect(inlinePassInput.text)
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: "arrow_forward"
                                        iconPointSize: Tokens.font.size.smaller
                                        color: inlinePassInput.text ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                        font.weight: 500

                                        Behavior on color { CAnim {} }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Saved Networks Section ──────────────────────────────────────────
        Section {
            Layout.fillWidth: true
            visible: Nmcli.wifiEnabled && root.savedWifiList.length > 0
            title: qsTr("Saved Networks")
            accentColor: Colours.palette.m3primary

            SettingRow {
                id: savedHeaderCard
                Layout.fillWidth: true
                title: qsTr("Saved Networks")
                description: qsTr("%1 saved networks").arg(root.savedWifiList.length)
                clickable: true
                onClicked: {
                    root.showSavedNetworks = !root.showSavedNetworks;
                    savedHeaderCard.notifySection();
                }

                StyledRect {
                    id: savedExpandToggleBtn
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3surfaceContainerHighest
                    border.width: 0

                    StateLayer {
                        radius: parent.radius
                        color: Colours.palette.m3onSurface
                        onClicked: {
                            root.showSavedNetworks = !root.showSavedNetworks;
                            savedHeaderCard.notifySection();
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "expand_more"
                        iconPointSize: 20
                        color: Colours.palette.m3onSurfaceVariant
                        rotation: root.showSavedNetworks ? 180 : 0
                        Behavior on rotation { Anim { type: Anim.DefaultSpatial } }
                    }
                }
            }

            Item {
                id: savedListContainer
                width: parent.width
                implicitHeight: savedCol.implicitHeight
                height: root.showSavedNetworks ? implicitHeight : 0
                opacity: root.showSavedNetworks ? 1.0 : 0.0
                clip: true
                visible: root.showSavedNetworks || height > 0 || opacity > 0.01

                Behavior on height {
                    Anim { type: Anim.Emphasized }
                }
                Behavior on opacity {
                    Anim { type: Anim.FastEffects }
                }

                Column {
                    id: savedCol
                    width: parent.width
                    spacing: 3

                    Repeater {
                        model: root.savedWifiList
                        delegate: SettingRow {
                            id: savedDev
                            required property var modelData
                            required property int index
                            showIconBackground: false

                            readonly property var liveNet: (root.networkList || []).find(n => n.ssid === modelData.ssid) || null
                            readonly property bool isLive: !!liveNet
                            readonly property bool isCurrentActive: liveNet && liveNet.active

                            title: savedDev.modelData.name || savedDev.modelData.ssid || qsTr("Unknown")
                            description: {
                                let status = savedDev.isCurrentActive ? qsTr("Connected") : (savedDev.isLive ? qsTr("In range · %1%").arg(savedDev.liveNet.strength) : qsTr("Not in range"));
                                if (savedDev.modelData.autoconnect) {
                                    status += qsTr(" · Auto-connect");
                                }
                                return status;
                            }
                            clickable: true
                            onClicked: {
                                if (savedDev.liveNet) {
                                    root.handleApClick(savedDev.liveNet);
                                } else if (root.session && root.session.wifiConfigMenu) {
                                    const ap = {
                                        ssid: savedDev.modelData.ssid,
                                        bssid: "",
                                        strength: 0,
                                        isSecure: true,
                                        active: false
                                    };
                                    root.session.wifiConfigMenu.openFor(ap, savedSettingsBtn);
                                }
                            }

                            customIcon: Component {
                                WifiLottieIcon {
                                    size: 24
                                    wifiEnabled: true
                                    connected: savedDev.isCurrentActive
                                    signalStrength: (savedDev.liveNet ? savedDev.liveNet.strength : 0) / 100.0
                                    color: savedDev.isCurrentActive ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                    disabledColor: savedDev.isCurrentActive ? Qt.rgba(1, 1, 1, 0.35) : Qt.alpha(Colours.palette.m3onSurface, 0.28)
                                    connecting: false
                                    locked: !savedDev.isCurrentActive && (savedDev.liveNet ? savedDev.liveNet.isSecure : true)
                                    saved: true
                                    showSlashOnDisable: false
                                }
                            }

                            StyledRect {
                                id: savedSettingsBtn
                                implicitWidth: 36
                                implicitHeight: 36
                                radius: Tokens.rounding.full
                                color: Colours.palette.m3secondaryContainer

                                opacity: {
                                    const menu = root.session ? root.session.wifiConfigMenu : null;
                                    if (menu && menu.isOpen && menu.network && menu.network.ssid === savedDev.modelData.ssid) return 0.0;
                                    return 1.0;
                                }

                                Behavior on color { CAnim {} }
                                Behavior on opacity { NumberAnimation { duration: 80 } }

                                StateLayer {
                                    radius: parent.radius
                                    color: Colours.palette.m3onSecondaryContainer
                                    onClicked: {
                                        if (root.session && root.session.wifiConfigMenu) {
                                            const ap = savedDev.liveNet || {
                                                ssid: savedDev.modelData.ssid,
                                                bssid: "",
                                                strength: 0,
                                                isSecure: true,
                                                active: false
                                            };
                                            root.session.wifiConfigMenu.openFor(ap, savedSettingsBtn);
                                        }
                                    }
                                }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "settings"
                                    iconPointSize: Tokens.font.size.normal
                                    color: Colours.palette.m3onSecondaryContainer
                                }
                            }
                        }
                    }
                }
            }
        }

        Section {
            Layout.fillWidth: true
            visible: Nmcli.wifiEnabled
            title: qsTr("Add Network")
            accentColor: Colours.palette.m3primary

            SettingRow {
                title: qsTr("Network name")
                description: qsTr("SSID of the hidden or manual network")

                StyledTextField {
                    id: addSsidField
                    width: Math.max(260, Math.round(contentWidth + leftPadding + rightPadding + 16))
                    placeholderText: qsTr("Network SSID")
                    Keys.onReturnPressed: addPasswordField.focus = true
                    Keys.onEnterPressed: addPasswordField.focus = true
                }
            }

            SettingRow {
                title: qsTr("Password")
                description: qsTr("Leave empty for open networks")

                RowLayout {
                    spacing: Tokens.spacing.small

                    StyledTextField {
                        id: addPasswordField
                        width: Math.max(195, Math.round(contentWidth + leftPadding + rightPadding + 16))
                        Layout.preferredWidth: width
                        echoMode: TextInput.Password
                        placeholderText: qsTr("Optional")
                        Keys.onReturnPressed: root.submitAddNetwork()
                        Keys.onEnterPressed: root.submitAddNetwork()
                    }

                    StyledRect {
                        implicitWidth: joinLbl.implicitWidth + 28
                        implicitHeight: 36
                        radius: Tokens.rounding.full
                        color: addSsidField.text.trim().length > 0 ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.12)
                        
                        Behavior on color { CAnim {} }

                        StyledText {
                            id: joinLbl
                            anchors.centerIn: parent
                            text: qsTr("Join")
                            color: addSsidField.text.trim().length > 0 ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                            font.weight: Font.Medium
                            textPointSize: Tokens.font.size.small
                        }

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onPrimary
                            enabled: addSsidField.text.trim().length > 0
                            onClicked: root.submitAddNetwork()
                        }
                    }
                }
            }
        }
    }
}