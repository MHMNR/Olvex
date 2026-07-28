import QtQuick
import Quickshell.Services.UPower
import qs.services

Item {
    id: root

    property real bgOpacity: 0.2
    property bool animating: PowerProfiles.profile !== PowerProfile.PowerSaver
    property bool active: visible

    readonly property bool shaderReady: fx.status === ShaderEffect.Ready
    readonly property real elapsed: clock.elapsed

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
        property real iKind: Weather.visualKind
        property real iIsDay: Weather.isDay ? 1.0 : 0.0
        property color iPrimary: Colours.palette.m3primary
        property color iSecondary: Colours.palette.m3secondary
        property color iTertiary: Colours.palette.m3tertiary
        property real iWidth: Math.max(width, 1)
        property real iHeight: Math.max(height, 1)

        fragmentShader: Qt.resolvedUrl("../../../assets/shaders/weather/weather_bg.frag.qsb")
    }

    Timer {
        id: clock

        interval: 33
        running: root.active && root.animating && root.shaderReady
        repeat: true

        property real elapsed: 0

        onTriggered: elapsed += interval / 1000.0
    }
}
