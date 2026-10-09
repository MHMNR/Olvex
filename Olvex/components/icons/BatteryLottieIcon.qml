import QtQuick

Item {
    id: root

    property color color: (typeof Colours !== "undefined" && Colours && Colours.palette) ? Colours.palette.m3onSurface : "#ffffff"
    property real level: 0.85       // 0.0 to 1.0
    property bool charging: false   // true = animated charging bolt
    property bool lowPowerMode: false
    property bool vertical: true    // true = vertical capsule (top terminal), false = horizontal
    property real size: 20

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    // Smooth level animation
    property real smoothLevel: level
    Behavior on smoothLevel {
        NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 1.0, 0.5, 1.0] }
    }

    // Dynamic color based on level & state
    readonly property color fillColor: {
        if (charging) return "#22c55e"; // Green
        if (lowPowerMode) return "#eab308"; // Yellow
        if (smoothLevel <= 0.20) return "#ef4444"; // Red
        return root.color;
    }

    onSmoothLevelChanged: canvas.requestPaint()
    onChargingChanged: canvas.requestPaint()
    onLowPowerModeChanged: canvas.requestPaint()
    onFillColorChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onVerticalChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
    onVisibleChanged: if (visible) canvas.requestPaint()
    Component.onCompleted: canvas.requestPaint()

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

            // Robust cross-platform rounded rectangle helper
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

            var s = Math.min(width, height) / 24.0;
            ctx.scale(s, s);

            if (root.vertical) {
                // Exact Symmetrical 24x24 optical grid — Center at (12.0, 12.0)
                var bodyW = 12.4;
                var bodyH = 17.2;
                var bodyX = (24.0 - bodyW) / 2.0; // 5.8
                var bodyY = 4.4;
                var bodyR = 3.6;

                // 1. Soft track background capsule (No harsh outline)
                ctx.fillStyle = Qt.alpha(root.color, 0.18);
                drawRoundRect(ctx, bodyX, bodyY, bodyW, bodyH, bodyR);
                ctx.fill();

                // 2. Terminal Cap on Top (Symmetrically centered at x=12.0)
                var capW = 5.4;
                var capH = 1.8;
                var capX = (24.0 - capW) / 2.0; // 9.3
                var capY = bodyY - capH - 0.4;   // 2.2 (top=2.2, bottom=21.6, center=11.9)

                ctx.fillStyle = Qt.alpha(root.color, 0.55);
                drawRoundRect(ctx, capX, capY, capW, capH, 0.9);
                ctx.fill();

                // 3. Fluid Fill (seamlessly fills capsule from bottom to top)
                var fillH = Math.max(1.8, bodyH * Math.min(1.0, Math.max(0.0, root.smoothLevel)));
                var fillY = (bodyY + bodyH) - fillH;

                ctx.save();
                drawRoundRect(ctx, bodyX, bodyY, bodyW, bodyH, bodyR);
                ctx.clip();

                ctx.fillStyle = root.fillColor;
                ctx.fillRect(bodyX, fillY, bodyW, fillH);
                ctx.restore();

                // 4. Charging Bolt (Exact Symmetrical Center at x=12.0)
                if (root.charging) {
                    var boltCenterX = 12.0;
                    var boltCenterY = bodyY + bodyH / 2.0; // 13.0

                    ctx.save();
                    ctx.translate(boltCenterX, boltCenterY);
                    ctx.fillStyle = "#ffffff";
                    ctx.beginPath();
                    ctx.moveTo(0.5, -4.5);
                    ctx.lineTo(-2.6, 0.2);
                    ctx.lineTo(-0.2, 0.2);
                    ctx.lineTo(-0.6, 4.5);
                    ctx.lineTo(2.6, -0.2);
                    ctx.lineTo(0.2, -0.2);
                    ctx.closePath();
                    ctx.fill();
                    ctx.restore();
                }
            } else {
                var sh = height / 24.0;
                ctx.scale(sh, sh);

                var hBodyX = 2.0;
                var hBodyY = 5.0;
                var hBodyW = 24.0;
                var hBodyH = 14.0;
                var hBodyR = 4.5;

                // Outer Shell
                ctx.strokeStyle = root.color;
                ctx.lineWidth = 1.8;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";

                drawRoundRect(ctx, hBodyX, hBodyY, hBodyW, hBodyH, hBodyR);
                ctx.stroke();

                // Terminal Cap on Right
                var hCapX = hBodyX + hBodyW + 1.2;
                var hCapY = hBodyY + 4.0;
                var hCapW = 1.8;
                var hCapH = 6.0;

                ctx.fillStyle = Qt.rgba(root.color.r, root.color.g, root.color.b, 0.65);
                drawRoundRect(ctx, hCapX, hCapY, hCapW, hCapH, 1.0);
                ctx.fill();

                // Internal Fluid Fill
                var hFillMargin = 2.6;
                var hMaxFillW = hBodyW - hFillMargin * 2;
                var hFillW = Math.max(2.0, hMaxFillW * Math.min(1.0, Math.max(0.0, root.smoothLevel)));
                var hFillH = hBodyH - hFillMargin * 2;
                var hFillR = 2.4;

                ctx.fillStyle = root.fillColor;
                drawRoundRect(ctx, hBodyX + hFillMargin, hBodyY + hFillMargin, hFillW, hFillH, hFillR);
                ctx.fill();

                // Charging Bolt
                if (root.charging) {
                    var hBoltCenterX = hBodyX + hBodyW / 2.0;
                    var hBoltCenterY = hBodyY + hBodyH / 2.0;

                    ctx.save();
                    ctx.globalCompositeOperation = "destination-out";
                    ctx.fillStyle = "#000000";
                    ctx.beginPath();
                    ctx.arc(hBoltCenterX, hBoltCenterY, 5.0, 0, Math.PI * 2);
                    ctx.fill();
                    ctx.restore();

                    ctx.save();
                    ctx.translate(hBoltCenterX, hBoltCenterY);
                    ctx.fillStyle = "#ffffff";
                    ctx.beginPath();
                    ctx.moveTo(0.5, -4.8);
                    ctx.lineTo(-2.8, 0.2);
                    ctx.lineTo(-0.2, 0.2);
                    ctx.lineTo(-0.8, 4.8);
                    ctx.lineTo(2.8, -0.2);
                    ctx.lineTo(0.2, -0.2);
                    ctx.closePath();
                    ctx.fill();
                    ctx.restore();
                }
            }
        }
    }
}
