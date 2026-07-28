import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.bar.popouts
import qs.utils

StyledRect {
    id: root

    required property PopoutState popouts
    property var network: null
    property bool isClosing: false
    property string failedSsid: ""

    readonly property bool shouldBeVisible: root.popouts.currentName === "wirelesspassword"

    function triggerFallback(): void {
        const ssidToFallback = NetworkConnection.previousSsid;
        if (ssidToFallback !== "" && (!Nmcli.active || Nmcli.active.ssid !== ssidToFallback)) {
            console.log("WirelessPassword - [HARDENED] Smart Fallback: Attempting recovery to:", ssidToFallback);
            
            // Aggressive cleanup before fallback
            Nmcli.connectionCheckTimer.stop();
            Nmcli.immediateCheckTimer.stop();
            Nmcli.pendingConnection = null;
            
            // Small delay to let Nmcli breathe after a failure/forget operation
            Qt.callLater(() => {
                Nmcli.connectToNetwork(ssidToFallback, "", "", result => {
                    console.log("WirelessPassword - Fallback recovery result for", ssidToFallback, ":", result.success ? "SUCCESS" : "FAILED");
                    if (result.success) {
                        NetworkConnection.previousSsid = "";
                    }
                });
            });
        } else {
            console.log("WirelessPassword - Fallback skipped: No valid previous SSID or already connected.");
        }
    }

    function closeDialog(): void {
        if (root.isClosing) return;

        console.log("WirelessPassword - Closing dialog. Error state:", connectButton.hasError);

        const shouldFallback = connectButton.hasError;
        const failedSsid = root.network ? root.network.ssid : "";

        root.isClosing = true;

        // Force cleanup of Nmcli pending states
        Nmcli.connectionCheckTimer.stop();
        Nmcli.immediateCheckTimer.stop();
        Nmcli.pendingConnection = null;

        if (shouldFallback) {
            // Forget failed network before fallback to avoid repeated prompts
            if (failedSsid) {
                Nmcli.forgetNetwork(failedSsid, () => {
                    triggerFallback();
                });
            } else {
                triggerFallback();
            }
        }

        if (root.popouts.currentName === "wirelesspassword") {
            root.popouts.currentName = "network";
        }
        
        // Final reset after a small delay
        Qt.callLater(() => {
            passwordContainer.passwordBuffer = "";
            connectButton.connecting = false;
            connectButton.hasError = false;
            connectButton.text = qsTr("Connect");
            root.isClosing = false;
        });
    }

    implicitWidth: 400
    implicitHeight: content.implicitHeight + Tokens.padding.large * 2
    visible: shouldBeVisible || isClosing
    enabled: shouldBeVisible && !isClosing
    focus: enabled

    Behavior on opacity { Anim {} }
    opacity: shouldBeVisible ? 1 : 0

    onShouldBeVisibleChanged: {
        if (shouldBeVisible) {
            passwordContainer.passwordBuffer = "";
            connectButton.hasError = false;
            connectButton.connecting = false;
            connectButton.text = qsTr("Connect");
            isClosing = false;
            
            // Force focus chain
            Qt.callLater(() => {
                root.forceActiveFocus();
                hiddenInput.text = "";
                hiddenInput.forceActiveFocus();
            });
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: true
        onTriggered: {
            if (root.shouldBeVisible && root.Window.window && root.Window.window.activeFocusItem) {
                console.log("WirelessPassword - CURRENT activeFocusItem:", root.Window.window.activeFocusItem, "type:", root.Window.window.activeFocusItem.toString());
            }
        }
    }

    ColumnLayout {
        id: content
        anchors.centerIn: parent
        width: parent.width - Tokens.padding.large * 2
        spacing: Tokens.spacing.large

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small
            
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: root.network ? root.network.ssid : "WiFi Network"
                textPointSize: Tokens.font.size.large
                font.bold: true
                color: Colours.palette.m3onSurface
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Enter password to connect")
                textPointSize: Tokens.font.size.small
                color: Qt.alpha(Colours.palette.m3onSurface, 0.7)
            }
        }

        // Password Input Area
        StyledRect {
            id: passwordContainer
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            radius: 20
            
            // Premium Glassmorphic Gradient
            color: "transparent"
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.alpha(Colours.palette.m3onSurface, hiddenInput.activeFocus ? 0.12 : 0.08) }
                GradientStop { position: 1.0; color: Qt.alpha(Colours.palette.m3onSurface, hiddenInput.activeFocus ? 0.08 : 0.04) }
            }
            
            border.width: 1.5
            border.color: hiddenInput.activeFocus ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.15)
            
            Behavior on border.color { CAnim {} }
            
            property alias passwordBuffer: hiddenInput.text

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 16
                spacing: 12

                // Lock Icon
                MaterialIcon {
                    text: "lock"
                    iconPointSize: 20
                    color: hiddenInput.activeFocus ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.5)
                    Behavior on color { CAnim {} }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Placeholder text
                    StyledText {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: qsTr("Password")
                        color: Qt.alpha(Colours.palette.m3onSurface, 0.3)
                        textPointSize: Tokens.font.size.normal
                        visible: hiddenInput.text.length === 0
                        
                        Behavior on opacity { Anim {} }
                    }

                    TextInput {
                        id: hiddenInput
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        color: Colours.palette.m3onSurface
                        font.pixelSize: Math.round(Tokens.font.size.large * 96 / 72)
                        font.family: Tokens.font.family.regular
                        echoMode: TextInput.Normal
                        focus: true
                        clip: true
                        
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                event.accepted = true;
                                NetworkConnection.forceFallback();
                                root.closeDialog();
                            }
                            if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                event.accepted = true;
                                if (connectButton.enabled && !connectButton.connecting) {
                                    connectButton.clicked();
                                }
                            }
                        }
                    }
                }

                // Clear button (appears when text exists)
                MaterialIcon {
                    text: "close"
                    iconPointSize: 18
                    color: Qt.alpha(Colours.palette.m3onSurface, 0.4)
                    visible: hiddenInput.text.length > 0
                    opacity: mouseClear.containsMouse ? 1.0 : 0.6
                    
                    MouseArea {
                        id: mouseClear
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            hiddenInput.text = "";
                            hiddenInput.forceActiveFocus();
                        }
                    }
                }
            }
            
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: hiddenInput.forceActiveFocus()
            }

            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: passwordContainer; property: "anchors.horizontalCenterOffset"; from: 0; to: 10; duration: 50 }
                NumberAnimation { target: passwordContainer; property: "anchors.horizontalCenterOffset"; from: 10; to: -10; duration: 50 }
                NumberAnimation { target: passwordContainer; property: "anchors.horizontalCenterOffset"; from: -10; to: 10; duration: 50 }
                NumberAnimation { target: passwordContainer; property: "anchors.horizontalCenterOffset"; from: 10; to: 0; duration: 50 }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.normal

            TextButton {
                id: cancelButton
                Layout.fillWidth: true
                Layout.preferredWidth: 100
                text: qsTr("Cancel")
                type: TextButton.Tonal
                onClicked: {
                    NetworkConnection.forceFallback();
                    root.closeDialog();
                }
                enabled: !connectButton.connecting
                
                Behavior on Layout.preferredWidth { Anim {} }
            }

            TextButton {
                id: connectButton
                Layout.fillWidth: true
                Layout.preferredWidth: 200
                text: qsTr("Connect")
                type: TextButton.Filled
                property bool connecting: false
                property bool hasError: false
                
                activeColour: {
                    if (hasError) return Colours.palette.m3error;
                    if (!enabled && !connecting) return Colours.palette.m3surfaceVariant;
                    return Colours.palette.m3primary;
                }
                inactiveColour: activeColour
                
                label.color: hasError ? Colours.palette.m3onError : (enabled || connecting ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant)
                label.opacity: enabled || connecting ? 1.0 : 0.6
                
                enabled: passwordContainer.passwordBuffer.length >= 8 && !connecting

                Behavior on Layout.preferredWidth { Anim {} }
                Behavior on scale { Anim { type: Anim.Bouncy } }
                scale: enabled ? 1.0 : 0.95

                onClicked: {
                    connecting = true;
                    hasError = false;
                    root.failedSsid = "";
                    text = qsTr("Connecting...");
                    
                    const networkToConnect = root.network;
                    NetworkConnection.connectWithPassword(networkToConnect, passwordContainer.passwordBuffer, result => {
                        if (result.success) {
                            if (root && !root.isClosing) root.closeDialog();
                        } else {
                            if (root && !root.isClosing) {
                                connecting = false;
                                hasError = true;
                                root.failedSsid = networkToConnect ? networkToConnect.ssid : "";
                                text = qsTr("Connection fail");
                                shakeAnim.start();
                                hiddenInput.text = "";
                                hiddenInput.forceActiveFocus();
                            } else {
                                NetworkConnection.forceFallback();
                            }
                        }
                    });
                }

                SequentialAnimation on opacity {
                    running: connectButton.connecting
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.7; duration: 600; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 0.7; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                }
            }
        }
    }
    
    // Auto-clear error when user types
    Connections {
        target: hiddenInput
        function onTextChanged(): void {
            if (connectButton.hasError) {
                connectButton.hasError = false;
                connectButton.text = qsTr("Connect");
            }
        }
    }
}
