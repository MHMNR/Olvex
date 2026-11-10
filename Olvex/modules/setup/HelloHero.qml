import QtQuick
import Olvex.Config
import qs.components
import qs.services

// Step 0: Authentic macOS multi-language "hello" cursive calligraphy animation.
// Uses Apple's official SF-Hello ("Macintosh 3D") vector strokes across 12 languages
// with arc-length parameterized De Casteljau Bezier trimming for zero-stutter continuous flow.
Item {
    id: root

    signal requestAdvance

    property bool active: true
    property int langIndex: 0
    readonly property var currentGreeting: greetingsData.items[root.langIndex]

    property real drawProgress: 0.0
    property real scriptOpacity: 1.0
    property real heroScale: 1.0
    property real subtitleOpacity: 0.0
    property real subtitleOffset: 8.0

    HelloGreetings {
        id: greetingsData
    }

    onDrawProgressChanged: {
        if (helloCanvas.available)
            helloCanvas.requestPaint();
    }

    onLangIndexChanged: {
        if (helloCanvas.available)
            helloCanvas.requestPaint();
    }

    SequentialAnimation {
        id: cycleAnim

        running: root.active
        loops: Animation.Infinite

        // Phase 0: Reset state for current language
        ScriptAction {
            script: {
                root.drawProgress = 0.0;
                root.subtitleOpacity = 0.0;
                root.subtitleOffset = 8.0;
                root.heroScale = 0.975;
                root.scriptOpacity = 1.0;
                if (helloCanvas.available)
                    helloCanvas.requestPaint();
            }
        }

        PauseAnimation {
            duration: 200
        }

        // Phase 1: Continuous arc-length handwriting stroke
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "heroScale"
                from: 0.975
                to: 1.0
                duration: root.currentGreeting.duration
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: root
                property: "drawProgress"
                from: 0.0
                to: 1.0
                duration: root.currentGreeting.duration
                easing.type: Easing.InOutSine
            }

            SequentialAnimation {
                PauseAnimation {
                    duration: Math.round(root.currentGreeting.duration * 0.68)
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: root
                        property: "subtitleOpacity"
                        from: 0.0
                        to: 1.0
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: root
                        property: "subtitleOffset"
                        from: 8.0
                        to: 0.0
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        // Phase 2: Hold completed calligraphy
        PauseAnimation {
            duration: 1900
        }

        // Phase 3: Smooth macOS dissolve out before next language
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "scriptOpacity"
                to: 0.0
                duration: 450
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: root
                property: "subtitleOpacity"
                to: 0.0
                duration: 360
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: root
                property: "heroScale"
                to: 1.02
                duration: 450
                easing.type: Easing.InCubic
            }
        }

        // Phase 4: Advance to next language in cycle
        ScriptAction {
            script: {
                root.langIndex = (root.langIndex + 1) % greetingsData.items.length;
            }
        }

        PauseAnimation {
            duration: 160
        }
    }

    Item {
        id: stageContainer

        anchors.fill: parent
        opacity: root.scriptOpacity
        scale: root.heroScale

        Canvas {
            id: helloCanvas

            readonly property real vbW: 1000.0
            readonly property real vbH: 340.0

            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.135)
            width: 600
            height: 204
            antialiasing: true
            renderTarget: Canvas.FramebufferObject

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();

                var g = root.currentGreeting;
                if (!g)
                    return;

                var s = width / vbW;
                ctx.scale(s, s);

                var grad = ctx.createLinearGradient(80, 40, 920, 300);
                grad.addColorStop(0.0, Colours.palette.m3primary);
                grad.addColorStop(0.5, Colours.palette.m3secondary);
                grad.addColorStop(1.0, Colours.palette.m3tertiary);

                ctx.strokeStyle = grad;
                ctx.lineWidth = g.lineWidth;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";

                var targetDist = root.drawProgress * g.totalLen;
                if (targetDist <= 0.01)
                    return;

                var strokes = g.strokes;
                for (var si = 0; si < strokes.length; ++si) {
                    var st = strokes[si];
                    if (targetDist <= st.startDist)
                        break;

                    if (st.isDot) {
                        var dotProg = Math.min(1.0, (targetDist - st.startDist) / Math.max(1.0, st.endDist - st.startDist));
                        ctx.save();
                        ctx.lineWidth = g.lineWidth * dotProg;
                        ctx.beginPath();
                        ctx.moveTo(st.x0, st.y0);
                        ctx.lineTo(st.x0 + 0.01, st.y0);
                        ctx.stroke();
                        ctx.restore();
                        continue;
                    }

                    ctx.beginPath();
                    ctx.moveTo(st.x0, st.y0);

                    var curDist = st.startDist;
                    var segs = st.segs;
                    for (var i = 0; i < segs.length; ++i) {
                        var seg = segs[i];
                        var segLen = seg[8];
                        if (targetDist >= curDist + segLen) {
                            ctx.bezierCurveTo(seg[2], seg[3], seg[4], seg[5], seg[6], seg[7]);
                            curDist += segLen;
                        } else {
                            var f = (targetDist - curDist) / segLen;
                            if (f > 0.0001) {
                                var th = seg[9];
                                var u = f * ((4.0 * th - 1.0) + (2.0 - 4.0 * th) * f);
                                u = Math.max(0.0, Math.min(1.0, u));

                                var x0 = seg[0], y0 = seg[1];
                                var x1 = seg[2], y1 = seg[3];
                                var x2 = seg[4], y2 = seg[5];
                                var x3 = seg[6], y3 = seg[7];

                                var q1x = x0 + (x1 - x0) * u;
                                var q1y = y0 + (y1 - y0) * u;
                                var r1x = x1 + (x2 - x1) * u;
                                var r1y = y1 + (y2 - y1) * u;
                                var r2x = x2 + (x3 - x2) * u;
                                var r2y = y2 + (y3 - y2) * u;

                                var q2x = q1x + (r1x - q1x) * u;
                                var q2y = q1y + (r1y - q1y) * u;
                                var s1x = r1x + (r2x - r1x) * u;
                                var s1y = r1y + (r2y - r1y) * u;

                                var q3x = q2x + (s1x - q2x) * u;
                                var q3y = q2y + (s1y - q2y) * u;

                                ctx.bezierCurveTo(q1x, q1y, q2x, q2y, q3x, q3y);
                            }
                            break;
                        }
                    }
                    ctx.stroke();
                }
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: helloCanvas.y + helloCanvas.height + 24 + root.subtitleOffset
            text: root.currentGreeting ? root.currentGreeting.subtitle : qsTr("Welcome to Olvex")
            font.weight: Font.Medium
            textPointSize: Tokens.font.size.large
            color: Colours.palette.m3onSurface
            opacity: root.subtitleOpacity
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: helloCanvas.y + helloCanvas.height + 58 + root.subtitleOffset
            text: qsTr("Let's configure your workspace")
            font.weight: Font.Normal
            textPointSize: Tokens.font.size.small
            color: Colours.palette.m3onSurfaceVariant
            opacity: root.subtitleOpacity * 0.78
        }
    }
}
