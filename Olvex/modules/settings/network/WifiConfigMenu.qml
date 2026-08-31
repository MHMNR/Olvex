import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.services
import qs.utils
import ".."
import "../../../components"
import "../../../components/controls"
import "../../../components/effects"

Item {
    id: menu

    property Session session
    property var network: null
    property var savedProfile: null
    property string savedPassword: ""
    property bool isPasswordEditing: false
    property bool showPasswordText: false
    property bool isSavingPassword: false

    property bool active: false
    property real startX: 0
    property real startY: 0
    property real startW: 32
    property real startH: 32

    readonly property bool isActive: network && network.active
    readonly property bool isSaved: network && Nmcli.hasSavedProfile(network.ssid)
    readonly property bool isOpen: active && container.state === "expanded"

    readonly property int expandDur: Tokens.anim.durations.expressiveDefaultSpatial || 400
    readonly property int collapseDur: Tokens.anim.durations.normal || 250

    readonly property real targetW: Math.min(380, Math.max(300, (menu.width > 50) ? (menu.width - 32) : 380))
    readonly property real targetH: Math.max(320, (contentCol ? contentCol.implicitHeight + 32 : 360))
    readonly property real targetX: Math.max(16, Math.min(menu.width - targetW - 16, startX + startW - targetW))
    readonly property real targetY: Math.max(16, Math.min(menu.height - targetH - 16, Math.max(16, startY - 32)))

    anchors.fill: parent
    z: 9999
    visible: active || expandTransition.running || collapseTransition.running
    focus: active

    Keys.onEscapePressed: event => {
        if (isPasswordEditing) {
            isPasswordEditing = false;
            event.accepted = true;
            return;
        }
        menu.close();
        event.accepted = true;
    }

    function openFor(ap, sourceItem) {
        if (!ap || !sourceItem) return;
        network = ap;
        savedProfile = Nmcli.getSavedProfile(ap.ssid);
        isPasswordEditing = false;
        showPasswordText = false;
        savedPassword = "";

        if (savedProfile && savedProfile.uuid) {
            Nmcli.getSavedPassword(savedProfile.uuid, pass => {
                savedPassword = pass || "";
            });
        }

        const pt = sourceItem.mapToItem(menu, 0, 0);
        startX = pt.x || 0;
        startY = pt.y || 0;
        startW = sourceItem.width || 32;
        startH = sourceItem.height || 32;

        hideTimer.stop();
        expandTimer.stop();
        active = true;
        container.state = "docked";
        expandTimer.start();
        menu.forceActiveFocus();
    }

    function close() {
        if (!active || container.state === "docked") return;
        isPasswordEditing = false;
        showPasswordText = false;
        container.state = "docked";
        hideTimer.start();
    }

    Timer {
        id: expandTimer
        interval: 16
        repeat: false
        onTriggered: {
            if (menu.active) {
                container.state = "expanded";
            }
        }
    }

    Timer {
        id: hideTimer
        interval: menu.collapseDur + 30
        repeat: false
        onTriggered: {
            menu.active = false;
        }
    }

    // ── Scrim ──────────────────────────────────────────────────────────────
    Rectangle {
        id: scrimRect
        anchors.fill: parent
        z: 0
        color: Colours.palette.m3scrim
        opacity: container.state === "expanded" ? 0.40 : 0.0
        visible: opacity > 0.001

        Behavior on opacity {
            NumberAnimation {
                duration: container.state === "expanded" ? menu.expandDur : menu.collapseDur
                easing: Tokens.anim.expressiveDefaultSpatial
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: container.state === "expanded"
            onClicked: menu.close()
        }
    }

    // ── Morphing Container (Material 3 Container Transform) ─────────────────
    Rectangle {
        id: container
        z: 1
        x: menu.startX
        y: menu.startY
        width: menu.startW
        height: menu.startH
        radius: menu.startW / 2
        color: Colours.palette.m3secondaryContainer
        clip: true
        antialiasing: true

        state: "docked"

        states: [
            State {
                name: "docked"
                PropertyChanges {
                    target: container
                    x: menu.startX
                    y: menu.startY
                    width: menu.startW
                    height: menu.startH
                    radius: menu.startW / 2
                    color: Colours.palette.m3secondaryContainer
                }
                PropertyChanges {
                    target: buttonContent
                    opacity: 1.0
                }
                PropertyChanges {
                    target: menuContent
                    opacity: 0.0
                }
            },
            State {
                name: "expanded"
                PropertyChanges {
                    target: container
                    x: menu.targetX
                    y: menu.targetY
                    width: menu.targetW
                    height: menu.targetH
                    radius: Tokens.rounding.large
                    color: Colours.palette.m3surfaceContainer
                }
                PropertyChanges {
                    target: buttonContent
                    opacity: 0.0
                }
                PropertyChanges {
                    target: menuContent
                    opacity: 1.0
                }
            }
        ]

        transitions: [
            Transition {
                id: expandTransition
                from: "docked"
                to: "expanded"
                ParallelAnimation {
                    NumberAnimation {
                        target: container
                        properties: "x,y,width,height"
                        duration: menu.expandDur
                        easing: Tokens.anim.expressiveDefaultSpatial
                    }
                    NumberAnimation {
                        target: container
                        property: "radius"
                        duration: Math.round(menu.expandDur * 0.75)
                        easing: Tokens.anim.expressiveDefaultSpatial
                    }
                    ColorAnimation {
                        target: container
                        property: "color"
                        duration: menu.expandDur
                        easing: Tokens.anim.expressiveDefaultSpatial
                    }
                    NumberAnimation {
                        target: buttonContent
                        property: "opacity"
                        duration: 100
                        easing: Tokens.anim.expressiveFastSpatial
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: 100 }
                        NumberAnimation {
                            target: menuContent
                            property: "opacity"
                            duration: menu.expandDur - 100
                            easing: Tokens.anim.expressiveDefaultSpatial
                        }
                    }
                }
            },
            Transition {
                id: collapseTransition
                from: "expanded"
                to: "docked"
                ParallelAnimation {
                    NumberAnimation {
                        target: container
                        properties: "x,y,width,height,radius"
                        duration: menu.collapseDur
                        easing: Tokens.anim.expressiveDefaultSpatial
                    }
                    ColorAnimation {
                        target: container
                        property: "color"
                        duration: menu.collapseDur
                        easing: Tokens.anim.expressiveDefaultSpatial
                    }
                    NumberAnimation {
                        target: menuContent
                        property: "opacity"
                        duration: 80
                        easing: Tokens.anim.expressiveFastSpatial
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: menu.collapseDur - 100 }
                        NumberAnimation {
                            target: buttonContent
                            property: "opacity"
                            duration: 100
                            easing: Tokens.anim.expressiveFastSpatial
                        }
                    }
                }
            }
        ]

        // Prevent clicks within container from closing via scrim
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        // ── Layer 1: Button Content (visible at docked state) ───────────────
        Item {
            id: buttonContent
            anchors.fill: parent

            MaterialIcon {
                anchors.centerIn: parent
                text: "settings"
                iconPointSize: Tokens.font.size.small
                color: Colours.palette.m3onSecondaryContainer
            }
        }

        // ── Layer 2: Menu Content (visible at expanded state) ──────────────
        Item {
            id: menuContent
            width: menu.targetW
            anchors.top: parent.top
            anchors.left: parent.left

            ColumnLayout {
                id: contentCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 10

                // ── 1. Header ──────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Leading Squircle Icon
                    StyledRect {
                        implicitWidth: 42
                        implicitHeight: 42
                        radius: Tokens.rounding.normal
                        color: menu.isActive ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHighest

                        Behavior on color { CAnim {} }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: Icons.getNetworkIcon(menu.network ? menu.network.strength : 0, menu.network ? menu.network.isSecure : false)
                            color: menu.isActive ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                            iconPointSize: Tokens.font.size.large
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        StyledText {
                            Layout.fillWidth: true
                            text: menu.network ? (menu.network.ssid || qsTr("Hidden network")) : ""
                            font.weight: Font.DemiBold
                            textPointSize: Tokens.font.size.larger
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        Row {
                            spacing: 6

                            // Status Tag
                            StyledRect {
                                implicitWidth: statusText.implicitWidth + 12
                                implicitHeight: 20
                                radius: Tokens.rounding.full
                                color: menu.isActive ? Qt.alpha(Colours.palette.m3primary, 0.16) : Qt.alpha(Colours.palette.m3onSurface, 0.08)

                                StyledText {
                                    id: statusText
                                    anchors.centerIn: parent
                                    text: menu.isActive ? qsTr("Connected") : (menu.isSaved ? qsTr("Saved") : qsTr("Available"))
                                    color: menu.isActive ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                    textPointSize: Tokens.font.size.smaller
                                    font.weight: Font.Medium
                                }
                            }

                            // Security Tag
                            StyledRect {
                                implicitWidth: secText.implicitWidth + 12
                                implicitHeight: 20
                                radius: Tokens.rounding.full
                                color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
                                visible: menu.network ? (menu.network.security || menu.network.isSecure) : false

                                StyledText {
                                    id: secText
                                    anchors.centerIn: parent
                                    text: menu.network ? (menu.network.security || (menu.network.isSecure ? qsTr("Secured") : qsTr("Open"))) : ""
                                    color: Colours.palette.m3onSurfaceVariant
                                    textPointSize: Tokens.font.size.smaller
                                    font.weight: Font.Normal
                                }
                            }
                        }
                    }

                    // Close Button
                    StyledRect {
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: Tokens.rounding.full
                        color: Qt.alpha(Colours.palette.m3onSurface, 0.06)

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onSurfaceVariant
                            onClicked: menu.close()
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "close"
                            iconPointSize: Tokens.font.size.small
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }

                // ── 2. Bento Grid ──────────────────────────────────────────
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 8
                    columnSpacing: 8

                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: 52
                        radius: Tokens.rounding.normal
                        color: Colours.palette.m3surfaceContainerHigh

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.small
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                text: "signal_wifi_4_bar"
                                color: Colours.palette.m3primary
                                iconPointSize: Tokens.font.size.normal
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                StyledText {
                                    text: qsTr("Signal Strength")
                                    color: Colours.palette.m3onSurfaceVariant
                                    textPointSize: Tokens.font.size.smaller
                                }

                                StyledText {
                                    text: (menu.network ? menu.network.strength : 0) + "%"
                                    font.weight: Font.Medium
                                    color: Colours.palette.m3onSurface
                                    textPointSize: Tokens.font.size.small
                                }
                            }
                        }
                    }

                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: 52
                        radius: Tokens.rounding.normal
                        color: Colours.palette.m3surfaceContainerHigh

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.small
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                text: "router"
                                color: Colours.palette.m3tertiary
                                iconPointSize: Tokens.font.size.normal
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                StyledText {
                                    text: qsTr("Frequency")
                                    color: Colours.palette.m3onSurfaceVariant
                                    textPointSize: Tokens.font.size.smaller
                                }

                                StyledText {
                                    text: {
                                        if (menu.network && menu.network.frequency) {
                                            return menu.network.frequency >= 4900 ? qsTr("5 GHz") : qsTr("2.4 GHz");
                                        }
                                        return qsTr("Standard");
                                    }
                                    font.weight: Font.Medium
                                    color: Colours.palette.m3onSurface
                                    textPointSize: Tokens.font.size.small
                                }
                            }
                        }
                    }
                }

                // ── 3. IP Address ──────────────────────────────────────────
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 46
                    radius: Tokens.rounding.normal
                    color: Colours.palette.m3surfaceContainerHigh
                    visible: menu.isActive && !!Nmcli.wirelessDeviceDetails && !!Nmcli.wirelessDeviceDetails.ipAddress

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.normal
                        anchors.rightMargin: Tokens.padding.normal
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: "lan"
                            color: Colours.palette.m3secondary
                            iconPointSize: Tokens.font.size.normal
                        }

                        StyledText {
                            text: qsTr("IP Address")
                            color: Colours.palette.m3onSurfaceVariant
                            textPointSize: Tokens.font.size.small
                        }

                        Item { Layout.fillWidth: true }

                        StyledText {
                            text: (Nmcli.wirelessDeviceDetails && Nmcli.wirelessDeviceDetails.ipAddress) ? Nmcli.wirelessDeviceDetails.ipAddress : ""
                            font.weight: Font.Medium
                            color: Colours.palette.m3onSurface
                            textPointSize: Tokens.font.size.small
                        }
                    }
                }

                // ── 4. Auto-connect ────────────────────────────────────────
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 52
                    radius: Tokens.rounding.normal
                    color: Colours.palette.m3surfaceContainerHigh
                    visible: menu.isSaved

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.normal
                        anchors.rightMargin: Tokens.padding.normal
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: "sync"
                            color: Colours.palette.m3onSurfaceVariant
                            iconPointSize: Tokens.font.size.normal
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                text: qsTr("Auto-connect")
                                color: Colours.palette.m3onSurface
                                textPointSize: Tokens.font.size.small
                                font.weight: Font.Normal
                            }

                            StyledText {
                                text: qsTr("Connect when in range")
                                color: Colours.palette.m3onSurfaceVariant
                                textPointSize: Tokens.font.size.smaller
                            }
                        }

                        StyledSwitch {
                            checked: menu.savedProfile ? menu.savedProfile.autoconnect : true
                            onToggled: {
                                if (menu.savedProfile && menu.savedProfile.uuid) {
                                    Nmcli.setAutoconnect(menu.savedProfile.uuid, checked);
                                }
                            }
                        }
                    }
                }

                // ── 5. Password Field ──────────────────────────────────────
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: passEditCol.implicitHeight + Tokens.padding.normal * 2
                    radius: Tokens.rounding.normal
                    color: Colours.palette.m3surfaceContainerHigh
                    visible: menu.isSaved && menu.network && menu.network.isSecure

                    ColumnLayout {
                        id: passEditCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Tokens.padding.normal
                        spacing: Tokens.spacing.extraSmall

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                text: "key"
                                color: Colours.palette.m3onSurfaceVariant
                                iconPointSize: Tokens.font.size.normal
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Network Password")
                                color: Colours.palette.m3onSurfaceVariant
                                textPointSize: Tokens.font.size.smaller
                            }

                            StyledText {
                                text: menu.isPasswordEditing ? qsTr("Editing…") : ""
                                color: Colours.palette.m3primary
                                textPointSize: Tokens.font.size.smaller
                                visible: menu.isPasswordEditing
                            }
                        }

                        StyledRect {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: Tokens.rounding.full
                            color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.65)
                            border.width: 0

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.padding.normal
                                anchors.rightMargin: 4
                                spacing: Tokens.spacing.extraSmall

                                TextInput {
                                    id: configPassField
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    verticalAlignment: TextInput.AlignVCenter
                                    echoMode: menu.showPasswordText ? TextInput.Normal : TextInput.Password
                                    text: menu.savedPassword
                                    color: Colours.palette.m3onSurface
                                    font.family: Tokens.font.family.sans
                                    font.pointSize: Tokens.font.size.small
                                    selectByMouse: true
                                    selectionColor: Colours.palette.m3primary
                                    selectedTextColor: Colours.palette.m3onPrimary
                                    clip: true

                                    onTextChanged: {
                                        if (text !== menu.savedPassword) {
                                            menu.isPasswordEditing = true;
                                        }
                                    }

                                    Keys.onReturnPressed: savePassword()
                                    Keys.onEnterPressed: savePassword()

                                    function savePassword() {
                                        if (menu.savedProfile && menu.savedProfile.uuid) {
                                            menu.isSavingPassword = true;
                                            Nmcli.modifyWifiPassword(menu.savedProfile.uuid, text, res => {
                                                menu.isSavingPassword = false;
                                                menu.isPasswordEditing = false;
                                                menu.savedPassword = text;
                                            });
                                        }
                                    }
                                }

                                StyledRect {
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    radius: Tokens.rounding.full
                                    color: "transparent"

                                    StateLayer {
                                        radius: parent.radius
                                        color: Colours.palette.m3onSurfaceVariant
                                        onClicked: menu.showPasswordText = !menu.showPasswordText
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: menu.showPasswordText ? "visibility_off" : "visibility"
                                        iconPointSize: Tokens.font.size.smaller
                                        color: Colours.palette.m3onSurfaceVariant
                                    }
                                }

                                StyledRect {
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    radius: Tokens.rounding.full
                                    visible: menu.isPasswordEditing
                                    color: Colours.palette.m3primary

                                    StateLayer {
                                        radius: parent.radius
                                        color: Colours.palette.m3onPrimary
                                        onClicked: configPassField.savePassword()
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: "check"
                                        iconPointSize: Tokens.font.size.smaller
                                        color: Colours.palette.m3onPrimary
                                    }
                                }
                            }
                        }
                    }
                }

                // ── 6. Action Footer ───────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledRect {
                        implicitWidth: forgetRow.implicitWidth + Tokens.padding.normal * 2
                        implicitHeight: 36
                        radius: Tokens.rounding.full
                        color: Qt.alpha(Colours.palette.m3error, 0.12)
                        visible: menu.isSaved

                        Row {
                            id: forgetRow
                            anchors.centerIn: parent
                            spacing: Tokens.spacing.extraSmall

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "delete"
                                iconPointSize: Tokens.font.size.small
                                color: Colours.palette.m3error
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Forget")
                                color: Colours.palette.m3error
                                font.weight: Font.Medium
                                textPointSize: Tokens.font.size.small
                            }
                        }

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3error
                            onClicked: {
                                if (menu.network) {
                                    Nmcli.forgetNetwork(menu.network.ssid);
                                }
                                menu.close();
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    StyledRect {
                        implicitWidth: actionRow.implicitWidth + Tokens.padding.large * 2
                        implicitHeight: 36
                        radius: Tokens.rounding.full
                        color: menu.isActive ? Colours.palette.m3errorContainer : Colours.palette.m3primary

                        Behavior on color { CAnim {} }

                        Row {
                            id: actionRow
                            anchors.centerIn: parent
                            spacing: Tokens.spacing.extraSmall

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: menu.isActive ? "wifi_off" : "wifi"
                                iconPointSize: Tokens.font.size.small
                                color: menu.isActive ? Colours.palette.m3onErrorContainer : Colours.palette.m3onPrimary
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: menu.isActive ? qsTr("Disconnect") : qsTr("Connect")
                                color: menu.isActive ? Colours.palette.m3onErrorContainer : Colours.palette.m3onPrimary
                                font.weight: Font.Medium
                                textPointSize: Tokens.font.size.small
                            }
                        }

                        StateLayer {
                            radius: parent.radius
                            color: menu.isActive ? Colours.palette.m3error : Colours.palette.m3onPrimary
                            onClicked: {
                                if (menu.isActive) {
                                    Nmcli.disconnectFromNetwork();
                                } else if (menu.network) {
                                    NetworkConnection.handleConnect(menu.network, menu.session);
                                }
                                menu.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
