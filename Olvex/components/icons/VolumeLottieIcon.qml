import QtQuick

Item {
    id: root

    property color color: (typeof Colours !== "undefined" && Colours && Colours.palette) ? Colours.palette.m3onSurface : "#ffffff"
    property color activeMutedColor: "#ff4d4f" // HyperOS 3 coral red
    property real volumeLevel: 0.85 // 0.0 to 1.0
    property alias volume: root.volumeLevel
    property alias level: root.volumeLevel
    property bool muted: false      // false = Sound Active (#FFFFFF), true = Muted (Red + Knockout Slash)
    property real size: 24
    property real animDuration: 300 // 30 frames @ 30fps from JSON

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    // Frame controller: 0.0 (unmuted active) to 30.0 (muted with slash)
    property real currentFrame: muted ? 30.0 : 0.0

    onMutedChanged: {
        if (muted) {
            unmuteAnim.stop();
            muteAnim.restart();
            shakeDelayTimer.restart();
        } else {
            muteAnim.stop();
            unmuteAnim.restart();
        }
    }

    // Mute Transition: 0 -> 30 frames (Waves collapse t=0..14, Slash draws t=14..29, Speaker shifts)
    NumberAnimation {
        id: muteAnim
        target: root
        property: "currentFrame"
        from: 0.0
        to: 30.0
        duration: root.animDuration
        easing.type: Easing.Linear
    }

    // Unmute Transition: 30 -> 0 frames in reverse
    NumberAnimation {
        id: unmuteAnim
        target: root
        property: "currentFrame"
        to: 0.0
        duration: 240
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.25, 1.0, 0.5, 1.0]
    }

    // Haptic Micro-Shake on Slash Finish
    Timer {
        id: shakeDelayTimer
        interval: 240
        onTriggered: hapticMicroShake.restart()
    }

    SequentialAnimation {
        id: hapticMicroShake
        NumberAnimation { target: iconContainer; property: "x"; to: -2; duration: 18; easing.type: Easing.OutQuad }
        NumberAnimation { target: iconContainer; property: "x"; to: 2; duration: 20; easing.type: Easing.InOutQuad }
        NumberAnimation { target: iconContainer; property: "x"; to: -1.5; duration: 18; easing.type: Easing.InOutQuad }
        NumberAnimation { target: iconContainer; property: "x"; to: 1.5; duration: 16; easing.type: Easing.InOutQuad }
        NumberAnimation { target: iconContainer; property: "x"; to: -1.0; duration: 14; easing.type: Easing.InOutQuad }
        NumberAnimation { target: iconContainer; property: "x"; to: 0; duration: 14; easing.type: Easing.OutQuad }
    }

    onCurrentFrameChanged: canvas.requestPaint()
    onVolumeLevelChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onActiveMutedColorChanged: canvas.requestPaint()

    Item {
        id: iconContainer
        anchors.fill: parent

        Canvas {
            id: canvas
            anchors.fill: parent
            antialiasing: true
            renderTarget: Canvas.Image
            renderStrategy: Canvas.Immediate

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.clearRect(0, 0, width, height);

                // Normalized 24.0 x 24.0 ViewBox matching all system icons
                var s = width / 24.0;
                ctx.scale(s, s);

                var f = root.currentFrame;
                var curColor = root.muted ? root.activeMutedColor : root.color;
                ctx.fillStyle = curColor;
                ctx.strokeStyle = curColor;
                ctx.lineWidth = 1.9;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";

                // ── 1D Cubic Bezier Interpolation Helper ──
                function evalBezier(x1, y1, x2, y2, t) {
                    var u = 1 - t;
                    return 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t;
                }

                // Speaker Cone X Shift: shifts right by +2px on mute (from JSON layer p: [16,16] -> [21,16] scaled)
                var shiftT = Math.max(0.0, Math.min(1.0, f / 20.0));
                var shiftX = evalBezier(0.5, 0.0, 0.491, 1.0, shiftT) * 3.0;

                // Global transform centering the volume in 24x24
                ctx.save();
                ctx.translate(12.0, 12.0);
                ctx.scale(0.85, 0.85);
                ctx.translate(-16.0, -16.0);

                // ══════════════════════════════════════════════════════════
                // ── 1. EXACT SPEAKER CONE FROM JSON (Layer 4) ────────────
                // ══════════════════════════════════════════════════════════
                ctx.save();
                ctx.translate(shiftX, 0);

                ctx.save();
                ctx.translate(10.5, 16.0); // Speaker cone center offset from JSON

                ctx.beginPath();
                // Vertices from JSON:
                // [[4.5, -7], [-0.5, -3], [-4.5, -3], [-4.5, 3], [-0.5, 3], [4.5, 7]]
                ctx.moveTo(4.5, -7);
                ctx.lineTo(-0.5, -3);
                ctx.lineTo(-4.5, -3);
                ctx.lineTo(-4.5, 3);
                ctx.lineTo(-0.5, 3);
                ctx.lineTo(4.5, 7);
                ctx.closePath();
                ctx.fill();
                ctx.stroke();
                ctx.restore();

                // ══════════════════════════════════════════════════════════
                // ── 2. EXACT SOUND WAVES (Layers 2 & 3) ──────────────────
                // ══════════════════════════════════════════════════════════
                // Wave 1: collapses from frame 7 to 14
                var wave1T = (f <= 7.0) ? 1.0 : (f >= 14.0 ? 0.0 : 1.0 - (f - 7.0) / 7.0);
                if (wave1T > 0.01 && root.volumeLevel > 0.15) {
                    ctx.save();
                    ctx.translate(23.257, 16.0); // Wave 1 center offset from JSON
                    ctx.scale(wave1T, wave1T);
                    ctx.beginPath();
                    // Path: [[-3.717, -3.54], [-3.717, 3.53]] with tangent 1.952
                    ctx.moveTo(-3.717, -3.54);
                    ctx.bezierCurveTo(-3.717 + 1.952, -3.54 + 1.953, -3.717 + 1.952, 3.53 - 1.953, -3.717, 3.53);
                    ctx.stroke();
                    ctx.restore();
                }

                // Wave 2: collapses from frame 0 to 7
                var wave2T = (f <= 0.0) ? 1.0 : (f >= 7.0 ? 0.0 : 1.0 - f / 7.0);
                if (wave2T > 0.01 && root.volumeLevel > 0.55) {
                    ctx.save();
                    ctx.translate(23.257, 16.0); // Wave 2 center offset from JSON
                    ctx.scale(wave2T, wave2T);
                    ctx.beginPath();
                    // Path: [[-0.187, -7.07], [-0.187, 7.07]] with tangent 3.904
                    ctx.moveTo(-0.187, -7.07);
                    ctx.bezierCurveTo(-0.187 + 3.904, -7.07 + 3.905, -0.187 + 3.904, 7.07 - 3.905, -0.187, 7.07);
                    ctx.stroke();
                    ctx.restore();
                }

                ctx.restore(); // end speaker shift
                ctx.restore(); // end global transform

                // ══════════════════════════════════════════════════════════
                // ── 3. EXACT TRIM-PATH SLASH WITH KNOCKOUT CHANNEL ───────
                // ══════════════════════════════════════════════════════════
                // Slash draws in from frame 14 to 29
                if (f > 14.0) {
                    var rawSlashT = Math.min(1.0, (f - 14.0) / 15.0);
                    var easedSlashT = evalBezier(0.588, 0.0, 0.223, 1.0, rawSlashT);

                    var x1 = 3.5;
                    var y1 = 3.5;
                    var fullTargetX = 20.5;
                    var fullTargetY = 20.5;

                    var endX = x1 + (fullTargetX - x1) * easedSlashT;
                    var endY = y1 + (fullTargetY - y1) * easedSlashT;

                    // Knockout Mask: Erases clean blank margin through speaker cone
                    ctx.save();
                    ctx.globalCompositeOperation = "destination-out";
                    ctx.lineWidth = 4.2;
                    ctx.beginPath();
                    ctx.moveTo(x1, y1);
                    ctx.lineTo(endX, endY);
                    ctx.stroke();
                    ctx.restore();

                    // Solid Red Slash Stroke
                    ctx.save();
                    ctx.strokeStyle = root.activeMutedColor;
                    ctx.lineWidth = 2.0;
                    ctx.beginPath();
                    ctx.moveTo(x1, y1);
                    ctx.lineTo(endX, endY);
                    ctx.stroke();
                    ctx.restore();
                }
            }
        }
    }
}
