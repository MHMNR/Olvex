import QtQuick

Item {
    id: root

    property color color: (typeof Colours !== "undefined" && Colours && Colours.palette) ? Colours.palette.m3onSurface : "#ffffff"
    property real brightness: 0.75  // 0.0 to 1.0
    property alias level: root.brightness
    property real size: 24

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    // Perfectly synchronized smooth brightness value
    property real smoothBrightness: brightness
    Behavior on smoothBrightness {
        NumberAnimation {
            duration: 320
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.34, 1.56, 0.64, 1.0] // Spring physics curve
        }
    }

    // Rotation is locked directly to smoothBrightness for 100% synchronized motion
    readonly property real rotationAngle: smoothBrightness * 180.0

    onSmoothBrightnessChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()

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

            var s = width / 24.0;
            ctx.scale(s, s);

            var b = Math.min(1.0, Math.max(0.0, root.smoothBrightness));
            var cx = 12.0;
            var cy = 12.0;

            ctx.fillStyle = root.color;
            ctx.strokeStyle = root.color;
            ctx.lineWidth = 1.8;
            ctx.lineCap = "round";

            // ══════════════════════════════════════════════════════════
            // ── 1. CENTER SUN CORE (grows synchronously 2.8px -> 5.2px)
            // ══════════════════════════════════════════════════════════
            var coreR = 2.8 + b * 2.4;
            ctx.beginPath();
            ctx.arc(cx, cy, coreR, 0, Math.PI * 2);
            ctx.fill();

            // ══════════════════════════════════════════════════════════
            // ── 2. 8 EXPANDING RAYS (spin & grow simultaneously) ─────
            // ══════════════════════════════════════════════════════════
            if (b > 0.05) {
                var rayInner = coreR + 1.8;
                var rayLen = 0.8 + b * 3.2;
                var rayOuter = rayInner + rayLen;
                var rad = root.rotationAngle * Math.PI / 180.0;

                ctx.save();
                ctx.translate(cx, cy);
                ctx.rotate(rad);

                for (var i = 0; i < 8; i++) {
                    var angle = (i * Math.PI / 4.0);
                    var cosA = Math.cos(angle);
                    var sinA = Math.sin(angle);

                    ctx.beginPath();
                    ctx.moveTo(cosA * rayInner, sinA * rayInner);
                    ctx.lineTo(cosA * rayOuter, sinA * rayOuter);
                    ctx.stroke();
                }

                ctx.restore();
            }
        }
    }
}
