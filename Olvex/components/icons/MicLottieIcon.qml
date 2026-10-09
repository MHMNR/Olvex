import QtQuick

Item {
    id: root

    property color color: (typeof Colours !== "undefined" && Colours && Colours.palette) ? Colours.palette.m3onSurface : "#ffffff"
    property color activeMutedColor: "#ff4d4f" // HyperOS 3 coral red
    property bool muted: false      // false = Mic Active (#FFFFFF), true = Mic Muted (Red + Knockout Slash)
    property real inputLevel: 0.0   // 0.0 to 1.0 voice activity intensity
    property alias level: root.inputLevel
    property real size: 24
    property real animDuration: 250 // 25 frames @ 30fps from JSON

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

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
        }
    }

    // JSON Layer 1: Trim Paths 1 (0 -> 100% over 25 frames)
    NumberAnimation {
        id: slashDrawAnim
        target: root
        property: "slashTrimProgress"
        from: 0.0
        to: 1.0
        duration: root.animDuration
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

    // Scale compress (1.0x -> 0.90x -> 1.0x)
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

    // Haptic Micro-Shake on Slash Finish
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

    onSlashTrimProgressChanged: canvas.requestPaint()
    onInputLevelChanged: canvas.requestPaint()
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

                // Global transform centering the mic in 24x24
                ctx.save();
                ctx.translate(12.0, 11.5);
                ctx.scale(0.88, 0.88);
                ctx.translate(-16.0, -16.0);

                // ══════════════════════════════════════════════════════════
                // ── 1. EXACT MIC CAPSULE ─────────────────────────────────
                // ══════════════════════════════════════════════════════════
                ctx.save();
                ctx.translate(16, 12);
                ctx.beginPath();
                ctx.moveTo(0, -7);
                ctx.bezierCurveTo(-1.657, -7, -3, -4 - 1.657, -3, -4);
                ctx.lineTo(-3, 4);
                ctx.bezierCurveTo(-3, 4 + 1.657, -1.657, 7, 0, 7);
                ctx.bezierCurveTo(1.657, 7, 3, 4 + 1.657, 3, 4);
                ctx.lineTo(3, -4);
                ctx.bezierCurveTo(3, -4 - 1.657, 1.657, -7, 0, -7);
                ctx.closePath();
                ctx.fill();
                ctx.stroke();
                ctx.restore();

                // ══════════════════════════════════════════════════════════
                // ── 2. EXACT U-CRADLE ────────────────────────────────────
                // ══════════════════════════════════════════════════════════
                ctx.save();
                ctx.translate(16, 18.5);
                ctx.beginPath();
                ctx.moveTo(7, -4.5);
                ctx.lineTo(7, -2.5);
                ctx.bezierCurveTo(7, -2.5 + 3.866, 0 + 3.866, 4.5, 0, 4.5);
                ctx.bezierCurveTo(0 - 3.866, 4.5, -7, -2.5 + 3.866, -7, -2.5);
                ctx.lineTo(-7, -4.5);
                ctx.stroke();
                ctx.restore();

                // ══════════════════════════════════════════════════════════
                // ── 3. EXACT STEM & BASE STAND ───────────────────────────
                // ══════════════════════════════════════════════════════════
                ctx.save();
                ctx.beginPath();
                ctx.moveTo(16, 23);
                ctx.lineTo(16, 27);
                ctx.moveTo(12, 27);
                ctx.lineTo(20, 27);
                ctx.stroke();
                ctx.restore();

                ctx.restore(); // Restore global center transform

                // ══════════════════════════════════════════════════════════
                // ── 4. EXACT TRIM-PATH SLASH WITH KNOCKOUT CHANNEL ───────
                // ══════════════════════════════════════════════════════════
                var sp = root.slashTrimProgress;
                if (sp > 0.01) {
                    var x1 = 3.5;
                    var y1 = 3.5;
                    var fullTargetX = 20.5;
                    var fullTargetY = 20.5;

                    var endX = x1 + (fullTargetX - x1) * sp;
                    var endY = y1 + (fullTargetY - y1) * sp;

                    // Knockout Mask: Erases blank separation channel through mic
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
