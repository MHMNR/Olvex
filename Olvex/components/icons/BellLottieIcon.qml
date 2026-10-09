import QtQuick

Item {
    id: root

    property color color: (typeof Colours !== "undefined" && Colours && Colours.palette) ? Colours.palette.m3onSurface : "#ffffff"
    property color activeMutedColor: "#ff4d4f" // HyperOS 3 coral red
    property bool muted: false      // false = Ringer Active, true = Silent Mode (Slash + Knockout)
    property bool swinging: false   // Ringing swing
    property real size: 24
    property real animDuration: 300

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    // Function to trigger ringing swing animation (from JSON 1)
    function triggerRing() {
        ringKeyframeAnim.restart();
    }

    // ══════════════════════════════════════════════════════════════════
    // ── JSON 1: 50-FRAME DAMPED HARMONIC RINGING SWING ANIMATION ──
    // ══════════════════════════════════════════════════════════════════
    property real ringFrame: 0.0
    NumberAnimation {
        id: ringKeyframeAnim
        target: root
        property: "ringFrame"
        from: 0.0
        to: 50.0
        duration: 800
        easing.type: Easing.Linear
    }

    // ══════════════════════════════════════════════════════════════════
    // ── JSON 2: 25-FRAME TRIM-PATH SLASH & SCALE COMPRESS ANIMATION
    // ══════════════════════════════════════════════════════════════════
    property real slashTrimProgress: muted ? 1.0 : 0.0

    onMutedChanged: {
        if (muted) {
            slashEraseAnim.stop();
            muteScaleCompress.restart();
            slashDrawAnim.restart();
            shakeDelayTimer.restart();
        } else {
            slashDrawAnim.stop();
            slashEraseAnim.restart();
            unmuteExpansion.restart();
            triggerRing();
        }
    }

    // JSON 2 Layer 1: Trim Paths 1 (0 -> 100% over 25 frames)
    NumberAnimation {
        id: slashDrawAnim
        target: root
        property: "slashTrimProgress"
        from: 0.0
        to: 1.0
        duration: 250
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.588, 0.0, 0.223, 1.0]
    }

    NumberAnimation {
        id: slashEraseAnim
        target: root
        property: "slashTrimProgress"
        to: 0.0
        duration: 200
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.25, 1.0, 0.5, 1.0]
    }

    // JSON 2 Layer 2: Scale Compress (100% -> 90% -> 100%)
    SequentialAnimation {
        id: muteScaleCompress
        NumberAnimation { target: iconScale; property: "xScale"; to: 0.90; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: iconScale; property: "yScale"; to: 0.90; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: iconScale; property: "xScale"; to: 1.00; duration: 160; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 1.0, 0.5, 1.0] }
        NumberAnimation { target: iconScale; property: "yScale"; to: 1.00; duration: 160; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 1.0, 0.5, 1.0] }
    }

    // Unmute Expansion Bounce (1.0x -> 1.08x -> 1.0x)
    SequentialAnimation {
        id: unmuteExpansion
        NumberAnimation { target: iconScale; property: "xScale"; to: 1.08; duration: 110; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.34, 1.56, 0.64, 1.0] }
        NumberAnimation { target: iconScale; property: "yScale"; to: 1.08; duration: 110; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.34, 1.56, 0.64, 1.0] }
        NumberAnimation { target: iconScale; property: "xScale"; to: 1.00; duration: 90; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 1.0, 0.5, 1.0] }
        NumberAnimation { target: iconScale; property: "yScale"; to: 1.00; duration: 90; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 1.0, 0.5, 1.0] }
    }

    // Haptic Micro-Shake on Slash Finish (100ms 3-cycle ±2px)
    Timer {
        id: shakeDelayTimer
        interval: 220
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

    onRingFrameChanged: canvas.requestPaint()
    onSlashTrimProgressChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onActiveMutedColorChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
    onVisibleChanged: if (visible) canvas.requestPaint()
    Component.onCompleted: canvas.requestPaint()

    Item {
        id: iconContainer
        anchors.fill: parent
        transform: Scale {
            id: iconScale
            origin.x: iconContainer.width / 2
            origin.y: iconContainer.height / 2
            xScale: 1.0
            yScale: 1.0
        }

        Canvas {
            id: canvas
            anchors.fill: parent
            antialiasing: true
            renderTarget: Canvas.Image
            renderStrategy: Canvas.Immediate

            onAvailableChanged: if (available) requestPaint()
            onWidthChanged: if (available) requestPaint()
            onHeightChanged: if (available) requestPaint()
            Component.onCompleted: if (available) requestPaint()

            onPaint: {
                if (width <= 0 || height <= 0) return;
                var ctx = getContext("2d");
                ctx.reset();
                ctx.clearRect(0, 0, width, height);

                // Normalized 24.0 x 24.0 ViewBox matching all system icons
                var s = width / 24.0;
                ctx.scale(s, s);

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

                function interpRot(kfs, f) {
                    if (f <= kfs[0].t) return kfs[0].v;
                    if (f >= kfs[kfs.length - 1].t) return kfs[kfs.length - 1].v;
                    for (var i = 0; i < kfs.length - 1; i++) {
                        var k0 = kfs[i];
                        var k1 = kfs[i + 1];
                        if (f >= k0.t && f <= k1.t) {
                            var rawT = (f - k0.t) / (k1.t - k0.t);
                            var easedT = evalBezier(k0.ox || 0.7, k0.oy || 0.0, k0.ix || 0.3, k0.iy || 1.0, rawT);
                            return k0.v + (k1.v - k0.v) * easedT;
                        }
                    }
                    return kfs[kfs.length - 1].v;
                }

                // ── JSON 1 Keyframe Tables: Harmonic Bell & Clapper Rotations ──
                var rf = root.ringFrame;
                var bodyKfs = [
                    { t: 0,  v: 0,   ox: 0.7, oy: 0.0, ix: 0.455, iy: 1.0 },
                    { t: 7,  v: 18,  ox: 0.7, oy: 0.0, ix: 0.279, iy: 1.0 },
                    { t: 14, v: -18, ox: 0.7, oy: 0.0, ix: 0.334, iy: 1.0 },
                    { t: 23, v: 18,  ox: 0.7, oy: 0.0, ix: 0.335, iy: 1.0 },
                    { t: 31, v: -9,  ox: 0.7, oy: 0.0, ix: 0.700, iy: 1.0 },
                    { t: 38, v: 5,   ox: 0.3, oy: 0.0, ix: 0.194, iy: 1.0 },
                    { t: 50, v: 0 }
                ];

                var clapperKfs = [
                    { t: 0,      v: 0,     ox: 0.3, oy: 0.0, ix: 0.300, iy: 1.0 },
                    { t: 6.944,  v: -20,   ox: 0.3, oy: 0.0, ix: 0.300, iy: 1.0 },
                    { t: 13.89,  v: 20,    ox: 0.3, oy: 0.0, ix: 0.300, iy: 1.0 },
                    { t: 20.834, v: -20,   ox: 0.3, oy: 0.0, ix: 0.579, iy: 1.0 },
                    { t: 26.0,   v: 9.717, ox: 0.3, oy: 0.0, ix: 0.300, iy: 1.0 },
                    { t: 37.0,   v: -10,   ox: 0.35, oy: 0.0, ix: 0.357, iy: 1.0 },
                    { t: 45.0,   v: 0 }
                ];

                var bodyDeg = (rf > 0.01 && root.slashTrimProgress < 0.1) ? interpRot(bodyKfs, rf) : 0.0;
                var clapperDeg = (rf > 0.01 && root.slashTrimProgress < 0.1) ? interpRot(clapperKfs, rf) : 0.0;

                var bodyRad = bodyDeg * Math.PI / 180.0;
                var clapperRad = clapperDeg * Math.PI / 180.0;

                // ══════════════════════════════════════════════════════════
                // ── 1. EXACT BELL BODY PATH (Normalized to 24x24 optical grid)
                // ══════════════════════════════════════════════════════════
                ctx.save();
                ctx.translate(12.0, 11.0);
                ctx.scale(0.88, 0.88);
                ctx.translate(-15.312, -7.625);
                ctx.rotate(bodyRad);
                ctx.translate(15.312, 7.625);
                ctx.translate(-15.241, -14.145);

                ctx.save();
                ctx.translate(15.241, 14.145);

                ctx.beginPath();
                // Vertices from JSON:
                // P0: [10, 7.5]
                // P1: [-10, 7.5] with o: [1.657, 0]
                // P2: [-7, 4.5] with i: [0, 1.657]
                // P3: [-7, -0.5] with o: [0, -3.866]
                // P4: [0, -7.5] with i: [-3.866, 0], o: [3.866, 0]
                // P5: [7, -0.5] with i: [0, -3.866]
                // P6: [7, 4.5] with i: [0, 1.657]
                ctx.moveTo(10, 7.5);
                ctx.lineTo(-10, 7.5);
                ctx.bezierCurveTo(-10 + 1.657, 7.5, -7, 4.5 + 1.657, -7, 4.5);
                ctx.lineTo(-7, -0.5);
                ctx.bezierCurveTo(-7, -0.5 - 3.866, 0 - 3.866, -7.5, 0, -7.5);
                ctx.bezierCurveTo(0 + 3.866, -7.5, 7, -0.5 - 3.866, 7, -0.5);
                ctx.lineTo(7, 4.5);
                ctx.bezierCurveTo(7, 4.5 + 1.657, 10 - 1.657, 7.5, 10, 7.5);
                ctx.closePath();

                ctx.fill();
                ctx.stroke();
                ctx.restore();

                ctx.restore();

                // ══════════════════════════════════════════════════════════
                // ── 2. EXACT CLAPPER ARC PATH (Normalized to 24x24 optical grid)
                // ══════════════════════════════════════════════════════════
                ctx.save();
                ctx.translate(12.0, 11.0);
                ctx.scale(0.88, 0.88);
                ctx.translate(-15.5, -9.75);
                ctx.rotate(bodyRad + clapperRad);
                ctx.translate(15.5, 9.75);
                ctx.translate(-15.241, -14.145);

                ctx.save();
                ctx.translate(15.241, 23.8);

                ctx.beginPath();
                ctx.arc(0, 0, 2.9, 0, Math.PI, false);
                ctx.closePath();
                ctx.fill();

                ctx.restore();
                ctx.restore();

                // ══════════════════════════════════════════════════════════
                // ── 3. EXACT 45° TRIM SLASH (Centered at 12.0, 12.0) ─────
                // ══════════════════════════════════════════════════════════
                var sp = root.slashTrimProgress;
                if (sp > 0.01) {
                    var x1 = 3.5;
                    var y1 = 3.5;
                    var fullTargetX = 20.5;
                    var fullTargetY = 20.5;

                    var endX = x1 + (fullTargetX - x1) * sp;
                    var endY = y1 + (fullTargetY - y1) * sp;

                    // Knockout Mask: Erases blank separation channel through bell
                    ctx.save();
                    ctx.globalCompositeOperation = "destination-out";
                    ctx.lineWidth = 4.2; // Clean white channel gap
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
