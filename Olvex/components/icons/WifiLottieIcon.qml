import QtQuick

Item {
    id: root

    property color color: (typeof Colours !== "undefined" && Colours && Colours.palette) ? Colours.palette.m3onSurface : "#ffffff"
    property color disabledColor: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.28)
    property color activeMutedColor: "#ff4d4f"

    property bool wifiEnabled: true         // true = Wi-Fi radio is on, false = Wi-Fi off (shows slash)
    property bool connected: true           // true = connected to access point, false = not connected/idle
    property real signalStrength: 1.0       // 0.0 to 1.0  → controls how many bars light up
    property alias strength: root.signalStrength
    property bool connecting: false          // Scanning radar pulse
    property bool locked: false              // Padlock badge
    property bool saved: false               // Checkmark badge
    property alias tick: root.saved
    property bool disconnected: false        // Disconnected "x" badge
    property bool showSlashOnDisable: true   // Animated 45° slash when Wi-Fi is off (wifiEnabled == false)

    property real size: 24
    property real animDuration: 500
    property real disableDuration: 280

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    // Frame controller: 0.0 (off) → 60.0 (fully revealed)
    property real currentFrame: wifiEnabled ? 60.0 : 0.0
    property real slashTrimProgress: (!wifiEnabled && showSlashOnDisable) ? 1.0 : 0.0

    onWifiEnabledChanged: {
        if (wifiEnabled) {
            slashDrawAnim.stop();
            slashEraseAnim.restart();
            collapseAnim.stop();
            playRevealAnim.restart();
        } else {
            playRevealAnim.stop();
            collapseAnim.restart();
            if (showSlashOnDisable) {
                slashEraseAnim.stop();
                slashDrawAnim.restart();
                shakeDelayTimer.restart();
            }
        }
    }

    onConnectedChanged: canvas.requestPaint()
    onShowSlashOnDisableChanged: {
        if (!showSlashOnDisable) {
            slashDrawAnim.stop();
            slashTrimProgress = 0.0;
        } else if (!wifiEnabled) {
            slashEraseAnim.stop();
            slashDrawAnim.restart();
        }
    }

    NumberAnimation {
        id: playRevealAnim
        target: root
        property: "currentFrame"
        from: 0.0
        to: 60.0
        duration: root.animDuration
        easing.type: Easing.Linear
    }

    NumberAnimation {
        id: collapseAnim
        target: root
        property: "currentFrame"
        to: 0.0
        duration: root.disableDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.25, 1.0, 0.5, 1.0]
    }

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

    Timer {
        id: shakeDelayTimer
        interval: 220
        onTriggered: hapticMicroShake.restart()
    }

    SequentialAnimation {
        id: hapticMicroShake
        NumberAnimation { target: iconContainer; property: "x"; to: -2;   duration: 18; easing.type: Easing.OutQuad }
        NumberAnimation { target: iconContainer; property: "x"; to:  2;   duration: 20; easing.type: Easing.InOutQuad }
        NumberAnimation { target: iconContainer; property: "x"; to: -1.5; duration: 18; easing.type: Easing.InOutQuad }
        NumberAnimation { target: iconContainer; property: "x"; to:  1.5; duration: 16; easing.type: Easing.InOutQuad }
        NumberAnimation { target: iconContainer; property: "x"; to: -1.0; duration: 14; easing.type: Easing.InOutQuad }
        NumberAnimation { target: iconContainer; property: "x"; to:  0;   duration: 14; easing.type: Easing.OutQuad }
    }

    onCurrentFrameChanged:     canvas.requestPaint()
    onSlashTrimProgressChanged: canvas.requestPaint()
    onSignalStrengthChanged:   canvas.requestPaint()
    onColorChanged:            canvas.requestPaint()
    onDisabledColorChanged:    canvas.requestPaint()
    onLockedChanged:           canvas.requestPaint()
    onSavedChanged:            canvas.requestPaint()
    onDisconnectedChanged:     canvas.requestPaint()
    onWidthChanged:            canvas.requestPaint()
    onHeightChanged:           canvas.requestPaint()
    onVisibleChanged:          if (visible) canvas.requestPaint()
    Component.onCompleted:     canvas.requestPaint()

    Item {
        id: iconContainer
        anchors.fill: parent

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

                var s = width / 24.0;
                ctx.scale(s, s);

                // Icon geometry (Plumpy / Icons8 style) - exact center at y=12.0
                var cx       = 12.0;
                var cy       = 17.65;
                var strokeW  = 2.8;
                var dotR     = 2.1;
                var r1       = 6.4;   // inner arc radius
                var r2       = 12.0;  // outer arc radius

                var arcStart = -Math.PI * 0.75;  // -135°
                var arcEnd   = -Math.PI * 0.25;  // -45°
                var zenith   = -Math.PI * 0.5;
                var halfFull =  Math.PI * 0.25;  // half-sweep at full reveal

                // Bezier spring easing matching HyperOS Folme
                function easeSpring(t) {
                    var u = 1 - t;
                    return 3 * u * u * t * 1.56 + 3 * u * t * t * 1.0 + t * t * t;
                }

                var f   = root.currentFrame;  // 0.0 → 60.0
                var str = root.signalStrength; // 0.0 → 1.0

                // ── SIGNAL STRENGTH BRACKETS ──────────────────────────────
                // 3-bar system exactly like HyperOS 3 / iOS:
                //   Dot        always lit when Wi-Fi is on and connected
                //   Inner arc  lit when str > 0.30  (>= ~1 bar)
                //   Outer arc  lit when str > 0.62  (>= ~2 bars)
                var dotLit  = root.wifiEnabled && root.connected;
                var bar1Lit = root.wifiEnabled && root.connected && (str > 0.30);
                var bar2Lit = root.wifiEnabled && root.connected && (str > 0.62);

                // ── REVEAL ANIMATION PROGRESS (staggered) ─────────────────
                // Dot:       frames 0–14
                var dotT    = Math.min(1.0, Math.max(0.0, f        ) / 14.0);
                var dotAnim = Math.max(0.0, easeSpring(dotT));

                // Inner arc: frames 8–36
                var a1T     = Math.min(1.0, Math.max(0.0, f - 8.0 ) / 28.0);
                var a1Anim  = Math.max(0.0, easeSpring(a1T));

                // Outer arc: frames 20–56
                var a2T     = Math.min(1.0, Math.max(0.0, f - 20.0) / 36.0);
                var a2Anim  = Math.max(0.0, easeSpring(a2T));

                // ── DRAW DOT ──────────────────────────────────────────────
                ctx.lineCap  = "round";
                ctx.lineJoin = "round";

                if (dotLit) {
                    ctx.globalAlpha = dotAnim;
                    ctx.fillStyle   = root.color;
                    ctx.beginPath();
                    ctx.arc(cx, cy, dotR * Math.max(0.01, dotAnim), 0, Math.PI * 2);
                    ctx.fill();
                    ctx.globalAlpha = 1.0;
                } else {
                    // Wi-Fi off / disconnected: draw dim dot
                    ctx.fillStyle = root.disabledColor;
                    ctx.beginPath();
                    ctx.arc(cx, cy, dotR, 0, Math.PI * 2);
                    ctx.fill();
                }

                // ── DRAW INNER ARC (BAR 1) ────────────────────────────────
                ctx.lineWidth = strokeW;

                if (bar1Lit) {
                    var hs1 = halfFull * a1Anim;
                    if (hs1 > 0.001) {
                        ctx.globalAlpha = Math.min(1.0, a1Anim);
                        ctx.strokeStyle = root.color;
                        ctx.beginPath();
                        ctx.arc(cx, cy, r1, zenith - hs1, zenith + hs1, false);
                        ctx.stroke();
                        ctx.globalAlpha = 1.0;
                    }
                } else {
                    // Inactive / low-signal bar: full arc at dim color
                    ctx.strokeStyle = root.disabledColor;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r1, arcStart, arcEnd, false);
                    ctx.stroke();
                }

                // ── DRAW OUTER ARC (BAR 2) ────────────────────────────────
                if (bar2Lit) {
                    var hs2 = halfFull * a2Anim;
                    if (hs2 > 0.001) {
                        ctx.globalAlpha = Math.min(1.0, a2Anim);
                        ctx.strokeStyle = root.color;
                        ctx.beginPath();
                        ctx.arc(cx, cy, r2, zenith - hs2, zenith + hs2, false);
                        ctx.stroke();
                        ctx.globalAlpha = 1.0;
                    }
                } else {
                    // Inactive bar
                    ctx.strokeStyle = root.disabledColor;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r2, arcStart, arcEnd, false);
                    ctx.stroke();
                }

                // ── ANIMATED 45° SLASH (Wi-Fi Off state) ─────────────────
                var sp = (!root.wifiEnabled && root.showSlashOnDisable) ? root.slashTrimProgress : 0.0;
                if (sp > 0.01) {
                    var x1 = 4.5,  y1 = 4.5;
                    var x2 = 19.5, y2 = 19.5;
                    var curX = x1 + (x2 - x1) * sp;
                    var curY = y1 + (y2 - y1) * sp;

                    // Knockout separation channel
                    ctx.save();
                    ctx.globalCompositeOperation = "destination-out";
                    ctx.lineWidth = strokeW + 2.4;
                    ctx.beginPath();
                    ctx.moveTo(x1, y1);
                    ctx.lineTo(curX, curY);
                    ctx.stroke();
                    ctx.restore();

                    // Slash stroke
                    ctx.save();
                    ctx.strokeStyle = root.disabledColor;
                    ctx.lineWidth   = strokeW * 0.90;
                    ctx.beginPath();
                    ctx.moveTo(x1, y1);
                    ctx.lineTo(curX, curY);
                    ctx.stroke();
                    ctx.restore();
                }

                // ── BADGES ────────────────────────────────────────────────
                drawBadges(ctx);

                function drawRoundRect(c, x, y, w, h, r) {
                    if (w < 2 * r) r = w / 2;
                    if (h < 2 * r) r = h / 2;
                    c.beginPath();
                    c.moveTo(x + r, y);
                    c.arcTo(x + w, y, x + w, y + h, r);
                    c.arcTo(x + w, y + h, x, y + h, r);
                    c.arcTo(x, y + h, x, y, r);
                    c.arcTo(x, y, x + w, y, r);
                    c.closePath();
                }

                function drawBadges(c) {
                    var bx = 18.0;
                    var by = 15.95;

                    if (root.saved || root.tick) {
                        c.save();
                        c.globalCompositeOperation = "destination-out";
                        c.beginPath();
                        c.arc(bx, by, 4.8, 0, Math.PI * 2);
                        c.fill();
                        c.restore();

                        c.save();
                        c.fillStyle = root.color;
                        c.beginPath();
                        c.arc(bx, by, 3.8, 0, Math.PI * 2);
                        c.fill();

                        c.globalCompositeOperation = "destination-out";
                        c.strokeStyle = "#000000";
                        c.lineWidth   = 1.2;
                        c.lineCap     = "round";
                        c.lineJoin    = "round";
                        c.beginPath();
                        c.moveTo(bx - 1.8, by + 0.1);
                        c.lineTo(bx - 0.4, by + 1.5);
                        c.lineTo(bx + 1.8, by - 1.3);
                        c.stroke();
                        c.restore();
                    } else if (root.locked) {
                        c.save();
                        c.globalCompositeOperation = "destination-out";
                        c.beginPath();
                        c.arc(bx, by - 0.5, 4.5, 0, Math.PI * 2);
                        c.fill();
                        c.restore();

                        c.save();
                        c.fillStyle   = root.color;
                        c.strokeStyle = root.color;
                        c.lineWidth   = 1.2;
                        c.beginPath();
                        c.arc(bx, by - 2.0, 1.8, Math.PI, 0);
                        c.stroke();
                        drawRoundRect(c, bx - 2.4, by - 1.2, 4.8, 4.2, 1.0);
                        c.fill();
                        c.restore();
                    } else if (root.disconnected) {
                        c.save();
                        c.globalCompositeOperation = "destination-out";
                        c.beginPath();
                        c.arc(bx, by, 4.8, 0, Math.PI * 2);
                        c.fill();
                        c.restore();

                        c.save();
                        c.fillStyle = root.color;
                        c.beginPath();
                        c.arc(bx, by, 3.8, 0, Math.PI * 2);
                        c.fill();
                        c.globalCompositeOperation = "destination-out";
                        c.strokeStyle = "#000000";
                        c.lineWidth   = 1.0;
                        c.beginPath();
                        c.moveTo(bx - 1.4, by - 1.4);
                        c.lineTo(bx + 1.4, by + 1.4);
                        c.moveTo(bx + 1.4, by - 1.4);
                        c.lineTo(bx - 1.4, by + 1.4);
                        c.stroke();
                        c.restore();
                    }
                }
            }
        }
    }
}
