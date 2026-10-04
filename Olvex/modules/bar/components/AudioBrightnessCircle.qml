import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Olvex.Config
import qs.components
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    required property var bar
    required property Brightness.Monitor monitor

    property string activeMetric: "volume" // "volume" | "brightness" | "mic"
    property bool isAutoRevealed: false
    property bool isHovered: false
    readonly property bool isOverlayRendering: Boolean(root.bar && root.bar.audioBrightnessMorph && (root.bar.audioBrightnessMorph.active || root.bar.audioBrightnessMorph.morphAnimating))
    readonly property bool shouldBeVisible: isOverlayRendering || (Config.bar.quickOrb.enabled && (isAutoRevealed || isHovered))

    property real circleSize: 48
    readonly property real circleRadius: circleSize / 2

    property real lastVolume: Audio.volume
    property bool lastMuted: Audio.muted
    property real lastSourceVolume: Audio.sourceVolume
    property bool lastSourceMuted: Audio.sourceMuted
    property real lastBrightness: (root.monitor && typeof root.monitor.brightness === "number") ? root.monitor.brightness : 0

    property bool showPercentage: false

    readonly property int percentVal: {
        if (root.activeMetric === "brightness") {
            const b = (root.monitor && typeof root.monitor.brightness === "number") ? root.monitor.brightness : 0;
            return Math.round(Math.max(0, Math.min(1.0, b)) * 100);
        } else if (root.activeMetric === "mic") {
            return Audio.sourceMuted ? 0 : Math.round(Math.max(0, Math.min(1.0, Audio.sourceVolume / (GlobalConfig.services.maxVolume || 1.0))) * 100);
        } else {
            return Audio.muted ? 0 : Math.round(Math.max(0, Math.min(1.0, Audio.volume / (GlobalConfig.services.maxVolume || 1.0))) * 100);
        }
    }

    Timer {
        id: percentageTimer
        interval: 1300
        repeat: false
        onTriggered: {
            root.showPercentage = false;
        }
    }

    function triggerReveal(metric, isChanging) {
        if (metric)
            root.activeMetric = metric;
        root.isAutoRevealed = true;
        autoHideTimer.restart();
        if (isChanging !== false && Config.bar.quickOrb.showPercentage) {
            root.showPercentage = true;
            percentageTimer.restart();
        }
    }

    Timer {
        id: autoHideTimer
        interval: Config.bar.quickOrb.autoHideDelay
        repeat: false
        onTriggered: {
            if (!root.isHovered && !root.isOverlayRendering) {
                root.isAutoRevealed = false;
            }
        }
    }

    Connections {
        target: Audio
        function onVolumeChanged() {
            if (Math.abs(Audio.volume - root.lastVolume) > 0.001) {
                root.lastVolume = Audio.volume;
                if (Config.bar.quickOrb.autoRevealVolume)
                    root.triggerReveal("volume", true);
            }
        }
        function onMutedChanged() {
            if (Audio.muted !== root.lastMuted) {
                root.lastMuted = Audio.muted;
                if (Config.bar.quickOrb.autoRevealVolume)
                    root.triggerReveal("volume", true);
            }
        }
        function onSourceVolumeChanged() {
            if (Math.abs(Audio.sourceVolume - root.lastSourceVolume) > 0.001) {
                root.lastSourceVolume = Audio.sourceVolume;
                if (Config.bar.quickOrb.autoRevealMic)
                    root.triggerReveal("mic", true);
            }
        }
        function onSourceMutedChanged() {
            if (Audio.sourceMuted !== root.lastSourceMuted) {
                root.lastSourceMuted = Audio.sourceMuted;
                if (Config.bar.quickOrb.autoRevealMic)
                    root.triggerReveal("mic", true);
            }
        }
    }

    Connections {
        target: root.monitor
        function onBrightnessChanged() {
            const b = (root.monitor && typeof root.monitor.brightness === "number") ? root.monitor.brightness : 0;
            if (Math.abs(b - root.lastBrightness) > 0.001) {
                root.lastBrightness = b;
                if (Config.bar.quickOrb.autoRevealBrightness)
                    root.triggerReveal("brightness", true);
            }
        }
    }

    Component.onCompleted: {
        root.lastVolume = Audio.volume;
        root.lastMuted = Audio.muted;
        root.lastSourceVolume = Audio.sourceVolume;
        root.lastSourceMuted = Audio.sourceMuted;
        root.lastBrightness = (root.monitor && typeof root.monitor.brightness === "number") ? root.monitor.brightness : 0;
    }

    readonly property var gentleSpringCurve: [0.32, 1.07, 0.36, 1.015, 1.0, 1.0]
    readonly property real revealProgress: root.shouldBeVisible ? 1.0 : 0.0
    property real animatedRevealProgress: revealProgress

    Behavior on animatedRevealProgress {
        NumberAnimation {
            duration: root.shouldBeVisible ? 360 : 220
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.shouldBeVisible ? root.gentleSpringCurve : [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
        }
    }

    readonly property real kineticShift: {
        if (!root.bar) return 0;
        const force = (typeof root.bar.cascadeForce === "number" && !isNaN(root.bar.cascadeForce)) ? root.bar.cascadeForce : 0;
        return force * 0.55;
    }

    property real animatedKineticShift: kineticShift
    Behavior on animatedKineticShift {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    implicitWidth: circleSize
    implicitHeight: Math.max(0, (circleSize + 8) * animatedRevealProgress)
    visible: animatedRevealProgress > 0.005

    function expand() {
        if (root.bar && typeof root.bar.expandAudioBrightnessMorphFromPill === "function") {
            autoHideTimer.stop();
            root.bar.expandAudioBrightnessMorphFromPill(circleBox, centerIcon, root.activeMetric);
        }
    }

    Item {
        id: circleBox
        width: root.circleSize
        height: root.circleSize
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        transformOrigin: Item.Center
        opacity: root.isOverlayRendering ? 0 : Math.min(1.0, root.animatedRevealProgress * 2.0)
        visible: !root.isOverlayRendering && root.animatedRevealProgress > 0.005
        enabled: !root.isOverlayRendering && root.shouldBeVisible
        scale: 0.88 + 0.12 * root.animatedRevealProgress

        transform: Translate {
            y: root.animatedKineticShift + (1.0 - root.animatedRevealProgress) * 4
        }

        // Clean M3 Surface (Border-free, Shadow-free)
        Rectangle {
            id: bg
            anchors.fill: parent
            radius: root.circleRadius
            color: Colours.tileSurface
            antialiasing: true
            smooth: true
        }

        // Circular Gauge Progress Ring
        Shape {
            id: progressShape
            anchors.fill: parent
            anchors.margins: 3
            preferredRendererType: Shape.CurveRenderer
            asynchronous: true

            readonly property real currentVal: {
                if (root.activeMetric === "brightness") {
                    const b = (root.monitor && typeof root.monitor.brightness === "number") ? root.monitor.brightness : 0;
                    return Math.max(0, Math.min(1.0, b));
                } else if (root.activeMetric === "mic") {
                    return Audio.sourceMuted ? 0 : Math.max(0, Math.min(1.0, Audio.sourceVolume / (GlobalConfig.services.maxVolume || 1.0)));
                } else {
                    return Audio.muted ? 0 : Math.max(0, Math.min(1.0, Audio.volume / (GlobalConfig.services.maxVolume || 1.0)));
                }
            }

            property real animVal: currentVal
            Behavior on animVal {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.gentleSpringCurve
                }
            }

            readonly property color ringAccent: {
                if (root.activeMetric === "brightness") {
                    return Colours.palette.m3tertiary;
                } else if (root.activeMetric === "mic") {
                    return Audio.sourceMuted ? Colours.palette.m3error : Colours.palette.m3secondary;
                } else {
                    return Audio.muted ? Colours.palette.m3error : Colours.palette.m3primary;
                }
            }

            readonly property real strokeW: 3
            readonly property real arcR: (width - strokeW) / 2
            readonly property real cX: width / 2
            readonly property real cY: height / 2

            // Inactive Track
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.alpha(Colours.palette.m3onSurface, 0.14)
                strokeWidth: progressShape.strokeW
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    startAngle: -90
                    sweepAngle: 360
                    radiusX: progressShape.arcR
                    radiusY: progressShape.arcR
                    centerX: progressShape.cX
                    centerY: progressShape.cY
                }
            }

            // Active Track
            ShapePath {
                fillColor: "transparent"
                strokeColor: progressShape.ringAccent
                strokeWidth: progressShape.strokeW
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    startAngle: -90
                    sweepAngle: Math.max(0.1, 360 * progressShape.animVal)
                    radiusX: progressShape.arcR
                    radiusY: progressShape.arcR
                    centerX: progressShape.cX
                    centerY: progressShape.cY
                }

                Behavior on strokeColor {
                    CAnim {
                        duration: Tokens.anim.durations.expressiveFastEffects
                    }
                }
            }
        }

        // Center Material Icon (Larger size & smooth crossfade)
        MaterialIcon {
            id: centerIcon
            anchors.centerIn: parent
            iconPointSize: Tokens.font.size.large
            fill: 1

            text: {
                if (root.activeMetric === "brightness") {
                    const b = (root.monitor && typeof root.monitor.brightness === "number") ? root.monitor.brightness : 0;
                    return `brightness_${Math.max(1, Math.min(7, Math.round(b * 6) + 1))}`;
                } else if (root.activeMetric === "mic") {
                    return Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted);
                } else {
                    return Icons.getVolumeIcon(Audio.volume, Audio.muted);
                }
            }

            color: {
                if (root.activeMetric === "brightness") {
                    return Colours.light ? Colours.palette.m3onSurface : Colours.palette.m3tertiary;
                } else if (root.activeMetric === "mic") {
                    return Audio.sourceMuted ? Colours.palette.m3error : (Colours.light ? Colours.palette.m3onSurface : Colours.palette.m3secondary);
                } else {
                    return Audio.muted ? Colours.palette.m3error : (Colours.light ? Colours.palette.m3onSurface : Colours.palette.m3primary);
                }
            }

            opacity: root.showPercentage ? 0 : 1
            scale: root.showPercentage ? 0.65 : 1.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.anim.durations.expressiveFastEffects
                    easing: Tokens.anim.emphasizedDecel
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Tokens.anim.durations.expressiveFastEffects
                    easing: Tokens.anim.emphasizedDecel
                }
            }

            Behavior on color {
                CAnim {
                    duration: Tokens.anim.durations.expressiveFastEffects
                }
            }
        }

        // Live Value Number Indicator (shown on value change, returning to icon after timeout)
        StyledText {
            id: percentText
            anchors.centerIn: parent
            text: {
                if (root.activeMetric === "mic" && Audio.sourceMuted)
                    return "0";
                if (root.activeMetric === "volume" && Audio.muted)
                    return "0";
                return String(root.percentVal);
            }
            textPointSize: Tokens.font.size.normal
            font.weight: 700
            font.letterSpacing: -0.3
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            color: {
                if (root.activeMetric === "brightness") {
                    return Colours.light ? Colours.palette.m3onSurface : Colours.palette.m3tertiary;
                } else if (root.activeMetric === "mic") {
                    return Audio.sourceMuted ? Colours.palette.m3error : (Colours.light ? Colours.palette.m3onSurface : Colours.palette.m3secondary);
                } else {
                    return Audio.muted ? Colours.palette.m3error : (Colours.light ? Colours.palette.m3onSurface : Colours.palette.m3primary);
                }
            }

            opacity: root.showPercentage ? 1 : 0
            scale: root.showPercentage ? 1.0 : 0.65
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.anim.durations.expressiveFastEffects
                    easing: Tokens.anim.emphasizedDecel
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Tokens.anim.durations.expressiveFastEffects
                    easing: Tokens.anim.emphasizedDecel
                }
            }

            Behavior on color {
                CAnim {
                    duration: Tokens.anim.durations.expressiveFastEffects
                }
            }
        }
    }

    // Interaction MouseArea (active on bar circle area during resting & in-flight transitions)
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        z: 10

        onEntered: {
            root.isHovered = true;
        }
        onExited: {
            root.isHovered = false;
            if (root.isAutoRevealed)
                autoHideTimer.restart();
        }

        onClicked: mouse => {
            mouse.accepted = true;
            root.expand();
        }

        onWheel: event => {
            event.accepted = true;
            if (root.activeMetric === "brightness") {
                if (root.monitor) {
                    const curB = typeof root.monitor.brightness === "number" ? root.monitor.brightness : 0;
                    if (event.angleDelta.y > 0)
                        root.monitor.setBrightness(Math.min(1.0, curB + GlobalConfig.services.brightnessIncrement));
                    else if (event.angleDelta.y < 0)
                        root.monitor.setBrightness(Math.max(0, curB - GlobalConfig.services.brightnessIncrement));
                }
                root.triggerReveal("brightness", true);
            } else {
                if (event.angleDelta.y > 0)
                    Audio.incrementVolume();
                else if (event.angleDelta.y < 0)
                    Audio.decrementVolume();
                root.triggerReveal("volume", true);
            }
        }
    }
}
