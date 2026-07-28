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

    // Internal state for smooth animation
    property var smoothValues: {
        let arr = [];
        for (let i = 0; i < numBands; i++) {
            arr.push(0.01);
        }
        return arr;
    }

    onActiveChanged: {
        if (active) {
            animTimer.start();
        } else {
            animTimer.stop();
            // Quickly animate down when stopped
            let arr = smoothValues;
            for (let i = 0; i < numBands; i++) {
                arr[i] = 0.01;
            }
            smoothValues = arr;
            canvas.requestPaint();
        }
    }

    Timer {
        id: animTimer
        interval: canvas.frameInterval
        running: canvas.active
        repeat: true
        onTriggered: {
            CpuProfile.bump("neonVizTick");
            // Smoothly interpolate values to prevent jitter
            let sourceValues = Audio.cava.values;
            if (!sourceValues || sourceValues.length === 0) return;
            
            let arr = canvas.smoothValues;
            let changed = false;
            let count = Math.min(sourceValues.length, canvas.numBands);
            
            for (let i = 0; i < count; i++) {
                let target = Math.max(0.01, Math.min(1.0, (sourceValues[i] || 0) * canvas.valueMultiplier));
                // Move 20% towards target per frame (simple low-pass filter)
                let diff = target - arr[i];
                if (Math.abs(diff) > 0.001) {
                    arr[i] += diff * 0.2;
                    changed = true;
                }
            }
            
            if (changed) {
                canvas.smoothValues = arr;
                CpuProfile.bump("neonVizPaint");
                canvas.requestPaint();
            }
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
        function drawPass(multiplier, color1, color2, color3, color4) {
            let pts = getCoords(multiplier);
            if (pts.length < 2) return;
            
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
            grad.addColorStop(0.0, color1);
            grad.addColorStop(0.3, color2);
            grad.addColorStop(0.8, color3);
            grad.addColorStop(1.0, color4);
            
            ctx.fillStyle = grad;
            ctx.fill();
        }

        // Pass 1: Outer soft glow
        drawPass(1.0, 
            Qt.alpha(boostedAccent, 0.8), 
            Qt.alpha(boostedAccent, 0.4), 
            Qt.alpha(boostedAccent, 0.1), 
            "transparent"
        );
        
        // Pass 2: Inner hot core — use accent color, slightly brighter
        drawPass(0.65, 
            Qt.alpha(boostedAccent, 0.9), 
            Qt.alpha(accentColor, 0.7), 
            Qt.alpha(accentColor, 0.15), 
            "transparent"
        );
    }
}
