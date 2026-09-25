import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Olvex
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    anchors.fill: parent
    width: parent ? parent.width : (Screen ? Screen.width : 1920)
    height: parent ? parent.height : (Screen ? Screen.height : 1080)
    enabled: false
    visible: root.active
    z: 1500

    property bool active: false
    property real progress: 0.0
    property real textEntrance: 0.0
    property real textExit: 0.0

    // Battery values
    readonly property real batteryPercentage: UPower.displayDevice ? UPower.displayDevice.percentage : 1.0
    readonly property int batteryPercentInt: Math.round(batteryPercentage * 100)
    readonly property bool isFullyCharged: UPower.displayDevice ? (UPower.displayDevice.state === UPowerDeviceState.FullyCharged || batteryPercentInt >= 99) : false

    function trigger() {
        console.log("ChargingRipple trigger() called! Parent:", parent, "Width:", root.width, "Height:", root.height, "WindowWidth:", Screen ? Screen.width : -1)
        if (!(GlobalConfig.general.battery.chargingRipple ?? true))
            return;
        rippleMasterAnim.stop();
        root.progress = 0.0;
        root.textEntrance = 0.0;
        root.textExit = 0.0;
        root.active = true;
        rippleMasterAnim.start();
    }

    Connections {
        target: Visibilities
        function onChargingRippleTriggered() {
            root.trigger();
        }
    }

    // ── Lazy GPU Shader Loader (Zero CPU/GPU overhead when inactive) ──
    Loader {
        id: shaderLoader
        anchors.fill: parent
        active: root.active
        visible: root.active

        sourceComponent: Rectangle {
            color: "transparent"
            layer.enabled: true
            layer.effect: ShaderEffect {
                readonly property real iProgress: root.progress
                readonly property real iAspectRatio: Math.max(1.0, (root.width > 0 ? root.width : 1920) / Math.max(1.0, (root.height > 0 ? root.height : 1080)))
                readonly property color iPrimary: Colours.palette.m3primary
                readonly property color iTertiary: Colours.palette.m3tertiary
                readonly property color iPrimaryContainer: Colours.palette.m3primaryContainer
                readonly property real iOriginX: 0.5
                readonly property real iOriginY: 0.5
                vertexShader: Quickshell.shellPath("assets/shaders/charging_ripple.vert.qsb")
                fragmentShader: Quickshell.shellPath("assets/shaders/charging_ripple.frag.qsb")
            }
        }
    }

    // ── Center Charging Text / Status Indicator ──
    Column {
        id: centerChargeStatus
        anchors.centerIn: parent
        spacing: 4
        visible: root.active

        opacity: {
            if (root.textExit > 0)
                return Math.max(0, 1.0 - root.textExit);
            return root.textEntrance;
        }

        scale: {
            if (root.textExit > 0)
                return 1.0 - root.textExit * 0.04;
            return 0.92 + root.textEntrance * 0.08;
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: "bolt"
                iconPointSize: 24
                color: Colours.palette.m3primary
                fill: 1
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.batteryPercentInt + "%"
                font.pixelSize: 28
                font.weight: Font.Bold
                color: Colours.palette.m3onSurface
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.isFullyCharged ? qsTr("Fully Charged") : qsTr("Charging")
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Colours.palette.m3primary
        }
    }

    // ── Master Animation Choreography ──
    ParallelAnimation {
        id: rippleMasterAnim

        // Ambient water ripple shader expansion (0ms - 4800ms)
        NumberAnimation {
            target: root
            property: "progress"
            from: 0.0
            to: 1.0
            duration: 4800
            easing: Tokens.anim.emphasizedDecel
        }

        // Center text entrance -> hold -> exit sequence (total 4800ms)
        SequentialAnimation {
            // Smooth entrance (600ms)
            NumberAnimation {
                target: root
                property: "textEntrance"
                from: 0.0
                to: 1.0
                duration: 600
                easing: Tokens.anim.emphasizedDecel
            }

            // Calm hold in center (3200ms)
            PauseAnimation { duration: 3200 }

            // Smooth fade out (1000ms)
            NumberAnimation {
                target: root
                property: "textExit"
                from: 0.0
                to: 1.0
                duration: 1000
                easing: Tokens.anim.emphasizedAccel
            }
        }

        onFinished: {
            root.active = false;
            root.progress = 0.0;
            root.textEntrance = 0.0;
            root.textExit = 0.0;
        }
    }
}
