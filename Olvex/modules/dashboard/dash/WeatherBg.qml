import QtQuick
import Quickshell.Services.UPower
import qs.services

Item {
    id: root

    property real bgOpacity: 0.2
    property bool animating: PowerProfiles.profile !== PowerProfile.PowerSaver
    property bool active: visible
    property real overrideKind: -1
    property real overrideDayCycle: -1.0
    property real overrideMoonPhase: -1.0

    readonly property bool shaderReady: fx.status === ShaderEffect.Compiled
    readonly property real elapsed: clock.elapsed
    readonly property real targetCycle: root.overrideDayCycle >= 0.0 ? root.overrideDayCycle : Weather.dayCycle
    property real continuousCycle: targetCycle
    property bool cycleInitialized: false

    onTargetCycleChanged: {
        if (!cycleInitialized) {
            continuousCycle = targetCycle;
            cycleInitialized = true;
            return;
        }
        const curMod = ((continuousCycle % 2.0) + 2.0) % 2.0;
        let diff = targetCycle - curMod;
        if (diff > 1.0)
            diff -= 2.0;
        else if (diff < -1.0)
            diff += 2.0;
        continuousCycle += diff;
    }

    Component.onCompleted: {
        continuousCycle = targetCycle;
        cycleInitialized = true;
    }

    Rectangle {
        anchors.fill: parent
        visible: !root.shaderReady
        color: "transparent"
    }

    ShaderEffect {
        id: fx

        anchors.fill: parent
        visible: root.shaderReady
        opacity: root.bgOpacity

        property real iTime: root.elapsed
        property real iKind: root.overrideKind >= 0 ? root.overrideKind : Weather.visualKind
        property real iIsDay: iSunProgress <= 1.0 ? 1.0 : 0.0
        property color iPrimary: Colours.palette.m3primary
        property color iSecondary: Colours.palette.m3secondary
        property color iTertiary: Colours.palette.m3tertiary
        property real iWidth: Math.max(width, 1)
        property real iHeight: Math.max(height, 1)
        property real iSunProgress: root.continuousCycle
        property real iMoonPhase: root.overrideMoonPhase >= 0.0 ? root.overrideMoonPhase : Weather.moonPhase

        Behavior on iSunProgress {
            enabled: root.animating
            SmoothedAnimation {
                velocity: 2.4
            }
        }

        fragmentShader: Qt.resolvedUrl("../../../assets/shaders/weather/weather_bg.frag.qsb")
    }

    Timer {
        id: clock

        interval: 16
        running: root.active && root.animating && root.shaderReady
        repeat: true

        property real elapsed: 0

        onTriggered: elapsed += interval / 1000.0
    }
}
