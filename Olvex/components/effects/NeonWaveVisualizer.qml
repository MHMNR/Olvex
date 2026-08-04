
import QtQuick
import qs.services

// Canvas-based neon-wave visualizer — restored from backups/Olvex so the media
// pill (and every other music surface) gets the old smooth-wave look AND its
// no-performance-drop behaviour.
//
// Why this doesn't drop system performance (unlike the C++ NeonWaveItem it
// replaces): it is driven by a plain QTimer at `frameInterval` (30–60fps,
// decoupled from the monitor's refresh) and only calls requestPaint() when the
// bar values actually moved. A Timer never puts the window into
// continuous-animation mode, so between ticks — and whenever audio is quiet —
// the compositor/GPU go fully idle. The previous engine used a FrameAnimation
// that re-pinned the whole window to the display's 144Hz refresh for as long as
// music played, which was the source of the drop.
//
// It polls `Audio.cava.values` imperatively each tick (not via the valuesChanged
// signal), so it works regardless of CavaProvider.qmlValuePublishing — values()
// always returns the live buffer.
Canvas {
    id: canvas

    property color accentColor: Colours.palette.m3primary
    property color boostedAccent: Qt.lighter(accentColor, 1.3)
    property int numBands: 32
    property real maxHeightRatio: 0.85
    property real valueMultiplier: 1.5
    property bool active: true
    property int frameInterval: 16

    // How much of the top of the wave fades to transparent (0 = backup look,
    // higher = subtler background wave). Consumed by the gradient below.
    property real topFadeRatio: 0.0

    // Accepted for call-site compatibility with the previous C++ wrapper. This
    // Canvas is always Timer-driven, so there is no per-vsync FrameAnimation to
    // switch off — the property is intentionally inert.
    property bool externallyDriven: false

    // Internal state for smooth animation. Seeded from VisualizerState's
    // cross-surface handoff buffer when available (matching band count) — so a
    // freshly created Canvas (e.g. right after the pill<->card morph transfers
    // ownership) starts from the outgoing surface's last drawn values instead
    // of ramping up from flat rest.
    property var smoothValues: {
        if (VisualizerState.lastBarValues && VisualizerState.lastBarValues.length === numBands)
            return VisualizerState.lastBarValues.slice();
        let arr = [];
        for (let i = 0; i < numBands; i++) {
            arr.push(0.01);
        }
        return arr;
    }

    // Rest height bars ease toward when not active (play → rise off this
    // baseline, pause → fall back to it) — same lowpass as the live values, so
    // both directions animate at the same smooth rate instead of snapping.
    readonly property real restValue: 0.01

    // Restart (not just start) on every transition — pausing needs the timer
    // running too, so it can ease bars down to restValue instead of the old
    // instant snap-to-zero. It self-stops once resting (see onTriggered).
    onActiveChanged: animTimer.restart()
    Component.onCompleted: if (active) animTimer.restart()

    Timer {
        id: animTimer
        interval: canvas.frameInterval
        running: false
        repeat: true
        onTriggered: {
            // Poll live cava buffer directly (see file header) only while
            // active; otherwise ease every band back toward restValue.
            let sourceValues = canvas.active ? Audio.cava.values : null;
            let haveSource = sourceValues && sourceValues.length > 0;

            let arr = canvas.smoothValues;
            let changed = false;
            let resting = true;

            for (let i = 0; i < canvas.numBands; i++) {
                let target = canvas.restValue;
                if (haveSource) {
                    let raw = i < sourceValues.length ? (sourceValues[i] || 0) : 0;
                    target = Math.max(0.01, Math.min(1.0, raw * canvas.valueMultiplier));
                }
                // Move 20% towards target per frame (simple low-pass filter)
                let diff = target - arr[i];
                if (Math.abs(diff) > 0.001) {
                    arr[i] += diff * 0.2;
                    changed = true;
                }
                if (Math.abs(arr[i] - canvas.restValue) > 0.004)
                    resting = false;
            }

            if (changed) {
                canvas.smoothValues = arr;
                canvas.requestPaint();
                // Keep the cross-surface handoff buffer fresh, but only while
                // this Canvas is the genuine active owner — an outgoing,
                // easing-to-rest instance must not overwrite the buffer the
                // new owner just seeded from and is now writing to itself.
                if (canvas.active)
                    VisualizerState.lastBarValues = arr;
            }

            // Fully eased down and inactive — nothing left to animate, stop
            // ticking (keeps this Timer-only design perf-safe at rest).
            if (!canvas.active && resting)
                animTimer.stop();
        }
    }

    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        let n = numBands;
        let vals = smoothValues;
        let w = width;
        let h = height;
        let maxGlowH = h * maxHeightRatio;
        let topFade = Math.max(0.0, Math.min(0.9, topFadeRatio));

        // Helper to get coordinates
        function getCoords(multiplier) {
            let pts = [];
            for (let i = 0; i < n; i++) {
                let x = (i / (n - 1)) * w;
                let y = h - (vals[i] * maxGlowH * multiplier);
                pts.push({x: x, y: y});
            }
            return pts;
        }

        // Draw a pass with given gradient colors and height multiplier
        function drawPass(multiplier, color1, color2, color3) {
            let pts = getCoords(multiplier);
            if (pts.length < 2)
                return;

            ctx.beginPath();
            ctx.moveTo(pts[0].x, pts[0].y);

            // Catmull-Rom to Cubic Bezier
            for (let i = 0; i < n - 1; i++) {
                let p0 = (i === 0) ? pts[0] : pts[i - 1];
                let p1 = pts[i];
                let p2 = pts[i + 1];
                let p3 = (i + 2 === n) ? pts[i + 1] : pts[i + 2];

                // Tension parameter
                let t = 0.2;

                let cp1x = p1.x + (p2.x - p0.x) * t;
                let cp1y = p1.y + (p2.y - p0.y) * t;
                let cp2x = p2.x - (p3.x - p1.x) * t;
                let cp2y = p2.y - (p3.y - p1.y) * t;

                ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y);
            }

            ctx.lineTo(w, h);
            ctx.lineTo(0, h);
            ctx.closePath();

            let grad = ctx.createLinearGradient(0, h, 0, h - (maxGlowH * multiplier));
            // solid = fraction of the height that stays opaque before fading out.
            // topFade === 0 reproduces the backup stops exactly (0 / 0.3 / 0.8 / 1.0).
            let solid = Math.max(0.05, 1.0 - topFade);
            grad.addColorStop(0.0, color1);
            grad.addColorStop(0.3 * solid, color2);
            grad.addColorStop(0.8 * solid, color3);
            grad.addColorStop(solid, "transparent");
            if (solid < 1.0)
                grad.addColorStop(1.0, "transparent");

            ctx.fillStyle = grad;
            ctx.fill();
        }

        // Pass 1: Outer soft glow
        drawPass(1.0,
            Qt.alpha(boostedAccent, 0.8),
            Qt.alpha(boostedAccent, 0.4),
            Qt.alpha(boostedAccent, 0.1)
        );

        // Pass 2: Inner hot core — use accent color, slightly brighter
        drawPass(0.65,
            Qt.alpha(boostedAccent, 0.9),
            Qt.alpha(accentColor, 0.7),
            Qt.alpha(accentColor, 0.15)
        );
    }
}
