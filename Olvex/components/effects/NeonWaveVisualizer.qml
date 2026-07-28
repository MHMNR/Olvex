pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.utils
import Olvex

Canvas {
    id: canvas

    property color accentColor: Colours.palette.m3primary
    property color boostedAccent: Qt.lighter(accentColor, 1.3)
    property int numBands: 32
    property real maxHeightRatio: 0.85
    property real valueMultiplier: 1.5
    property bool active: true
    property int frameInterval: 16
    property bool decayWhenInactive: true
    readonly property bool settled: maxSmoothValue <= 0.012
    readonly property bool paintingActive: (active || (decayWhenInactive && !settled)) && visible && opacity > 0.001 && width > 0 && height > 0
    readonly property real maxSmoothValue: {
        let maxValue = 0;
        for (let i = 0; i < smoothValues.length; i++)
            maxValue = Math.max(maxValue, smoothValues[i] || 0);
        return maxValue;
    }

    property var smoothValues: {
        let arr = [];
        for (let i = 0; i < numBands; i++)
            arr.push(0.01);
        return arr;
    }

    function resetValues(): void {
        let arr = smoothValues.slice(0, numBands);
        for (let i = 0; i < numBands; i++)
            arr[i] = 0.01;
        smoothValues = arr;
    }

    onPaintingActiveChanged: {
        if (paintingActive) {
            animTimer.start();
        } else {
            animTimer.stop();
        }
    }

    onActiveChanged: {
        if (!active && decayWhenInactive && !settled && visible && opacity > 0.001 && width > 0 && height > 0)
            animTimer.start();
    }

    Timer {
        id: animTimer
        interval: canvas.frameInterval
        running: canvas.paintingActive
        repeat: true
        onTriggered: {
            if (CpuProfile.enabled)
                CpuProfile.bump("neonVizTick");
            const sourceValues = canvas.active ? Audio.cava.values : [];

            const count = canvas.numBands;
            const previous = canvas.smoothValues;
            const arr = previous.slice(0, count);
            let changed = false;

            for (let i = 0; i < count; i++) {
                const current = arr[i] ?? 0.01;
                const hasInput = canvas.active && sourceValues && i < sourceValues.length;
                const target = hasInput
                    ? Math.max(0.01, Math.min(1.0, (sourceValues[i] || 0) * canvas.valueMultiplier))
                    : 0.01;
                const diff = target - current;
                if (Math.abs(diff) > 0.001) {
                    const catchup = Math.abs(diff) > 0.25 ? 0.72 : 0.58;
                    const activeRelease = Math.abs(diff) > 0.25 ? 0.52 : 0.34;
                    const decayRelease = 0.14;
                    arr[i] = current + diff * (hasInput ? (diff > 0 ? catchup : activeRelease) : decayRelease);
                    changed = true;
                } else {
                    arr[i] = target;
                }
            }

            if (changed) {
                canvas.smoothValues = arr;
                if (CpuProfile.enabled)
                    CpuProfile.bump("neonVizPaint");
                canvas.requestPaint();
            }
        }
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        const n = numBands;
        const vals = smoothValues;
        const w = width;
        const h = height;
        const maxGlowH = h * maxHeightRatio;

        function getCoords(multiplier) {
            const pts = [];
            for (let i = 0; i < n; i++) {
                const x = (i / (n - 1)) * w;
                const y = h - (vals[i] * maxGlowH * multiplier);
                pts.push({x: x, y: y});
            }
            return pts;
        }

        function drawPass(multiplier, color1, color2, color3, color4) {
            const pts = getCoords(multiplier);
            if (pts.length < 2)
                return;

            ctx.beginPath();
            ctx.moveTo(pts[0].x, pts[0].y);

            for (let i = 0; i < n - 1; i++) {
                const p0 = (i === 0) ? pts[0] : pts[i - 1];
                const p1 = pts[i];
                const p2 = pts[i + 1];
                const p3 = (i + 2 === n) ? pts[i + 1] : pts[i + 2];
                const t = 0.2;

                const cp1x = p1.x + (p2.x - p0.x) * t;
                const cp1y = p1.y + (p2.y - p0.y) * t;
                const cp2x = p2.x - (p3.x - p1.x) * t;
                const cp2y = p2.y - (p3.y - p1.y) * t;

                ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y);
            }

            ctx.lineTo(w, h);
            ctx.lineTo(0, h);
            ctx.closePath();

            const grad = ctx.createLinearGradient(0, h, 0, h - (maxGlowH * multiplier));
            grad.addColorStop(0.0, color1);
            grad.addColorStop(0.3, color2);
            grad.addColorStop(0.8, color3);
            grad.addColorStop(1.0, color4);

            ctx.fillStyle = grad;
            ctx.fill();
        }

        drawPass(
            1.0,
            Qt.alpha(boostedAccent, 0.8),
            Qt.alpha(boostedAccent, 0.4),
            Qt.alpha(boostedAccent, 0.1),
            "transparent"
        );

        drawPass(
            0.65,
            Qt.alpha(boostedAccent, 0.9),
            Qt.alpha(accentColor, 0.7),
            Qt.alpha(accentColor, 0.15),
            "transparent"
        );
    }
}
