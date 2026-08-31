import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.settings
import "../../../components/containers"

ColumnLayout {
    id: root

    required property PopoutState popouts

    property string connectingToSsid: ""
    property string editingSsid: ""
    property string selectedSsid: ""
    property string view: "wireless" // "wireless" or "ethernet"
    property var passwordNetwork: null
    property bool showPasswordDialog: false

    function handleApClick(ap) {
        if (!ap) return;
        if (ap.active) {
            Nmcli.disconnectFromNetwork();
            return;
        }
        if (root.connectingToSsid === ap.ssid) return;
        if (ap.isSecure && !Nmcli.hasSavedProfile(ap.ssid)) {
            root.editingSsid = ap.ssid;
            return;
        }
        root.editingSsid = "";
        root.selectedSsid = ap.ssid;
        root.connectingToSsid = ap.ssid;
        NetworkConnection.handleConnect(ap, null, network => {
            root.editingSsid = network.ssid;
        });
    }

    // Dismiss inline password field when clicking empty space
    TapHandler {
        enabled: root.editingSsid !== ""
        onTapped: {
            const ssidToClean = root.editingSsid;
            root.editingSsid = "";
            if (ssidToClean && !Nmcli.hasSavedProfile(ssidToClean)) {
                Nmcli.checkAndDeleteConnection(ssidToClean, () => {
                    Nmcli.loadSavedConnections(() => {});
                });
            }
        }
        gesturePolicy: TapHandler.ReleaseWithinBounds
    }

    readonly property var activeNetwork: {
        if (Nmcli.active && Nmcli.active.ssid) return Nmcli.active;
        const found = (Nmcli.networks || []).find(n => n.active);
        if (found && found.ssid) return found;
        if (Nmcli.activeConnection) return { ssid: Nmcli.activeConnection, strength: 100, isSecure: false, active: true };
        return null;
    }

    spacing: Tokens.spacing.normal
    Layout.fillWidth: true
    implicitWidth: parent ? parent.width : 340

    // ── Wi-Fi Disabled / Empty State ─────────────────────────────────────────
    StyledRect {
        id: offStateCard
        visible: !Nmcli.wifiEnabled
        Layout.fillWidth: true
        Layout.preferredHeight: 160
        radius: Tokens.rounding.large
        color: Colours.layer(Colours.palette.m3surfaceContainer, 1)

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Tokens.spacing.normal

            StyledRect {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 52
                implicitHeight: 52
                radius: Tokens.rounding.full
                color: Qt.alpha(Colours.palette.m3onSurface, 0.08)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "wifi_off"
                    iconPointSize: Tokens.font.size.large
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 2

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Wi-Fi is turned off")
                    font.weight: Font.DemiBold
                    textPointSize: Tokens.font.size.normal
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Turn on Wi-Fi to find networks")
                    textPointSize: Tokens.font.size.smaller
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            IconTextButton {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Turn on Wi-Fi")
                icon: "wifi"
                inactiveColour: Colours.palette.m3primary
                inactiveOnColour: Colours.palette.m3onPrimary
                onClicked: Nmcli.enableWifi(true)
            }
        }
    }

    // ── Wi-Fi Enabled View ───────────────────────────────────────────────────
    ColumnLayout {
        id: wifiContainer
        visible: Nmcli.wifiEnabled
        Layout.fillWidth: true
        spacing: Tokens.spacing.normal

        // ── Connected Network Hero Card ──────────────────────────────────────
        ColumnLayout {
            visible: root.activeNetwork !== null && (root.activeNetwork.ssid ? true : false)
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            StyledText {
                text: qsTr("Connected")
                textPointSize: Tokens.font.size.smaller
                font.weight: Font.DemiBold
                color: Colours.palette.m3primary
                Layout.leftMargin: Tokens.padding.small
            }

            StyledRect {
                id: activeCard
                Layout.fillWidth: true
                implicitHeight: 64
                radius: Tokens.rounding.normal
                color: Colours.palette.m3primaryContainer

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.normal
                    anchors.rightMargin: Tokens.padding.normal
                    spacing: Tokens.spacing.normal

                    // Connected Wi-Fi Icon Badge
                    StyledRect {
                        implicitWidth: 40
                        implicitHeight: 40
                        radius: Tokens.rounding.small
                        color: Colours.palette.m3primary

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: root.activeNetwork ? Icons.getNetworkIcon(root.activeNetwork.strength, root.activeNetwork.isSecure) : "wifi"
                            color: Colours.palette.m3onPrimary
                            iconPointSize: Tokens.font.size.normal
                        }
                    }

                    // Network info
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: root.activeNetwork ? root.activeNetwork.ssid : ""
                            font.weight: Font.DemiBold
                            textPointSize: Tokens.font.size.normal
                            color: Colours.palette.m3onPrimaryContainer
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            spacing: Tokens.spacing.extraSmall

                            StyledText {
                                text: qsTr("Connected")
                                textPointSize: Tokens.font.size.smaller
                                color: Qt.alpha(Colours.palette.m3onPrimaryContainer, 0.8)
                            }

                            StyledText {
                                text: "•"
                                textPointSize: Tokens.font.size.smaller
                                color: Qt.alpha(Colours.palette.m3onPrimaryContainer, 0.5)
                            }

                            StyledText {
                                text: (root.activeNetwork ? root.activeNetwork.strength : 100) + "%"
                                textPointSize: Tokens.font.size.smaller
                                color: Qt.alpha(Colours.palette.m3onPrimaryContainer, 0.8)
                            }
                        }
                    }

                    // Disconnect Button
                    StyledRect {
                        id: activeDisconnectBtn
                        implicitWidth: 36
                        implicitHeight: 36
                        radius: Tokens.rounding.full
                        color: Qt.alpha(Colours.palette.m3onPrimaryContainer, 0.12)

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "link_off"
                            color: Colours.palette.m3onPrimaryContainer
                            iconPointSize: Tokens.font.size.normal
                        }

                        StateLayer {
                            anchors.fill: parent
                            color: Colours.palette.m3onPrimaryContainer
                            onClicked: Nmcli.disconnectFromNetwork()
                        }
                    }
                }
            }
        }

        // ── Available Networks Header ────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.rightMargin: Tokens.padding.small
            spacing: Tokens.spacing.small

            StyledText {
                text: qsTr("Available Networks")
                textPointSize: Tokens.font.size.smaller
                font.weight: Font.DemiBold
                color: Colours.palette.m3onSurfaceVariant
                Layout.fillWidth: true
            }

            // Count Badge
            StyledRect {
                implicitWidth: countText.implicitWidth + 12
                implicitHeight: 20
                radius: Tokens.rounding.full
                color: Qt.alpha(Colours.palette.m3onSurface, 0.08)

                StyledText {
                    id: countText
                    anchors.centerIn: parent
                    text: `${Nmcli.networks.length}`
                    textPointSize: Tokens.font.size.smaller - 2
                    font.weight: Font.Medium
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }

        // ── Available Networks List ──────────────────────────────────────────
        StyledFlickable {
            id: wifiScroll
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(wifiContent.implicitHeight, 300)
            contentHeight: wifiContent.implicitHeight
            flickableDirection: Flickable.VerticalFlick
            clip: true
            smoothWheel: true

            ScrollBar.vertical: ScrollBar {
                policy: wifiContent.implicitHeight > wifiScroll.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            ColumnLayout {
                id: wifiContent
                width: wifiScroll.width
                spacing: Tokens.spacing.small

                Repeater {
                    model: ScriptModel {
                        values: [...(Nmcli.networks || [])].filter(n => !n.active && (!root.activeNetwork || n.ssid !== root.activeNetwork.ssid)).sort((a, b) => b.strength - a.strength)
                    }

                    StyledRect {
                        id: networkItem
                        required property Nmcli.AccessPoint modelData
                        required property int index

                        readonly property bool isEditing: root.editingSsid === modelData.ssid
                        readonly property bool isConnecting: root.connectingToSsid === modelData.ssid || (root.selectedSsid === modelData.ssid && !modelData.active)
                        readonly property bool isSaved: Nmcli.hasSavedProfile(modelData.ssid)
                        property bool showPasswordText: false
                        property bool animatingMorph: false

                        onIsEditingChanged: {
                            networkItem.animatingMorph = true;
                            morphTimer.restart();
                        }

                        Timer {
                            id: morphTimer
                            interval: 350
                            onTriggered: networkItem.animatingMorph = false
                        }

                        function cancelInline() {
                            const ssidToClean = root.editingSsid;
                            root.editingSsid = "";
                            networkItem.showPasswordText = false;
                            if (ssidToClean && !Nmcli.hasSavedProfile(ssidToClean)) {
                                Nmcli.checkAndDeleteConnection(ssidToClean, () => {
                                    Nmcli.loadSavedConnections(() => {});
                                });
                            }
                        }

                        function submitInlineConnect(pass) {
                            const trimmed = (pass || "").trim();
                            if (!trimmed) {
                                networkItem.cancelInline();
                                return;
                            }
                            const ssid = networkItem.modelData.ssid;
                            root.editingSsid = "";
                            root.selectedSsid = ssid;
                            root.connectingToSsid = ssid;
                            networkItem.showPasswordText = false;
                            NetworkConnection.connectWithPassword(networkItem.modelData, trimmed, result => {
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
                                root.connectingToSsid = "";
                                Nmcli.rescanWifi();
                            });
                        }

                        Layout.fillWidth: true
                        implicitHeight: networkItem.isEditing ? 104 : 52
                        radius: Tokens.rounding.normal
                        color: networkItem.isEditing ? Colours.layer(Colours.palette.m3surfaceContainerHigh, 1) : Colours.layer(Colours.palette.m3surfaceContainer, 1)
                        border.width: 0
                        border.color: "transparent"
                        clip: true

                        Behavior on implicitHeight {
                            enabled: networkItem.animatingMorph
                            Anim { type: Anim.DefaultSpatial }
                        }
                        Behavior on color { CAnim {} }

                        // ── Top Row: Wi-Fi Icon + SSID + Badges ─────────────────────────
                        RowLayout {
                            id: topRow
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.topMargin: (52 - 34) / 2
                            anchors.leftMargin: Tokens.padding.normal
                            anchors.rightMargin: Tokens.padding.normal
                            height: 34
                            spacing: Tokens.spacing.normal

                            // Wi-Fi Signal Icon container
                            StyledRect {
                                implicitWidth: 34
                                implicitHeight: 34
                                radius: Tokens.rounding.small
                                color: Qt.alpha(Colours.palette.m3primary, 0.10)

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: Icons.getNetworkIcon(networkItem.modelData.strength, networkItem.modelData.isSecure)
                                    color: Colours.palette.m3primary
                                    opacity: networkItem.isConnecting ? 0 : 1
                                    iconPointSize: Tokens.font.size.normal

                                    Behavior on opacity { Anim { type: Anim.FastEffects } }
                                }

                                LoadingIndicator {
                                    anchors.centerIn: parent
                                    implicitSize: 22
                                    color: Colours.palette.m3primary
                                    animated: networkItem.isConnecting
                                    opacity: networkItem.isConnecting ? 1 : 0

                                    Behavior on opacity { Anim { type: Anim.FastEffects } }
                                }
                            }

                            // Network SSID & Badges
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    Layout.fillWidth: true
                                    text: networkItem.modelData.ssid
                                    font.weight: Font.Medium
                                    textPointSize: Tokens.font.size.small
                                    color: Colours.palette.m3onSurface
                                    elide: Text.ElideRight
                                }

                                RowLayout {
                                    spacing: Tokens.spacing.extraSmall

                                    StyledText {
                                        text: `${networkItem.modelData.strength}%`
                                        textPointSize: Tokens.font.size.smaller - 1
                                        color: Colours.palette.m3onSurfaceVariant
                                    }

                                    StyledText {
                                        visible: networkItem.modelData.isSecure || networkItem.isSaved
                                        text: "•"
                                        textPointSize: Tokens.font.size.smaller - 1
                                        color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.5)
                                    }

                                    StyledText {
                                        visible: networkItem.isSaved
                                        text: qsTr("Saved")
                                        textPointSize: Tokens.font.size.smaller - 1
                                        color: Colours.palette.m3primary
                                        font.weight: Font.Medium
                                    }

                                    StyledText {
                                        visible: networkItem.modelData.isSecure && !networkItem.isSaved
                                        text: qsTr("Secured")
                                        textPointSize: Tokens.font.size.smaller - 1
                                        color: Colours.palette.m3onSurfaceVariant
                                    }
                                }
                            }

                            // Spacer to prevent SSID text from underlapping pill when pill is collapsed on top-right
                            Item {
                                implicitWidth: !networkItem.isEditing ? (wifiPill.collapsedWidth) : 0
                                implicitHeight: 1
                                Behavior on implicitWidth {
                                    enabled: networkItem.animatingMorph
                                    Anim { type: Anim.DefaultSpatial }
                                }
                            }
                        }

                        // ── Morphing M3 Container (Transforms from Top-Right Pill into Bottom Input Field) ──
                        StyledRect {
                            id: wifiPill
                            z: 2
                            clip: true

                            readonly property real collapsedWidth: wifiPillRow.implicitWidth + Tokens.padding.normal * 2
                            readonly property real expandedWidth: networkItem.width - Tokens.padding.normal * 2

                            // Direct Hardware-Accelerated Coordinate Morphing
                            x: networkItem.isEditing ? Tokens.padding.normal : (networkItem.width - collapsedWidth - Tokens.padding.normal)
                            y: networkItem.isEditing ? 54 : (52 - 26) / 2
                            width: networkItem.isEditing ? expandedWidth : collapsedWidth
                            height: networkItem.isEditing ? 38 : 26
                            radius: Tokens.rounding.full

                            border.width: 0
                            border.color: "transparent"

                            color: {
                                if (networkItem.isEditing) return Qt.alpha(Colours.palette.m3onSurface, 0.12);
                                if (networkItem.isConnecting) return Qt.alpha(Colours.palette.m3primary, 0.16);
                                if (networkItem.modelData.active) return Colours.palette.m3primaryContainer;
                                return Qt.alpha(Colours.palette.m3onSurface, 0.08);
                            }

                            Behavior on x {
                                enabled: networkItem.animatingMorph
                                Anim { type: Anim.DefaultSpatial }
                            }
                            Behavior on y {
                                enabled: networkItem.animatingMorph
                                Anim { type: Anim.DefaultSpatial }
                            }
                            Behavior on width {
                                enabled: networkItem.animatingMorph
                                Anim { type: Anim.DefaultSpatial }
                            }
                            Behavior on height {
                                enabled: networkItem.animatingMorph
                                Anim { type: Anim.DefaultSpatial }
                            }
                            Behavior on color { CAnim {} }

                            // 1. Collapsed State: "Available" / "Connected" / "Connecting" Pill Content
                            Row {
                                id: wifiPillRow
                                anchors.centerIn: parent
                                visible: opacity > 0.01
                                opacity: networkItem.isEditing ? 0.0 : 1.0

                                Behavior on opacity { Anim { type: Anim.FastEffects } }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        if (networkItem.isConnecting) return qsTr("Connecting");
                                        if (networkItem.modelData.active) return qsTr("Connected");
                                        return qsTr("Available");
                                    }
                                    color: {
                                        if (networkItem.isConnecting) return Colours.palette.m3primary;
                                        if (networkItem.modelData.active) return Colours.palette.m3onPrimaryContainer;
                                        return Colours.palette.m3onSurfaceVariant;
                                    }
                                    font.weight: Font.Normal
                                    font.letterSpacing: 0.15
                                    textPointSize: Tokens.font.size.smaller
                                }
                            }

                            // 2. Expanded State: Password Input Field Content
                            RowLayout {
                                id: editingRow
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.padding.normal
                                anchors.rightMargin: Tokens.padding.small
                                spacing: Tokens.spacing.small
                                visible: opacity > 0.01
                                opacity: networkItem.isEditing ? 1.0 : 0.0

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

                                    TextInput {
                                        id: inlinePassInput
                                        anchors.fill: parent
                                        verticalAlignment: TextInput.AlignVCenter
                                        echoMode: networkItem.showPasswordText ? TextInput.Normal : TextInput.Password
                                        color: Colours.palette.m3onSurface
                                        font.family: Tokens.font.family.sans
                                        font.pointSize: Tokens.font.size.small
                                        selectByMouse: true
                                        selectionColor: Colours.palette.m3primary
                                        selectedTextColor: Colours.palette.m3onPrimary
                                        clip: true

                                        Keys.onReturnPressed: networkItem.submitInlineConnect(text)
                                        Keys.onEnterPressed: networkItem.submitInlineConnect(text)
                                        Keys.onEscapePressed: networkItem.cancelInline()

                                        Connections {
                                            target: networkItem
                                            function onIsEditingChanged() {
                                                if (networkItem.isEditing) {
                                                    Qt.callLater(() => inlinePassInput.forceActiveFocus());
                                                } else {
                                                    inlinePassInput.text = "";
                                                }
                                            }
                                        }
                                    }

                                    StyledText {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Enter password")
                                        color: Colours.palette.m3outline
                                        font.family: Tokens.font.family.sans
                                        textPointSize: Tokens.font.size.small
                                        visible: !inlinePassInput.text && !inlinePassInput.activeFocus
                                    }
                                }

                                // Eye toggle button
                                StyledRect {
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    radius: Tokens.rounding.full
                                    color: "transparent"

                                    StateLayer {
                                        radius: parent.radius
                                        color: Colours.palette.m3onSurfaceVariant
                                        onClicked: networkItem.showPasswordText = !networkItem.showPasswordText
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: networkItem.showPasswordText ? "visibility_off" : "visibility"
                                        iconPointSize: Tokens.font.size.normal
                                        color: Colours.palette.m3onSurfaceVariant
                                    }
                                }

                                // Cancel button (✕)
                                StyledRect {
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    radius: Tokens.rounding.full
                                    color: Qt.alpha(Colours.palette.m3onSurface, 0.08)

                                    StateLayer {
                                        radius: parent.radius
                                        color: Colours.palette.m3onSurfaceVariant
                                        onClicked: networkItem.cancelInline()
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: "close"
                                        iconPointSize: Tokens.font.size.normal
                                        color: Colours.palette.m3onSurfaceVariant
                                    }
                                }

                                // Submit button (arrow_forward)
                                StyledRect {
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    radius: Tokens.rounding.full
                                    color: inlinePassInput.text.length > 0 ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.08)

                                    Behavior on color { CAnim {} }

                                    StateLayer {
                                        radius: parent.radius
                                        color: inlinePassInput.text.length > 0 ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                        onClicked: networkItem.submitInlineConnect(inlinePassInput.text)
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: "arrow_forward"
                                        iconPointSize: Tokens.font.size.normal
                                        color: inlinePassInput.text.length > 0 ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                        font.weight: 500
                                    }
                                }
                            }
                        }

                        // Background StateLayer for clicking the entire row (when not editing)
                        StateLayer {
                            anchors.fill: parent
                            color: Colours.palette.m3onSurface
                            preventStealing: false
                            interactive: !networkItem.isEditing && !networkItem.isConnecting
                            disabled: networkItem.isEditing || networkItem.isConnecting || !Nmcli.wifiEnabled

                            onClicked: {
                                if (root.editingSsid !== "") {
                                    if (networkItem.isEditing) {
                                        networkItem.cancelInline();
                                    } else {
                                        root.editingSsid = "";
                                        root.handleApClick(networkItem.modelData);
                                    }
                                } else {
                                    root.handleApClick(networkItem.modelData);
                                }
                            }
                        }
                    }
                }

                // Scanning / Empty state
                StyledRect {
                    visible: (Nmcli.networks || []).length === 0
                    Layout.fillWidth: true
                    implicitHeight: 96
                    radius: Tokens.rounding.normal
                    color: Qt.alpha(Colours.palette.m3onSurface, 0.04)

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.normal

                        LoadingIndicator {
                            Layout.alignment: Qt.AlignHCenter
                            implicitSize: 36
                            color: Colours.palette.m3primary
                            animated: Nmcli.scanning
                            opacity: Nmcli.scanning ? 1 : 0.45
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Nmcli.scanning ? qsTr("Scanning for networks…") : qsTr("No networks found · tap to scan")
                            color: Colours.palette.m3onSurfaceVariant
                            textPointSize: Tokens.font.size.small
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (Nmcli.wifiEnabled) Nmcli.rescanWifi()
                    }
                }
            }
        }
    }

    // ── Footer: Open Network Settings ────────────────────────────────────────
    StyledRect {
        Layout.fillWidth: true
        implicitHeight: 46
        radius: Tokens.rounding.normal
        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.normal
            anchors.rightMargin: Tokens.padding.normal
            spacing: Tokens.spacing.normal

            MaterialIcon {
                text: "settings"
                color: Colours.palette.m3primary
                iconPointSize: Tokens.font.size.normal
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("More Wi-Fi settings")
                font.weight: Font.Medium
                textPointSize: Tokens.font.size.small
                color: Colours.palette.m3onSurface
            }

            MaterialIcon {
                text: "chevron_right"
                color: Colours.palette.m3onSurfaceVariant
                iconPointSize: Tokens.font.size.normal
            }
        }

        StateLayer {
            anchors.fill: parent
            color: Colours.palette.m3onSurface
            onClicked: {
                root.popouts.hasCurrent = false;
                const activeScr = Visibilities.getForActive();
                if (activeScr) activeScr.qspanel = false;
                WindowFactory.create(null, {
                    active: "network",
                    activeSection: "wifi"
                });
            }
        }
    }

    Connections {
        target: Nmcli
        function onActiveChanged() {
            if (Nmcli.active && root.connectingToSsid === Nmcli.active.ssid) {
                root.connectingToSsid = "";
                if (root.showPasswordDialog && root.passwordNetwork && Nmcli.active.ssid === root.passwordNetwork.ssid) {
                    root.showPasswordDialog = false;
                    root.passwordNetwork = null;
                    if (root.popouts.currentName === "wirelesspassword") {
                        root.popouts.currentName = "network";
                    }
                }
            }
        }
    }

    Connections {
        target: root.popouts
        function onCurrentNameChanged() {
            if (root.popouts.currentName !== "wirelesspassword" && root.showPasswordDialog) {
                root.showPasswordDialog = false;
                root.passwordNetwork = null;
            }
        }
    }
}
