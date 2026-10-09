import QtQuick

Item {
    id: root

    property color color: (typeof Colours !== "undefined" && Colours && Colours.palette) ? Colours.palette.m3onSurface : "#ffffff"
    property color disabledColor: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.28)
    property bool connected: true   // true = active/on, false = disabled/off
    property alias adapterEnabled: root.connected
    property bool deviceConnected: false // true = device(s) connected
    property alias hasConnectedDevice: root.deviceConnected

    property real size: 24
    property real animDuration: 550

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    // Exact Trim Path Controller: 0.0 to 1.0
    property real trimProgress: connected ? 1.0 : 0.0
    property real dotProgress: (connected && deviceConnected) ? 1.0 : 0.0

    onConnectedChanged: {
        if (connected) {
            collapseAnim.stop();
            playTrimAnim.restart();
        } else {
            playTrimAnim.stop();
            collapseAnim.restart();
        }
    }

    onDeviceConnectedChanged: {
        if (connected && deviceConnected) {
            dotDisappearAnim.stop();
            dotAppearAnim.restart();
        } else {
            dotAppearAnim.stop();
            dotDisappearAnim.restart();
        }
    }

    NumberAnimation {
        id: playTrimAnim
        target: root
        property: "trimProgress"
        from: 0.0
        to: 1.0
        duration: root.animDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.38, 1.21, 0.22, 1.0]
    }

    NumberAnimation {
        id: collapseAnim
        target: root
        property: "trimProgress"
        to: 0.0
        duration: 220
        easing.type: Easing.OutQuad
    }

    NumberAnimation {
        id: dotAppearAnim
        target: root
        property: "dotProgress"
        from: 0.0
        to: 1.0
        duration: 320
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.34, 1.56, 0.64, 1.0]
    }

    NumberAnimation {
        id: dotDisappearAnim
        target: root
        property: "dotProgress"
        to: 0.0
        duration: 180
        easing.type: Easing.OutQuad
    }

    onTrimProgressChanged: canvas.requestPaint()
    onDotProgressChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onDisabledColorChanged: canvas.requestPaint()
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

            var s = width / 24.0;
            ctx.scale(s, s);
            ctx.lineWidth = 1.95;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";

            // Normalized 24x24 optical grid - exact symmetrical center at x=12.0, y=12.0
            var pts = [
                { x: 7.5,  y: 7.5 },
                { x: 16.5, y: 16.5 },
                { x: 12.0, y: 20.5 },
                { x: 12.0, y: 3.5 },
                { x: 16.5, y: 7.5 },
                { x: 7.5,  y: 16.5 }
            ];

            // ── 1. ALWAYS VISIBLE DISABLED BASELINE ──
            ctx.strokeStyle = root.disabledColor;
            ctx.beginPath();
            ctx.moveTo(pts[0].x, pts[0].y);
            for (var k = 1; k < pts.length; k++) {
                ctx.lineTo(pts[k].x, pts[k].y);
            }
            ctx.stroke();

            // ── 2. ACTIVE DYNAMIC LOTTIE TRIM-PATH ILLUMINATION LAYER ──
            var trim = root.trimProgress;
            if (trim <= 0.001) return;

            ctx.strokeStyle = root.color;

            // Segment lengths
            var segLengths = [];
            var totalLen = 0;
            for (var i = 0; i < pts.length - 1; i++) {
                var dx = pts[i + 1].x - pts[i].x;
                var dy = pts[i + 1].y - pts[i].y;
                var len = Math.sqrt(dx * dx + dy * dy);
                segLengths.push(len);
                totalLen += len;
            }

            var currentTargetLen = totalLen * trim;
            var accumulated = 0;

            ctx.beginPath();
            ctx.moveTo(pts[0].x, pts[0].y);

            for (var j = 0; j < segLengths.length; j++) {
                var sLen = segLengths[j];
                if (accumulated + sLen <= currentTargetLen) {
                    ctx.lineTo(pts[j + 1].x, pts[j + 1].y);
                    accumulated += sLen;
                } else {
                    var remaining = currentTargetLen - accumulated;
                    var ratio = remaining / sLen;
                    var endX = pts[j].x + (pts[j + 1].x - pts[j].x) * ratio;
                    var endY = pts[j].y + (pts[j + 1].y - pts[j].y) * ratio;
                    ctx.lineTo(endX, endY);
                    break;
                }
            }
            ctx.stroke();

            // ── 3. CONNECTED STATE INDICATOR NODES ──
            var dp = root.dotProgress;
            if (dp > 0.001) {
                ctx.fillStyle = root.color;
                var dotR = 1.65 * Math.min(1.0, dp);

                // Left node
                ctx.beginPath();
                ctx.arc(3.6, 12.0, dotR, 0, Math.PI * 2);
                ctx.fill();

                // Right node
                ctx.beginPath();
                ctx.arc(20.4, 12.0, dotR, 0, Math.PI * 2);
                ctx.fill();
            }
        }
    }
}
