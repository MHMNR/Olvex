import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.services
import qs.utils
import ".."
import "../../../components"
import "../../../components/controls"
import "../../../components/effects"
import "../../../components/icons"

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

    readonly property real targetW: Math.min(390, Math.max(320, (menu.width > 50) ? (menu.width - 32) : 390))
    readonly property real targetH: Math.max(340, (contentCol ? contentCol.implicitHeight + 36 : 380))
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
        opacity: container.state === "expanded" ? (Colours.light ? 0.42 : 0.62) : 0.0
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
            hoverEnabled: true
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
                    color: Colours.light ? Colours._tileSurfaceRgb : Colours.palette.m3surfaceBright
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

        // Prevent clicks & hovers within container from leaking
        MouseArea {
            anchors.fill: parent
            enabled: container.state === "expanded"
            hoverEnabled: true
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
                anchors.margins: 18
                spacing: 10

                // ── 1. Header ──────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Leading Squircle Icon (46x46 box with 22px icon)
                    StyledRect {
                        implicitWidth: 46
                        implicitHeight: 46
                        radius: 14
                        color: menu.isActive ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHighest

                        Behavior on color { CAnim {} }

                        WifiLottieIcon {
                            anchors.centerIn: parent
                            size: 22
                            wifiEnabled: true
                            connected: menu.isActive
                            signalStrength: (menu.network ? menu.network.strength : 0) / 100.0
                            color: menu.isActive ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                            disabledColor: menu.isActive ? Qt.rgba(1, 1, 1, 0.35) : Qt.alpha(Colours.palette.m3onSurface, 0.28)
                            connecting: false
                            locked: !menu.isActive && (menu.network ? menu.network.isSecure : false)
                            saved: menu.isSaved && !menu.isActive
                            showSlashOnDisable: false
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 4

                        // SSID Title: 18px-20px SemiBold
                        StyledText {
                            Layout.fillWidth: true
                            text: menu.network ? (menu.network.ssid || qsTr("Hidden network")) : ""
                            font.weight: Font.DemiBold
                            textPixelSize: 19
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            spacing: 8

                            // Status Tag: 11px Medium with breathing room padding
                            StyledRect {
                                implicitWidth: statusText.implicitWidth + 20
                                implicitHeight: 22
                                radius: Tokens.rounding.full
                                color: menu.isActive ? Qt.alpha(Colours.palette.m3primary, 0.16) : Qt.alpha(Colours.palette.m3onSurface, 0.08)

                                StyledText {
                                    id: statusText
                                    anchors.centerIn: parent
                                    text: menu.isActive ? qsTr("Connected") : (menu.isSaved ? qsTr("Saved") : qsTr("Available"))
                                    color: menu.isActive ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                    textPixelSize: 11
                                    font.weight: Font.Medium
                                }
                            }

                            // Security Tag: 11px Medium with breathing room padding
                            StyledRect {
                                implicitWidth: secText.implicitWidth + 20
                                implicitHeight: 22
                                radius: Tokens.rounding.full
                                color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
                                visible: menu.network ? (menu.network.security || menu.network.isSecure) : false

                                StyledText {
                                    id: secText
                                    anchors.centerIn: parent
                                    text: menu.network ? (menu.network.security || (menu.network.isSecure ? qsTr("Secured") : qsTr("Open"))) : ""
                                    color: Colours.palette.m3onSurfaceVariant
                                    textPixelSize: 11
                                    font.weight: Font.Medium
                                }
                            }
                        }
                    }

                    // Close Button: Vertically centered with the header
                    StyledRect {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 32
                        implicitHeight: 32
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
                            iconPointSize: 12
                            fill: 0
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }

                // ── 2. Bento Grid (Signal & Frequency) ─────────────────────
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 10
                    columnSpacing: 10

                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: 56
                        radius: Tokens.rounding.normal
                        color: Colours.palette.m3surfaceContainerHigh

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Item {
                                width: 22
                                height: 22
                                Layout.alignment: Qt.AlignVCenter

                                WifiLottieIcon {
                                    anchors.centerIn: parent
                                    size: 18
                                    wifiEnabled: true
                                    connected: true
                                    signalStrength: (menu.network ? menu.network.strength : 0) / 100.0
                                    color: Colours.palette.m3primary
                                    disabledColor: Qt.alpha(Colours.palette.m3primary, 0.28)
                                    showSlashOnDisable: false
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                // Label: 12px Regular, muted
                                StyledText {
                                    text: qsTr("Signal Strength")
                                    color: Colours.palette.m3onSurfaceVariant
                                    textPixelSize: 12
                                    font.weight: Font.Normal
                                }

                                // Value: 15px-16px SemiBold, bright
                                StyledText {
                                    text: (menu.network ? menu.network.strength : 0) + "%"
                                    font.weight: Font.DemiBold
                                    color: Colours.palette.m3onSurface
                                    textPixelSize: 15
                                }
                            }
                        }
                    }

                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: 56
                        radius: Tokens.rounding.normal
                        color: Colours.palette.m3surfaceContainerHigh

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Item {
                                width: 22
                                height: 22
                                Layout.alignment: Qt.AlignVCenter

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "router"
                                    color: Colours.palette.m3tertiary
                                    iconPointSize: 13.5
                                    fill: 0
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                // Label: 12px Regular, muted
                                StyledText {
                                    text: qsTr("Frequency")
                                    color: Colours.palette.m3onSurfaceVariant
                                    textPixelSize: 12
                                    font.weight: Font.Normal
                                }

                                // Value: 15px-16px SemiBold, bright
                                StyledText {
                                    text: {
                                        if (menu.network && menu.network.frequency) {
                                            return menu.network.frequency >= 4900 ? qsTr("5 GHz") : qsTr("2.4 GHz");
                                        }
                                        return qsTr("Standard");
                                    }
                                    font.weight: Font.DemiBold
                                    color: Colours.palette.m3onSurface
                                    textPixelSize: 15
                                }
                            }
                        }
                    }
                }

                // ── 3. IP Address Card ─────────────────────────────────────
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    radius: Tokens.rounding.normal
                    color: Colours.palette.m3surfaceContainerHigh
                    visible: menu.isActive && !!Nmcli.wirelessDeviceDetails && !!Nmcli.wirelessDeviceDetails.ipAddress

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        Item {
                            width: 22
                            height: 22
                            Layout.alignment: Qt.AlignVCenter

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "lan"
                                color: Colours.palette.m3secondary
                                iconPointSize: 13.5
                                fill: 0
                            }
                        }

                        // Label: 14px Medium
                        StyledText {
                            text: qsTr("IP Address")
                            color: Colours.palette.m3onSurface
                            textPixelSize: 14
                            font.weight: Font.Medium
                        }

                        Item { Layout.fillWidth: true }

                        // Value: 14px Monospace / Tabular
                        StyledText {
                            text: (Nmcli.wirelessDeviceDetails && Nmcli.wirelessDeviceDetails.ipAddress) ? Nmcli.wirelessDeviceDetails.ipAddress : ""
                            font.family: Tokens.font.family.mono
                            font.weight: Font.Medium
                            textPixelSize: 14
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }

                // ── 4. Auto-connect Row ────────────────────────────────────
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 54
                    radius: Tokens.rounding.normal
                    color: Colours.palette.m3surfaceContainerHigh
                    visible: menu.isSaved

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 12
                        spacing: 10

                        Item {
                            width: 22
                            height: 22
                            Layout.alignment: Qt.AlignVCenter

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "sync"
                                color: Colours.palette.m3onSurfaceVariant
                                iconPointSize: 13.5
                                fill: 0
                            }
                        }

                        ColumnLayout {
                            spacing: 2

                            // Primary Title: 14px Medium bright
                            StyledText {
                                text: qsTr("Auto-connect")
                                color: Colours.palette.m3onSurface
                                textPixelSize: 14
                                font.weight: Font.Medium
                            }

                            // Subtext: 12px Regular muted
                            StyledText {
                                text: qsTr("Connect when in range")
                                color: Colours.palette.m3onSurfaceVariant
                                textPixelSize: 12
                                font.weight: Font.Normal
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        StyledSwitch {
                            Layout.alignment: Qt.AlignVCenter
                            checked: menu.savedProfile ? menu.savedProfile.autoconnect : true
                            onToggled: {
                                if (menu.savedProfile && menu.savedProfile.uuid) {
                                    Nmcli.setAutoconnect(menu.savedProfile.uuid, checked);
                                }
                            }
                        }
                    }
                }

                // ── 5. Password Field Refinement ───────────────────────────
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: passEditCol.implicitHeight + 24
                    radius: Tokens.rounding.normal
                    color: Colours.palette.m3surfaceContainerHigh
                    visible: menu.isSaved && menu.network && menu.network.isSecure

                    ColumnLayout {
                        id: passEditCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Item {
                                width: 22
                                height: 22
                                Layout.alignment: Qt.AlignVCenter

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "key"
                                    color: Colours.palette.m3onSurfaceVariant
                                    iconPointSize: 13.5
                                    fill: 0
                                }
                            }

                            // Label: 14px Medium
                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Network Password")
                                color: Colours.palette.m3onSurface
                                textPixelSize: 14
                                font.weight: Font.Medium
                            }

                            StyledText {
                                text: menu.isPasswordEditing ? qsTr("Editing…") : ""
                                color: Colours.palette.m3primary
                                textPixelSize: 12
                                visible: menu.isPasswordEditing
                            }
                        }

                        // Subtle inner pill container
                        StyledRect {
                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: Tokens.rounding.full
                            color: Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.70)
                            border.width: 0

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 12
                                spacing: 8

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    // Crisp 7px password dots
                                    M3PasswordDots {
                                        anchors.fill: parent
                                        text: configPassField.text
                                        dotSize: 7
                                        dotSpacing: 5
                                        color: Colours.palette.m3onSurface
                                        hasFocus: configPassField.activeFocus
                                        visible: !menu.showPasswordText
                                    }

                                    TextInput {
                                        id: configPassField
                                        anchors.fill: parent
                                        verticalAlignment: TextInput.AlignVCenter
                                        echoMode: TextInput.Normal
                                        text: menu.savedPassword
                                        color: menu.showPasswordText ? Colours.palette.m3onSurface : "transparent"
                                        cursorVisible: menu.showPasswordText
                                        font.family: Tokens.font.family.sans
                                        font.pixelSize: 13
                                        selectByMouse: true
                                        selectionColor: Colours.palette.m3primary
                                        selectedTextColor: Colours.palette.m3onPrimary
                                        clip: true

                                        HoverHandler {
                                            cursorShape: Qt.IBeamCursor
                                        }

                                        cursorDelegate: Item {
                                            visible: menu.showPasswordText && configPassField.cursorVisible
                                            width: visible ? 2 : 0
                                            height: visible ? (configPassField.height * 0.7) : 0
                                            Rectangle {
                                                anchors.fill: parent
                                                color: Colours.palette.m3primary
                                                radius: 1
                                            }
                                        }

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
                                        iconPointSize: 12
                                        fill: 0
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
                                        iconPointSize: 11
                                        color: Colours.palette.m3onPrimary
                                    }
                                }
                            }
                        }
                    }
                }

                // ── 6. Bottom Action Buttons (50/50 Equal Width) ───────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    // Forget Button (50% equal width, subtle tonal style)
                    StyledRect {
                        id: forgetBtn
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 40
                        radius: 20
                        color: Qt.alpha(Colours.palette.m3error, 0.10)
                        visible: menu.isSaved

                        Row {
                            id: forgetRow
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "delete"
                                iconPointSize: 12
                                fill: 0
                                color: Colours.palette.m3error
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Forget")
                                color: Colours.palette.m3error
                                font.weight: Font.Medium
                                textPixelSize: 13
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

                    // Disconnect / Connect Button (50% equal width, filled style)
                    StyledRect {
                        id: actionBtn
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 40
                        radius: 20
                        color: menu.isActive ? Colours.palette.m3error : Colours.palette.m3primary

                        Behavior on color { CAnim {} }

                        Row {
                            id: actionRow
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: menu.isActive ? "wifi_off" : "wifi"
                                iconPointSize: 12
                                fill: 0
                                color: menu.isActive ? Colours.palette.m3onError : Colours.palette.m3onPrimary
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: menu.isActive ? qsTr("Disconnect") : qsTr("Connect")
                                color: menu.isActive ? Colours.palette.m3onError : Colours.palette.m3onPrimary
                                font.weight: Font.Medium
                                textPixelSize: 13
                            }
                        }

                        StateLayer {
                            radius: parent.radius
                            color: menu.isActive ? Colours.palette.m3onError : Colours.palette.m3onPrimary
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
