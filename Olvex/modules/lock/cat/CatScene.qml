import QtQuick
import QtQuick.Shapes
import Olvex.Config
import qs.components
import qs.services

// Real-Time 60/144Hz Procedurally Simulated Lockscreen Cat Scene:
// - GPU CurveRenderer Tapered Bezier Forelimb (`armShape`) — matches `FelineLimb` shader style!
// - Outward-Cheek Elbow Arc (Sweeps around the side of the head, NEVER through the mouth/nose)
// - Zero-Vibration Exponential Smoothing Physics & Hysteresis Multi-Side Stalking
Item {
    id: root

    required property var lock
    property string layout: "full"
    property bool running: true

    clip: true
    layer.enabled: peek

    readonly property bool peek: layout === "peek"

    // ── Tunables ────────────────────────────────────────────────────────────
    readonly property int drowsyAfterMs: 40000
    readonly property int sleepAfterMs: 52000
    readonly property real tScale: Tokens.anim.durations.normal > 0 ? Tokens.anim.durations.normal / 400 : 0.01
    function dur(ms) {
        return Math.max(1, Math.round(ms * root.tScale));
    }

    function safeNum(v, fallback) {
        return Number.isFinite(v) ? v : fallback;
    }

    // ── Geometry & Procedural Walk Kinematics ───────────────────────────────
    readonly property real s: Math.max(16, peek ? Math.min(height * 1.1, width * 0.30) : Math.min(height * 0.50, width * 0.34))
    readonly property real headH: s * 0.84
    readonly property real bodyW: s * 1.30
    readonly property real bodyH: s * 0.80

    readonly property real minWalkX: s * 0.12
    readonly property real maxWalkX: Math.max(minWalkX, width - bodyW - s * 0.12)
    property real catWalkX: (width - bodyW) / 2
    property real prevCatWalkX: catWalkX
    property real targetWalkX: catWalkX
    property bool isWalking: false
    property real walkPhase: 0
    property real walkSpeedNorm: 0
    property int walkFacing: 1
    property real facingSmooth: 1.0
    property real spineTurnBend: 0.0
    property real pendingDestX: 0
    property bool pendingIsStalk: false
    property real startleHopY: 0

    // Unconditionally Stable Harmonic Tail Angles
    property real tailJ1: 0
    property real tailJ2: 0
    property real tailJ3: 0
    property real tailClock: 0

    // NaN-Proof Exponentially-Smoothed State for Gaze, Head & Ears
    property real lookXL: 0
    property real lookXR: 0
    property real lookYL: 0
    property real lookYR: 0
    property real headDX: 0
    property real headDY: 0
    property real headTilt: 0
    property real earLs: 0
    property real earRs: 0

    readonly property real lookX: (lookXL + lookXR) * 0.5
    readonly property real lookY: (lookYL + lookYR) * 0.5

    property real standRatio: (isWalking || mood === "walk" || mood === "stalkWalk" || mood === "stretch" || mood === "sitToWalk" || mood === "startle") ? 1.0 : 0.0
    Behavior on standRatio {
        NumberAnimation { duration: root.dur(240); easing.type: Easing.InOutCubic }
    }

    readonly property real targetFix: {
        if (hunting || mood === "stalkWalk" || mood === "chatter")
            return 1.0;
        if ((isWalking || mood === "walk" || mood === "sitToWalk") && hasCursor)
            return 0.90;
        return 0.0;
    }

    readonly property real walkHeadOffset: (isWalking || standRatio > 0.05)
        ? (facingSmooth * bodyW * 0.24) * standRatio
          + (mood === "stretch" ? facingSmooth * s * 0.08 : 0)
        : 0

    readonly property real bodyX: peek ? (width - bodyW) / 2 : catWalkX
    readonly property real bodyY: height - 4 - bodyH + startleHopY
    readonly property real headBaseX: peek ? (width - s) / 2 : catWalkX + (bodyW - s) / 2 + walkHeadOffset
    readonly property real headBaseY: peek ? height - headH * 0.74 : bodyY - headH + s * 0.28

    // ── Brain & Cursor Kinematics State ─────────────────────────────────────
    property string mood: "watch"
    property int misses: 0
    property int missLimit: 3
    property real nextActionAt: 0
    property real lastMoveAt: Date.now()
    property real curSpeed: 0
    property real petAccum: 0
    property real lastPetAt: 0
    property real stirAccum: 0
    property point lastCur: Qt.point(-1, -1)
    property point sampleA: Qt.point(-1, -1)
    property point lastSample: Qt.point(-1, -1)
    property int sulkSide: 1
    property point randLook: Qt.point(0, 0)
    property var actionHistory: []
    property bool usePawFixed: false
    property point pawFixed: Qt.point(0, 0)

    property real kneadPhase: 0
    property real scratchPhase: 0
    property real sniffPhase: 0
    property real chatterPhase: 0
    property real groomCyclePhase: 0
    property real pupilHippus: 0

    readonly property var idleMoods: [
        "watch", "walk", "groom", "stretch", "yawn", "lookAround",
        "earTwitch", "tailSwish", "tilt", "slowBlink", "knead",
        "scratch", "chatter", "sitToWalk", "walkToSit"
    ]
    readonly property bool asleep: mood === "sleep" || mood === "stir"
    readonly property bool hunting: mood === "stalk" || mood === "stalkWalk" || mood === "pounce" || mood === "recover"

    function curNow() {
        if (!root.lock || !root.lock.rootItem)
            return Qt.point(-1, -1);
        const pt = root.mapFromItem(root.lock.rootItem, root.lock.cursorPos.x, root.lock.cursorPos.y);
        if (!Number.isFinite(pt.x) || !Number.isFinite(pt.y))
            return Qt.point(-1, -1);
        return pt;
    }

    readonly property point cur: curNow()
    readonly property bool hasCursor: !!root.lock && root.lock.cursorInside && cur.x >= -2000
    readonly property bool inside: hasCursor && cur.x >= 0 && cur.y >= 0 && cur.x <= width && cur.y <= height

    // Strike & Walk Range Geometry
    readonly property real catCenterX: peek ? width * 0.5 : catWalkX + bodyW * 0.5
    readonly property real distToCursorX: hasCursor ? Math.abs(cur.x - catCenterX) : 0
    readonly property real strikeRangeX: s * 0.56

    // Anatomical Hit Zones on the Cat
    readonly property bool curOverHead: hasCursor
        && cur.x >= headBaseX - s * 0.08 && cur.x <= headBaseX + s * 1.08
        && cur.y >= headBaseY - s * 0.18 && cur.y <= headBaseY + headH * 0.82

    readonly property bool curOverBack: !peek && hasCursor
        && cur.x >= bodyX + bodyW * 0.10 && cur.x <= bodyX + bodyW * 0.90
        && cur.y >= bodyY - s * 0.04 && cur.y <= bodyY + bodyH * 0.62

    readonly property bool curNearNose: hasCursor
        && Math.hypot(cur.x - (headBaseX + s * 0.5), cur.y - (headBaseY + headH * 0.65)) < s * 0.38

    function clampPt(p) {
        const pad = root.s * 0.14;
        const cx = root.safeNum(p.x, root.width * 0.5);
        const cy = root.safeNum(p.y, root.height * 0.5);
        return Qt.point(
            Math.max(pad, Math.min(Math.max(pad, root.width - pad), cx)),
            Math.max(pad, Math.min(Math.max(pad, root.height - pad), cy))
        );
    }

    function updateFacingWithHysteresis(targetX) {
        const dx = targetX - root.catCenterX;
        if (Math.abs(dx) > root.s * 0.14) {
            root.walkFacing = dx >= 0 ? 1 : -1;
        }
    }

    // ── Pinpoint Stereoscopic Gaze Calculation ──────────────────────────────
    function computeSingleEyeTarget(eyeCenterX, eyeCenterY) {
        if (root.asleep || root.mood === "drowsy")
            return Qt.point(0, 0.45);
        if (root.mood === "sulk")
            return Qt.point(0.65 * root.sulkSide, 0.50);
        if (root.mood === "lookAround")
            return root.randLook;
        if (root.mood === "groom" || root.mood === "yawn" || root.mood === "pet" || root.mood === "knead")
            return Qt.point(0, 0.22);
        if (!root.hasCursor && !(root.mood === "pounce" && root.usePawFixed))
            return root.saccade;

        const targetPt = (root.mood === "pounce" && root.usePawFixed)
            ? (root.pawLift > 0.1 ? Qt.point(root.pawTargetX, root.pawTargetY) : root.pawFixed)
            : root.cur;

        const rawDx = targetPt.x - eyeCenterX;
        const rawDy = targetPt.y - eyeCenterY;
        const len = Math.hypot(rawDx, rawDy);
        if (len < 1.0 || !Number.isFinite(len))
            return Qt.point(0, 0);

        const rotRad = -root.safeNum(root.headTilt, 0) * Math.PI / 180.0;
        const cosR = Math.cos(rotRad);
        const sinR = Math.sin(rotRad);
        const localDx = rawDx * cosR - rawDy * sinR;
        const localDy = rawDx * sinR + rawDy * cosR;

        const k = Math.min(1.0, len / Math.max(16.0, root.s * 0.55));
        const gx = (localDx / len) * k;
        const gy = (localDy / len) * k;
        return Qt.point(
            Math.max(-1.0, Math.min(1.0, root.safeNum(gx, 0))),
            Math.max(-1.0, Math.min(1.0, root.safeNum(gy, 0)))
        );
    }

    // ── Real-Time 60/144Hz FrameAnimation Procedural Physics Engine ─────────
    FrameAnimation {
        id: physicsLoop
        running: root.running
        onTriggered: {
            const dt = Math.min(0.04, Math.max(0.001, frameTime));

            // Exponential smoothing helper (100% immune to frame-rate oscillation/vibration!)
            const alpha = function(rate) {
                return 1.0 - Math.exp(-rate * dt);
            };

            // 1. Velocity-Synced Zero-Slip Gait Solver
            const dx = root.catWalkX - root.prevCatWalkX;
            root.prevCatWalkX = root.catWalkX;
            const instVel = Math.abs(dx) / dt;
            const refSpeed = Math.max(10, root.s * 1.05);
            root.walkSpeedNorm = root.safeNum(root.walkSpeedNorm + (Math.min(1.3, instVel / refSpeed) - root.walkSpeedNorm) * alpha(12.0), 0);

            if (root.isWalking && root.s > 1) {
                const strideCyclePx = Math.max(8, root.s * (root.hunting ? 0.42 : 0.36));
                root.walkPhase = root.safeNum((root.walkPhase + Math.abs(dx) / strideCyclePx) % 1.0, 0);
            } else {
                root.walkSpeedNorm *= Math.exp(-10.0 * dt);
            }

            // 2. Live Cursor Interception during Pounce Strike
            if (root.mood === "pounce" && root.usePawFixed && root.hasCursor && root.pawLift < 0.05 && root.reach < 0.88) {
                const clampedCur = root.clampPt(root.cur);
                const kTrack = alpha(16.0);
                root.pawFixed = Qt.point(
                    root.pawFixed.x + (clampedCur.x - root.pawFixed.x) * kTrack,
                    root.pawFixed.y + (clampedCur.y - root.pawFixed.y) * kTrack
                );
            }

            // 3. Smooth 3D Body Turn & Spine Bend
            const diffFace = root.walkFacing - root.facingSmooth;
            root.facingSmooth = root.safeNum(root.facingSmooth + diffFace * alpha(10.0), 1.0);
            root.spineTurnBend = root.safeNum(diffFace * 0.55, 0);

            // 4. Smooth Vibration-Free Head & Ear Motion
            const tgtHDX = root.followX * root.s * (root.hunting || root.mood === "sniff" || root.mood === "pet" ? 0.12 : (root.targetFix > 0.5 ? 0.09 : 0.05));
            const tgtHDY = root.tgtHeadDY + root.pawLift * root.s * 0.06;
            root.headDX = root.safeNum(root.headDX + (tgtHDX - root.headDX) * alpha(12.0), 0);
            root.headDY = root.safeNum(root.headDY + (tgtHDY - root.headDY) * alpha(10.0), 0);
            root.headTilt = root.safeNum(root.headTilt + (root.tgtHeadTilt - root.headTilt) * alpha(10.0), 0);

            root.earLs = root.safeNum(root.earLs + (root.tgtEarL - root.earLs) * alpha(14.0), 0);
            root.earRs = root.safeNum(root.earRs + (root.tgtEarR - root.earRs) * alpha(14.0), 0);

            // 5. Crisp Stereoscopic Eyeball Tracking
            const eyeLeftX = root.headBaseX + root.headDX + root.s * 0.27;
            const eyeRightX = root.headBaseX + root.headDX + root.s * 0.73;
            const eyeCenterY = root.headBaseY + root.headDY + root.headH * 0.46;

            const gL = root.computeSingleEyeTarget(eyeLeftX, eyeCenterY);
            const gR = root.computeSingleEyeTarget(eyeRightX, eyeCenterY);
            const kGaze = alpha(28.0);

            root.lookXL = root.safeNum(root.lookXL + (gL.x - root.lookXL) * kGaze, 0);
            root.lookYL = root.safeNum(root.lookYL + (gL.y - root.lookYL) * kGaze, 0);
            root.lookXR = root.safeNum(root.lookXR + (gR.x - root.lookXR) * kGaze, 0);
            root.lookYR = root.safeNum(root.lookYR + (gR.y - root.lookYR) * kGaze, 0);

            // 6. Unconditionally Stable Phase-Delayed Harmonic Tail Wave
            const tailFreq = root.asleep ? 1.1 : (root.hunting || root.mood === "tailSwish" || root.mood === "startle" ? 7.2 : 2.4);
            root.tailClock = (root.tailClock + dt * tailFreq) % (Math.PI * 200);

            const walkTailDrag = Math.max(-18, Math.min(18, -dx * 1.4));
            const targetJ1 = (root.isWalking
                ? -22 + Math.sin(root.walkPhase * Math.PI * 2) * 14
                : Math.sin(root.tailClock) * root.tailAmp) + root.tailBias + walkTailDrag;
            const targetJ2 = targetJ1 * 1.15 + Math.sin(root.tailClock - 0.85) * (root.tailAmp * 0.45);
            const targetJ3 = targetJ2 * 1.18 + Math.sin(root.tailClock - 1.65) * (root.tailAmp * 0.65);

            root.tailJ1 = root.safeNum(root.tailJ1 + (targetJ1 - root.tailJ1) * alpha(12.0), 0);
            root.tailJ2 = root.safeNum(root.tailJ2 + (targetJ2 - root.tailJ2) * alpha(10.0), 0);
            root.tailJ3 = root.safeNum(root.tailJ3 + (targetJ3 - root.tailJ3) * alpha(8.5), 0);
        }
    }

    function enter(m, ms) {
        if (m === "sulk" || m === "tilt")
            root.sulkSide = Math.random() < 0.5 ? -1 : 1;
        root.mood = m;
        if (ms > 0) {
            phaseTimer.interval = ms;
            phaseTimer.restart();
        } else {
            phaseTimer.stop();
        }
    }

    function scheduleNext() {
        root.nextActionAt = Date.now() + 4000 + Math.random() * 6000;
    }

    function toWatch() {
        root.stopWalk();
        root.enter("watch", 0);
        root.scheduleNext();
    }

    function computeStalkStopX(cursorX) {
        const offset = root.s * 0.30;
        const desiredWalkX = (cursorX < root.catCenterX)
            ? (cursorX + offset - root.bodyW * 0.5)
            : (cursorX - offset - root.bodyW * 0.5);
        return Math.max(root.minWalkX, Math.min(root.maxWalkX, desiredWalkX));
    }

    function startWalk(destX, isStalk) {
        if (root.peek) return;
        const clampedDest = Math.max(root.minWalkX, Math.min(root.maxWalkX, destX));
        const dist = Math.abs(clampedDest - root.catWalkX);
        if (root.hasCursor && isStalk) {
            root.updateFacingWithHysteresis(root.cur.x);
        } else if (dist > root.s * 0.10) {
            root.walkFacing = clampedDest >= root.catWalkX ? 1 : -1;
        }

        if (dist < 8) {
            root.isWalking = false;
            if (isStalk) {
                root.enter("stalk", 320 + Math.random() * 220);
            }
            return;
        }
        root.targetWalkX = clampedDest;

        if (root.standRatio < 0.25 && !root.isWalking) {
            root.pendingDestX = clampedDest;
            root.pendingIsStalk = isStalk;
            root.enter("sitToWalk", 160);
            return;
        }

        root.executeWalk(clampedDest, isStalk);
    }

    function executeWalk(clampedDest, isStalk) {
        const dist = Math.abs(clampedDest - root.catWalkX);
        if (dist < 6) {
            root.isWalking = false;
            if (isStalk) root.enter("stalk", 300);
            return;
        }
        root.targetWalkX = clampedDest;
        root.walkFacing = clampedDest >= root.catWalkX ? 1 : -1;
        root.isWalking = true;
        const speed = isStalk ? root.s * 0.92 : root.s * 1.15;
        const durationMs = Math.max(260, Math.round((dist / speed) * 1000));

        walkAnimX.stop();
        walkAnimX.duration = root.dur(durationMs);
        walkAnimX.to = root.targetWalkX;
        walkAnimX.restart();
    }

    function stopWalk() {
        walkAnimX.stop();
        root.isWalking = false;
        root.walkSpeedNorm = 0;
    }

    function triggerStartle() {
        root.stopWalk();
        root.petAccum = 0;
        root.updateFacingWithHysteresis(root.cur.x);
        root.enter("startle", 680);
        startleHopAnim.restart();
    }

    function startHunt() {
        if (!root.hasCursor) return;
        root.updateFacingWithHysteresis(root.cur.x);

        if (!root.peek && root.distToCursorX > root.strikeRangeX) {
            const tgt = root.computeStalkStopX(root.cur.x);
            root.enter("stalkWalk", 0);
            root.startWalk(tgt, true);
        } else {
            root.stopWalk();
            root.enter("stalk", 320 + Math.random() * 240);
        }
    }

    function newLook() {
        root.randLook = Qt.point(Math.random() * 2 - 1, Math.random() * 1.4 - 0.7);
    }

    function pickAction() {
        const all = !root.peek
            ? ["walk", "groom", "stretch", "yawn", "lookAround", "earTwitch", "tailSwish", "tilt", "slowBlink", "knead", "scratch", "chatter"]
            : ["groom", "stretch", "yawn", "lookAround", "earTwitch", "tailSwish", "tilt", "slowBlink", "chatter"];
        const pool = all.filter(a => root.actionHistory.indexOf(a) < 0);
        const a = pool[Math.floor(Math.random() * pool.length)];
        const hist = root.actionHistory.slice();
        hist.push(a);
        while (hist.length > 3)
            hist.shift();
        root.actionHistory = hist;

        if (a === "walk") {
            const dest = root.minWalkX + Math.random() * (root.maxWalkX - root.minWalkX);
            root.enter("walk", 0);
            root.startWalk(dest, false);
            root.scheduleNext();
            return;
        }

        const d = {
            groom: 2800,
            stretch: 2300,
            yawn: 2000,
            lookAround: 2800,
            earTwitch: 800,
            tailSwish: 1900,
            tilt: 1600,
            slowBlink: 950,
            knead: 3000,
            scratch: 1800,
            chatter: 1100
        };
        root.enter(a, d[a]);
        if (a === "lookAround")
            root.newLook();
        else if (a === "earTwitch")
            twitchAnim.restart();
        else if (a === "groom")
            groomAnim.restart();
        else if (a === "chatter")
            chatterAnim.restart();
        else if (a === "scratch")
            scratchAnim.restart();
        root.scheduleNext();
    }

    function doPounce() {
        if (!root.peek && root.inside && root.distToCursorX > root.strikeRangeX * 1.25) {
            root.startHunt();
            return;
        }

        const base = root.hasCursor ? root.cur : (root.lastSample.x >= 0 ? root.lastSample : Qt.point(root.width * 0.5, root.height * 0.5));
        root.pawFixed = root.clampPt(base);
        root.usePawFixed = true;
        root.mood = "pounce";
        phaseTimer.stop();

        if (!root.peek) {
            root.updateFacingWithHysteresis(root.pawFixed.x);
            const idealDest = root.pawFixed.x - root.bodyW * 0.5 - root.walkFacing * root.s * 0.16;
            const hopDelta = Math.max(-root.s * 0.50, Math.min(root.s * 0.50, idealDest - root.catWalkX));
            pounceHopAnim.to = Math.max(root.minWalkX, Math.min(root.maxWalkX, root.catWalkX + hopDelta));
        }
        pounceAnim.restart();
    }

    function wakeUp() {
        root.stirAccum = 0;
        root.enter("perk", 550);
    }

    function advance() {
        const now = Date.now();
        switch (root.mood) {
        case "sitToWalk":
            root.enter(root.pendingIsStalk ? "stalkWalk" : "walk", 0);
            root.executeWalk(root.pendingDestX, root.pendingIsStalk);
            break;
        case "walkToSit":
        case "walk":
        case "knead":
        case "scratch":
            root.toWatch();
            break;
        case "pet":
            root.enter("slowBlink", 900);
            break;
        case "sniff":
            if (root.curOverHead || root.curOverBack) {
                root.enter("pet", 2400);
            } else if (root.inside) {
                root.startHunt();
            } else {
                root.toWatch();
            }
            break;
        case "startle":
            root.enter("perk", 600);
            break;
        case "chatter":
            if (root.inside)
                root.startHunt();
            else
                root.toWatch();
            break;
        case "stalkWalk":
            root.stopWalk();
            root.enter("stalk", 300 + Math.random() * 220);
            break;
        case "stalk":
            root.stopWalk();
            root.doPounce();
            break;
        case "recover":
            root.misses++;
            if (!root.inside || now - root.lastMoveAt > 4500) {
                root.toWatch();
            } else if (!root.peek && root.distToCursorX > root.strikeRangeX) {
                root.misses = 0;
                root.startHunt();
            } else if (root.misses >= root.missLimit) {
                root.enter("sulk", 1400 + Math.random() * 900);
            } else {
                root.startHunt();
            }
            break;
        case "sulk":
            root.misses = 0;
            if (root.inside)
                root.startHunt();
            else
                root.enter("perk", 650);
            break;
        case "perk":
            if (root.inside)
                root.startHunt();
            else
                root.toWatch();
            break;
        case "stir":
            root.stirAccum = 0;
            root.enter("sleep", 0);
            break;
        case "sleep":
        case "drowsy":
            break;
        default:
            root.toWatch();
        }
    }

    function noteMove() {
        const now = Date.now();
        const dt = Math.max(4, now - root.lastMoveAt);
        const p = root.curNow();
        const d = root.lastCur.x < 0 ? 0 : Math.hypot(p.x - root.lastCur.x, p.y - root.lastCur.y);
        const instSpeed = (d / dt) * 1000.0;
        root.curSpeed = root.curSpeed * 0.6 + instSpeed * 0.4;
        root.lastCur = p;
        root.lastMoveAt = now;

        if (root.asleep) {
            root.stirAccum += d;
            if (root.stirAccum > 30)
                root.wakeUp();
            else if (root.mood === "sleep" && root.stirAccum > 2) {
                twitchAnim.restart();
                root.enter("stir", 1400);
            }
            return;
        }
        if (root.mood === "drowsy") {
            if (d > 3)
                root.toWatch();
            return;
        }

        // 1. High-Speed Startle Reflex
        if (root.curSpeed > root.s * 18.0 && (root.curOverHead || root.curOverBack)
                && root.mood !== "pounce" && root.mood !== "startle") {
            root.triggerStartle();
            return;
        }

        // 2. Gentle Petting over Head / Back
        if ((root.curOverHead || root.curOverBack) && root.curSpeed < root.s * 4.2 && root.mood !== "pounce") {
            root.petAccum = Math.min(100, root.petAccum + d * 0.85);
            root.lastPetAt = now;
            if (root.petAccum > 18) {
                root.stopWalk();
                root.enter("pet", 2200);
                return;
            }
        }

        // 3. Curious Nose Sniffing
        if (root.curNearNose && root.curSpeed < root.s * 1.6
                && (root.mood === "watch" || root.mood === "sniff" || root.mood === "tilt")) {
            if (root.mood !== "sniff") {
                root.stopWalk();
                root.enter("sniff", 1400);
                sniffAnim.restart();
            }
            return;
        }

        // 4. Hysteresis-Stabilized Continuous Hunting & Multi-Side Stalking
        if (root.inside && !root.curOverHead && !root.curOverBack && root.mood !== "pounce") {
            if (root.mood === "stalk" || root.mood === "recover" || root.mood === "watch") {
                root.updateFacingWithHysteresis(root.cur.x);
            }

            if (root.mood === "stalkWalk" && !root.peek) {
                const newTgt = root.computeStalkStopX(root.cur.x);
                if (Math.abs(newTgt - root.targetWalkX) > root.s * 0.24) {
                    root.executeWalk(newTgt, true);
                }
                return;
            }

            if (!root.peek && root.distToCursorX > root.strikeRangeX * 1.08
                    && (root.mood === "stalk" || root.mood === "recover" || root.mood === "sulk" || root.mood === "perk" || root.idleMoods.indexOf(root.mood) >= 0)) {
                root.misses = 0;
                root.startHunt();
                return;
            }

            if (root.idleMoods.indexOf(root.mood) >= 0 || root.mood === "walk") {
                root.startHunt();
            }
        }
    }

    function tick() {
        const now = Date.now();
        root.lastSample = root.sampleA;
        root.sampleA = root.curNow();
        const idle = now - root.lastMoveAt;

        if (now - root.lastPetAt > 1200) {
            root.petAccum = Math.max(0, root.petAccum - 15);
        }
        if (idle > 180) {
            root.curSpeed *= 0.5;
        }

        if (root.curNearNose && idle > 200 && idle < 2500 && root.mood === "watch") {
            root.enter("sniff", 1400);
            sniffAnim.restart();
            return;
        }

        if (root.mood === "stalkWalk") {
            if (root.distToCursorX <= root.strikeRangeX * 0.85) {
                root.advance();
                return;
            }
        }

        if (!root.peek && root.inside && (root.mood === "stalk" || root.mood === "recover") && root.distToCursorX > root.strikeRangeX * 1.15) {
            root.startHunt();
            return;
        }

        if (root.idleMoods.indexOf(root.mood) >= 0) {
            if (root.inside && !root.curOverHead && !root.curOverBack && !root.curNearNose && idle < 3500) {
                root.startHunt();
                return;
            }
            if (idle > root.drowsyAfterMs) {
                root.stopWalk();
                root.enter("drowsy", 0);
                return;
            }
            if (root.mood === "watch" && now > root.nextActionAt)
                root.pickAction();
            if (root.mood === "watch" && !root.hasCursor && Math.random() < 0.35)
                root.saccade = Qt.point((Math.random() - 0.5) * 0.24, (Math.random() - 0.5) * 0.16);
            if (root.mood === "lookAround" && Math.random() < 0.5)
                root.newLook();
        } else if (root.mood === "drowsy" && idle > root.sleepAfterMs) {
            root.enter("sleep", 0);
        } else if (root.mood === "sleep" && idle > 1500) {
            root.stirAccum = 0;
        }
    }

    Connections {
        target: root.lock
        enabled: root.running
        function onCursorPosChanged() {
            root.noteMove();
        }
    }

    Timer {
        id: tickTimer
        interval: root.asleep || root.mood === "drowsy" ? 600 : 180
        repeat: true
        running: root.running
        onTriggered: root.tick()
    }

    Timer {
        id: phaseTimer
        repeat: false
        onTriggered: root.advance()
    }

    NumberAnimation {
        id: walkAnimX
        target: root
        property: "catWalkX"
        easing.type: Easing.InOutSine
        onFinished: {
            root.isWalking = false;
            root.walkSpeedNorm = 0;
            if (root.mood === "walk") {
                root.enter("walkToSit", 240);
            } else if (root.mood === "stalkWalk") {
                if (root.inside && root.distToCursorX > root.strikeRangeX * 1.15) {
                    root.startHunt();
                } else {
                    root.enter("stalk", 300 + Math.random() * 240);
                }
            }
        }
    }

    onRunningChanged: {
        if (!root.running) {
            phaseTimer.stop();
            root.stopWalk();
        } else {
            root.lastMoveAt = Date.now();
            root.scheduleNext();
        }
    }

    Component.onCompleted: {
        root.lastCur = root.curNow();
        root.sampleA = root.lastCur;
        root.lastSample = root.lastCur;
        root.lastMoveAt = Date.now();
        root.scheduleNext();
    }

    // ── Mood → Visual & Anatomical Targets ──────────────────────────────────
    readonly property real tgtLid: {
        switch (mood) {
        case "sleep":
            return 1;
        case "stir":
            return 0.62;
        case "drowsy":
            return 0.55;
        case "yawn":
            return 0.85;
        case "groom":
            return 0.48;
        case "sulk":
            return 0.40;
        case "slowBlink":
            return 0.92;
        case "pet":
            return 0.35;
        case "knead":
            return 0.30;
        case "scratch":
            return 0.75;
        default:
            return 0;
        }
    }
    property real lidBaseL: tgtLid
    property real lidBaseR: mood === "stir" ? 1.0 : tgtLid
    Behavior on lidBaseL {
        NumberAnimation { duration: root.dur(root.mood === "sleep" ? 900 : 220); easing.type: Easing.OutCubic }
    }
    Behavior on lidBaseR {
        NumberAnimation { duration: root.dur(root.mood === "sleep" ? 900 : 220); easing.type: Easing.OutCubic }
    }

    readonly property real tgtHappySquint: (mood === "pet" || mood === "knead") ? 0.85 : (mood === "scratch" ? 0.55 : 0.0)
    property real happySquint: tgtHappySquint
    Behavior on happySquint {
        NumberAnimation { duration: root.dur(260); easing.type: Easing.OutCubic }
    }

    property real blink: 0

    readonly property real tgtEyeScale: {
        switch (mood) {
        case "startle":
            return 1.22;
        case "stalk":
        case "stalkWalk":
        case "pounce":
        case "chatter":
            return 1.14;
        case "perk":
        case "sniff":
            return 1.15;
        case "tilt":
            return 1.08;
        case "sulk":
            return 0.94;
        default:
            return targetFix > 0.5 ? 1.10 : (inside ? 1.06 : 1);
        }
    }
    property real eyeScale: tgtEyeScale
    Behavior on eyeScale {
        NumberAnimation { duration: root.dur(200); easing.type: Easing.OutCubic }
    }

    readonly property real tgtPupil: {
        switch (mood) {
        case "startle":
        case "pounce":
            return 1.50;
        case "stalk":
        case "stalkWalk":
        case "chatter":
            return 1.44;
        case "perk":
        case "sniff":
        case "pet":
            return 1.26;
        case "tilt":
            return 1.18;
        case "sulk":
        case "drowsy":
            return 0.82;
        default:
            return targetFix > 0.5 ? 1.32 : (inside ? 1.18 : 0.92);
        }
    }
    property real pupilScale: tgtPupil
    Behavior on pupilScale {
        NumberAnimation { duration: root.dur(240); easing.type: Easing.OutCubic }
    }

    readonly property real tgtEar: {
        switch (mood) {
        case "startle":
            return 32;
        case "sulk":
            return 26;
        case "stalk":
        case "stalkWalk":
        case "chatter":
            return -9;
        case "pounce":
            return 16;
        case "perk":
        case "sniff":
            return -12;
        case "pet":
            return 8;
        case "scratch":
            return 22;
        case "sleep":
            return 10;
        case "drowsy":
            return 7;
        case "yawn":
            return 14;
        default:
            return 0;
        }
    }
    property real earBase: tgtEar
    Behavior on earBase {
        NumberAnimation { duration: root.dur(260); easing.type: Easing.OutCubic }
    }
    property real earTwitch: 0

    readonly property real cursorEarBiasL: (hasCursor && !asleep && followX < -0.15) ? -followX * 9 : 0
    readonly property real cursorEarBiasR: (hasCursor && !asleep && followX > 0.15) ? followX * 9 : 0

    readonly property real tgtEarL: earBase + cursorEarBiasL + (mood === "earTwitch" || mood === "stir" ? earTwitch : 0) - headDX * 0.9
    readonly property real tgtEarR: earBase + cursorEarBiasR + (mood === "scratch" ? 14 : 0) + headDX * 0.9

    readonly property real tgtMouth: mood === "yawn" ? 1 : 0
    property real mouthOpen: tgtMouth
    Behavior on mouthOpen {
        NumberAnimation { duration: root.dur(root.tgtMouth > 0 ? 650 : 480); easing.type: Easing.InOutSine }
    }

    readonly property real tgtWhisker: {
        if (hunting || mood === "perk" || mood === "sniff" || mood === "chatter")
            return 1.0;
        if (mood === "pet" || mood === "knead")
            return 0.45;
        if (mood === "sulk" || mood === "startle" || asleep)
            return -0.85;
        return 0.0;
    }
    property real whiskerForward: tgtWhisker
    Behavior on whiskerForward {
        NumberAnimation { duration: root.dur(240); easing.type: Easing.OutCubic }
    }

    readonly property real tgtHeadDY: {
        if (peek) {
            switch (mood) {
            case "sleep":
                return headH * 0.30;
            case "drowsy":
                return headH * 0.10;
            case "sulk":
                return headH * 0.22;
            case "stalk":
            case "stalkWalk":
                return headH * 0.08;
            case "sniff":
            case "pet":
                return -headH * 0.05;
            default:
                return 0;
            }
        }
        switch (mood) {
        case "sleep":
            return s * 0.17;
        case "stir":
            return s * 0.12;
        case "drowsy":
            return s * 0.06;
        case "sulk":
            return s * 0.14;
        case "stalk":
        case "stalkWalk":
            return s * 0.15;
        case "stretch":
            return s * 0.19;
        case "startle":
            return -s * 0.08;
        case "perk":
        case "sniff":
        case "yawn":
            return -s * 0.05;
        case "pet":
            return -s * 0.04;
        default:
            return 0;
        }
    }

    readonly property real tgtHeadTilt: {
        if (pawLift > 0.1) {
            return (pawLeft ? -12 : 12) * pawLift;
        }
        switch (mood) {
        case "sleep":
            return 11 * sulkSide;
        case "stir":
            return 6 * sulkSide;
        case "tilt":
            return 15 * sulkSide;
        case "pet":
            return followX * 14;
        case "sniff":
            return followX * 8;
        case "scratch":
            return 18;
        case "groom":
            return (pawLeft ? -11 : 11) + Math.sin(groomCyclePhase * Math.PI * 2) * 5;
        case "sulk":
            return 6 * sulkSide;
        default:
            return 0;
        }
    }

    readonly property real followX: {
        if (!hasCursor || asleep || mood === "drowsy" || mood === "sulk" || mood === "lookAround")
            return 0;
        const dx = cur.x - (headBaseX + s * 0.5);
        return Math.max(-1, Math.min(1, dx / Math.max(40, width * 0.5)));
    }

    readonly property real tgtBSX: {
        switch (mood) {
        case "sleep":
            return 1.08;
        case "stir":
        case "drowsy":
            return 1.04;
        case "stretch":
            return 1.18;
        case "startle":
            return 0.90;
        case "sulk":
            return 0.94;
        case "perk":
        case "yawn":
            return 0.96;
        case "sitToWalk":
            return 1.06;
        case "walkToSit":
            return 1.02;
        case "stalk":
        case "stalkWalk":
            return 1.06;
        default:
            return 1.0;
        }
    }
    readonly property real tgtBSY: {
        switch (mood) {
        case "sleep":
            return 0.88;
        case "stir":
        case "drowsy":
            return 0.94;
        case "stretch":
            return 0.84;
        case "startle":
            return 1.14;
        case "sulk":
            return 1.06;
        case "perk":
        case "yawn":
            return 1.08;
        case "sitToWalk":
            return 0.95;
        case "walkToSit":
            return 0.98;
        case "stalk":
        case "stalkWalk":
            return 0.88;
        default:
            return 1.0;
        }
    }
    property real bsx: tgtBSX
    property real bsy: tgtBSY
    Behavior on bsx {
        NumberAnimation { duration: root.dur(280); easing.type: Easing.OutCubic }
    }
    Behavior on bsy {
        NumberAnimation { duration: root.dur(280); easing.type: Easing.OutCubic }
    }
    property real breath: 0
    property real wiggle: 0
    property real anticip: 0
    property real lunge: 0
    property point saccade: Qt.point(0, 0)
    property real swayA: 0
    property real swayB: 0

    // Pounce Lunge Vector
    readonly property point strikeTargetPt: usePawFixed ? pawFixed : (hasCursor ? cur : Qt.point(width * 0.5, height * 0.5))
    readonly property real lungeDirX: {
        const dx = strikeTargetPt.x - (headBaseX + s * 0.5);
        const dy = strikeTargetPt.y - (headBaseY + headH * 0.5);
        const len = Math.hypot(dx, dy);
        return len > 1.0 ? (dx / len) : 0.0;
    }
    readonly property real lungeDirY: {
        const dx = strikeTargetPt.x - (headBaseX + s * 0.5);
        const dy = strikeTargetPt.y - (headBaseY + headH * 0.5);
        const len = Math.hypot(dx, dy);
        return len > 1.0 ? (dy / len) : 0.0;
    }
    readonly property real lungeDX: lungeDirX * s * 0.22 * lunge
    readonly property real lungeDY: lungeDirY * s * 0.10 * lunge + s * 0.12 * anticip + (mood === "groom" ? Math.sin(groomCyclePhase * Math.PI * 2) * s * 0.04 : 0)

    readonly property real actualHeadX: headBaseX + headDX + lungeDX
    readonly property real actualHeadY: headBaseY + headDY + lungeDY

    readonly property real tgtFeet: (mood === "stretch" ? 0.34 : (mood === "pet" || mood === "knead" ? 0.23 : 0.20))
    property real feetSpread: tgtFeet
    Behavior on feetSpread {
        NumberAnimation { duration: root.dur(260); easing.type: Easing.OutBack }
    }

    // ── Tail Target Parameters ──────────────────────────────────────────────
    readonly property real tailAmp: {
        switch (mood) {
        case "startle":
            return 30;
        case "tailSwish":
            return 28;
        case "pounce":
            return 24;
        case "stalk":
        case "chatter":
            return 16;
        case "perk":
            return 20;
        case "pet":
        case "knead":
            return 12;
        case "sleep":
        case "stir":
            return 2.5;
        case "sulk":
            return 4;
        case "stretch":
            return 6;
        default:
            return 10;
        }
    }
    readonly property real tailBias: {
        if (asleep) return 46;
        if (mood === "stretch" || mood === "pet" || mood === "startle") return -20;
        if (mood === "sulk") return 16;
        return 0;
    }

    // ── GPU CurveRenderer Tapered Bezier Forelimb Kinematics (Like FelineLimb!) ──
    property real reach: 0
    property real pawWindup: 0     // 0..1 pre-pounce paw coil
    property real clawExtend: 0    // 0..1 retractable claws unsheathing
    property real toeSpread: 0     // 0..1 toe beans fanning wide
    property real toeCup: 0        // 0..1 toes pressing/cupping down to pin cursor
    property real pawLift: 0       // 0..1 inquisitive lift to peek under paw
    property real pawShake: 0      // wrist flick on retraction
    property real swatBat: 0       // 0..1 playful feline secondary "bop"
    property real slashSwoosh: 0   // visual curved swoosh trail

    readonly property real reachRest: 0.0
    Behavior on reach {
        enabled: root.mood !== "pounce" && root.mood !== "groom"
        NumberAnimation { duration: root.dur(220); easing.type: Easing.OutCubic }
    }
    onReachRestChanged: if (root.mood !== "pounce" && root.mood !== "groom")
        root.reach = root.reachRest

    readonly property bool pawLeft: strikeTargetPt.x < catCenterX
    readonly property real sideSign: pawLeft ? -1.0 : 1.0

    // Outer-Lateral Shoulder Anchor (Placed on the outer chest so the arm sweeps around the cheek, NEVER through the nose/mouth!)
    readonly property point shoulder: peek
        ? Qt.point(width * 0.5 + sideSign * s * 0.34, height + s * 0.06)
        : Qt.point(
            bodyX + bodyW * 0.5 + lungeDX * 0.5 + (standRatio > 0.05 ? facingSmooth * s * 0.25 : sideSign * s * 0.33),
            bodyY + bodyH * 0.52 + lungeDY * 0.5
        )

    // Rest Paw Position (Planted on floor below shoulder)
    readonly property point restPawPos: peek
        ? Qt.point(shoulder.x, height + s * 0.15)
        : Qt.point(shoulder.x + sideSign * s * 0.04, height - s * 0.07)

    // Pre-Pounce Coiled Paw Position (Tucked at outer chest)
    readonly property point cockedPawPos: Qt.point(
        shoulder.x + sideSign * s * 0.08,
        shoulder.y - s * 0.06
    )

    // Circular Face-Washing Trajectory during Grooming
    readonly property point groomPoint: {
        const angle = root.groomCyclePhase * Math.PI * 2;
        const cx = root.headBaseX + root.headDX + root.s * (root.pawLeft ? 0.18 : 0.82);
        const cy = root.headBaseY + root.headDY + root.headH * 0.58;
        return Qt.point(
            cx + Math.cos(angle) * root.s * 0.07 * sideSign,
            cy + Math.sin(angle) * root.s * 0.12
        );
    }

    readonly property point aim: mood === "groom" ? groomPoint : clampPt(strikeTargetPt)

    readonly property real armMax: peek ? height * 1.02 : s * 1.08
    readonly property real rawAimDist: Math.hypot(aim.x - shoulder.x, aim.y - shoulder.y)
    readonly property point clampedAim: rawAimDist > armMax
        ? Qt.point(shoulder.x + (aim.x - shoulder.x) * (armMax / rawAimDist), shoulder.y + (aim.y - shoulder.y) * (armMax / rawAimDist))
        : aim

    readonly property real strikeArc: Math.sin(reach * Math.PI) * (1.0 - pawWindup * 0.8)
    readonly property real swatShakeOffset: Math.sin(pawShake * Math.PI * 6) * s * 0.03
    readonly property real batOffsetY: -Math.sin(swatBat * Math.PI) * s * 0.10

    // Distal Wrist/Paw Center (`W`)
    readonly property real pawTargetX: {
        const baseT = Math.min(1.0, reach);
        const startX = restPawPos.x * (1.0 - pawWindup) + cockedPawPos.x * pawWindup;
        const linearX = startX * (1.0 - baseT) + clampedAim.x * baseT;
        // Sweeps outward around the side of the head during mid-strike
        const lateralHookX = sideSign * s * 0.14 * strikeArc * (mood === "groom" ? 0.2 : 1.0);
        return root.safeNum(linearX + lateralHookX + swatShakeOffset, shoulder.x);
    }

    readonly property real pawTargetY: {
        const baseT = Math.min(1.0, reach);
        const startY = restPawPos.y * (1.0 - pawWindup) + cockedPawPos.y * pawWindup;
        const linearY = startY * (1.0 - baseT) + clampedAim.y * baseT;
        const overheadArcY = -s * 0.14 * strikeArc * (mood === "groom" ? 0.1 : 1.0);
        const peekLiftY = -s * 0.09 * pawLift;
        return root.safeNum(linearY + overheadArcY + peekLiftY + batOffsetY, shoulder.y);
    }

    // Outward-Cheek Elbow Control Point (`E`): Always bows outward around the head (`sideSign * s * 0.22`)
    readonly property point elbowPos: {
        const dx = pawTargetX - shoulder.x;
        const dy = pawTargetY - shoulder.y;
        const d = Math.max(1.0, Math.hypot(dx, dy));
        const extRatio = Math.min(0.96, d / Math.max(10, armMax));
        const outwardBow = (1.0 - extRatio * 0.65) * s * 0.24;

        return Qt.point(
            (shoulder.x + pawTargetX) * 0.5 + sideSign * outwardBow,
            (shoulder.y + pawTargetY) * 0.5 + s * 0.06
        );
    }

    // Exact Bezier Tangent Angle at the Wrist (`E -> W`) so the Paw is 100% seamlessly aligned with the arm tip!
    readonly property real wristTangentAngle: Math.atan2(pawTargetY - elbowPos.y, pawTargetX - elbowPos.x) * 180 / Math.PI
    readonly property real pawRotation: {
        if (mood === "groom") {
            return wristTangentAngle + sideSign * -16 + Math.cos(groomCyclePhase * Math.PI * 2) * 8;
        }
        return wristTangentAngle + sideSign * (8 * pawWindup - 6 * pawLift);
    }

    // ── Animations ──────────────────────────────────────────────────────────
    Timer {
        id: blinkTimer
        interval: 3000
        repeat: true
        running: root.running && !root.asleep && root.mood !== "slowBlink" && root.mood !== "pet"
        onTriggered: {
            blinkTimer.interval = 2500 + Math.random() * 3500;
            blinkAnim.restart();
        }
    }

    SequentialAnimation {
        id: blinkAnim
        NumberAnimation { target: root; property: "blink"; to: 1; duration: root.dur(70); easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "blink"; to: 0; duration: root.dur(120); easing.type: Easing.InQuad }
        ScriptAction {
            script: {
                if (Math.random() < 0.22)
                    doubleBlinkAnim.restart();
            }
        }
    }

    SequentialAnimation {
        id: doubleBlinkAnim
        PauseAnimation { duration: 110 }
        NumberAnimation { target: root; property: "blink"; to: 1; duration: root.dur(70); easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "blink"; to: 0; duration: root.dur(120); easing.type: Easing.InQuad }
    }

    SequentialAnimation {
        id: twitchAnim
        NumberAnimation { target: root; property: "earTwitch"; to: 16; duration: root.dur(90); easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "earTwitch"; to: -4; duration: root.dur(110); easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "earTwitch"; to: 10; duration: root.dur(90); easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "earTwitch"; to: 0; duration: root.dur(140); easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: startleHopAnim
        NumberAnimation { target: root; property: "startleHopY"; to: -root.s * 0.22; duration: root.dur(110); easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "startleHopY"; to: 0; duration: root.dur(210); easing.type: Easing.OutBounce }
    }

    SequentialAnimation {
        id: sniffAnim
        NumberAnimation { target: root; property: "sniffPhase"; from: 0; to: 1; duration: root.dur(1200); easing.type: Easing.Linear }
        ScriptAction { script: root.sniffPhase = 0; }
    }

    SequentialAnimation {
        id: chatterAnim
        NumberAnimation { target: root; property: "chatterPhase"; from: 0; to: 1; duration: root.dur(900); easing.type: Easing.Linear }
        ScriptAction { script: root.chatterPhase = 0; }
    }

    SequentialAnimation {
        id: scratchAnim
        NumberAnimation { target: root; property: "scratchPhase"; from: 0; to: 1; duration: root.dur(1800); easing.type: Easing.Linear }
        ScriptAction { script: root.scratchPhase = 0; }
    }

    NumberAnimation {
        running: root.running && (root.mood === "pet" || root.mood === "knead")
        loops: Animation.Infinite
        target: root
        property: "kneadPhase"
        from: 0
        to: 1
        duration: root.dur(950)
    }

    SequentialAnimation {
        running: root.running && root.hasCursor && !root.asleep
        loops: Animation.Infinite
        NumberAnimation { target: root; property: "pupilHippus"; to: 1; duration: 680; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "pupilHippus"; to: -1; duration: 680; easing.type: Easing.InOutSine }
    }

    SequentialAnimation {
        running: root.running
        loops: Animation.Infinite
        NumberAnimation { target: root; property: "breath"; to: 1; duration: root.asleep ? 2300 : 1700; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "breath"; to: 0; duration: root.asleep ? 2300 : 1700; easing.type: Easing.InOutSine }
    }

    SequentialAnimation {
        running: root.running && !root.asleep
        loops: Animation.Infinite
        NumberAnimation { target: root; property: "swayA"; to: 1; duration: 3100; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "swayA"; to: -1; duration: 3100; easing.type: Easing.InOutSine }
    }
    SequentialAnimation {
        running: root.running && !root.asleep
        loops: Animation.Infinite
        NumberAnimation { target: root; property: "swayB"; to: 1; duration: 4700; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "swayB"; to: -1; duration: 4700; easing.type: Easing.InOutSine }
    }

    onMoodChanged: {
        if (mood !== "pounce")
            wiggle = 0;
        if (mood !== "groom" && groomAnim.running) {
            groomAnim.stop();
            reach = reachRest;
            groomCyclePhase = 0;
        }
    }

    SequentialAnimation {
        id: groomAnim
        NumberAnimation { target: root; property: "reach"; to: 0.95; duration: root.dur(280); easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "groomCyclePhase"; from: 0; to: 3; duration: root.dur(2100); easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "reach"; to: 0; duration: root.dur(280); easing.type: Easing.InCubic }
        ScriptAction { script: root.groomCyclePhase = 0; }
    }

    // ── Research-Backed Feline Pounce, Grab & Playful Bop Choreography ──────
    SequentialAnimation {
        id: pounceAnim

        // 1. Pre-Pounce Coil & One-Paw Hover
        ParallelAnimation {
            NumberAnimation { target: root; property: "anticip"; to: 1; duration: root.dur(150); easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "pawWindup"; to: 1; duration: root.dur(150); easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "toeSpread"; to: 0.20; duration: root.dur(150); easing.type: Easing.OutSine }
            NumberAnimation { target: root; property: "reach"; to: 0.08; duration: root.dur(150); easing.type: Easing.OutCubic }
        }

        // Single brief hind-leg calibration wiggle right before pounce release (No continuous vibration!)
        SequentialAnimation {
            NumberAnimation { target: root; property: "wiggle"; to: 0.8; duration: root.dur(45); easing.type: Easing.InOutSine }
            NumberAnimation { target: root; property: "wiggle"; to: -0.8; duration: root.dur(50); easing.type: Easing.InOutSine }
            NumberAnimation { target: root; property: "wiggle"; to: 0; duration: root.dur(45); easing.type: Easing.InOutSine }
        }

        // 2. Explosive Whole-Body Lunge & Downward Forelimb Swat
        ParallelAnimation {
            NumberAnimation {
                id: pounceHopAnim
                target: root
                property: "catWalkX"
                duration: root.dur(115)
                easing.type: Easing.OutCubic
            }
            NumberAnimation { target: root; property: "anticip"; to: 0; duration: root.dur(75); easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "lunge"; to: 1; duration: root.dur(85); easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "pawWindup"; to: 0; duration: root.dur(65); easing.type: Easing.InQuad }
            NumberAnimation { target: root; property: "reach"; to: 1; duration: root.dur(85); easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "clawExtend"; to: 1; duration: root.dur(70); easing.type: Easing.OutBack }
            NumberAnimation { target: root; property: "toeSpread"; to: 1; duration: root.dur(70); easing.type: Easing.OutBack }
            SequentialAnimation {
                NumberAnimation { target: root; property: "slashSwoosh"; to: 1; duration: root.dur(38); easing.type: Easing.OutSine }
                NumberAnimation { target: root; property: "slashSwoosh"; to: 0; duration: root.dur(65); easing.type: Easing.InSine }
            }
        }

        // 3. Pin & Playful Secondary Feline "Bop"
        ParallelAnimation {
            NumberAnimation { target: root; property: "toeCup"; to: 0.90; duration: root.dur(70); easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "swatBat"; from: 0; to: 1; duration: root.dur(120); easing.type: Easing.InOutSine }
            SequentialAnimation {
                PauseAnimation { duration: root.dur(45) }
                NumberAnimation { target: root; property: "toeCup"; to: 1.0; duration: root.dur(70); easing.type: Easing.OutQuad }
                NumberAnimation { target: root; property: "toeSpread"; to: 0.30; duration: root.dur(70); easing.type: Easing.OutQuad }
            }
        }
        ScriptAction { script: root.swatBat = 0; }

        PauseAnimation { duration: 90 }

        // 4. Inquisitive Peek under Paw
        ParallelAnimation {
            NumberAnimation { target: root; property: "pawLift"; to: 1; duration: root.dur(150); easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "toeCup"; to: 0; duration: root.dur(140); easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "clawExtend"; to: 0; duration: root.dur(140); easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "toeSpread"; to: 0.10; duration: root.dur(140); easing.type: Easing.InOutQuad }
        }

        PauseAnimation { duration: 75 }

        // 5. Smooth Retraction into Stance
        ParallelAnimation {
            NumberAnimation { target: root; property: "reach"; to: 0; duration: root.dur(260); easing.type: Easing.InOutCubic }
            NumberAnimation { target: root; property: "lunge"; to: 0; duration: root.dur(300); easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            NumberAnimation { target: root; property: "pawLift"; to: 0; duration: root.dur(200); easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "pawShake"; to: 2; duration: root.dur(210); easing.type: Easing.Linear }
        }

        ScriptAction {
            script: {
                root.pawShake = 0;
                root.usePawFixed = false;
                root.enter("recover", 150 + Math.random() * 120);
            }
        }
    }

    // ── Rendering ───────────────────────────────────────────────────────────
    readonly property color fur: Colours.palette.m3primaryContainer
    readonly property color furTop: Qt.lighter(fur, 1.08)
    readonly property color furBottom: Qt.darker(fur, 1.12)
    readonly property color furOutline: Qt.alpha(Colours.palette.m3onPrimaryContainer, 0.38)
    readonly property color beanColor: Qt.alpha(Colours.palette.m3error, 0.78)

    // Multi-Link Harmonic Wave Tail
    Item {
        id: tail
        visible: !root.peek
        z: root.asleep ? 2.5 : 0
        width: root.s * 0.62
        height: root.s * 0.78
        x: root.standRatio > 0.05
            ? root.bodyX + root.bodyW * (0.50 - root.facingSmooth * 0.36)
            : root.bodyX + root.bodyW * 0.80
        y: root.bodyY + root.bodyH - height - root.s * 0.05 * root.standRatio
        transformOrigin: Item.BottomLeft
        rotation: root.tailJ1
        transform: Scale {
            origin.x: 0
            origin.y: tail.height
            xScale: (root.standRatio > 0.5 && root.facingSmooth > 0) ? -1 : 1
        }

        readonly property real midWhipX: (root.tailJ2 - root.tailJ1) * tail.width * 0.015
        readonly property real tipFlickX: (root.tailJ3 - root.tailJ1) * tail.width * 0.022
        readonly property real puffScale: root.mood === "startle" ? 1.55 : 1.0

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: root.furOutline
                strokeWidth: root.s * 0.145 * tail.puffScale + 3.0
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: 0
                startY: tail.height
                PathCubic {
                    x: tail.width * 0.36 + tail.tipFlickX
                    y: tail.height * 0.04
                    control1X: tail.width * 0.92 + tail.midWhipX
                    control1Y: tail.height * 0.96
                    control2X: tail.width * 1.02 - tail.tipFlickX * 0.5
                    control2Y: tail.height * 0.24
                }
            }
            ShapePath {
                strokeColor: root.fur
                strokeWidth: root.s * 0.145 * tail.puffScale
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: 0
                startY: tail.height
                PathCubic {
                    x: tail.width * 0.36 + tail.tipFlickX
                    y: tail.height * 0.04
                    control1X: tail.width * 0.92 + tail.midWhipX
                    control1Y: tail.height * 0.96
                    control2X: tail.width * 1.02 - tail.tipFlickX * 0.5
                    control2Y: tail.height * 0.24
                }
            }
        }
    }

    // Body
    CatBody {
        id: body
        visible: !root.peek
        z: 1
        s: root.s
        fur: root.fur
        furOutline: root.furOutline
        mood: root.mood
        facing: root.walkFacing
        facingSmooth: root.facingSmooth
        isWalking: root.isWalking
        walkPhase: root.walkPhase
        walkSpeedNorm: root.walkSpeedNorm
        standRatio: root.standRatio
        anticip: root.anticip
        lunge: root.lunge
        breath: root.breath
        wiggle: root.wiggle
        reach: root.reach
        pawLeft: root.pawLeft
        feetSpread: root.feetSpread
        hunting: root.hunting
        bsx: root.bsx
        bsy: root.bsy
        kneadPhase: root.kneadPhase
        scratchPhase: root.scratchPhase
        spineTurnBend: root.spineTurnBend

        x: root.bodyX + root.lungeDX * 0.5
        y: root.bodyY
    }

    // Head
    CatFace {
        id: face
        z: 2
        size: root.s
        x: root.actualHeadX + root.swayA * root.s * 0.012 * (1.0 - root.targetFix * 0.75)
        y: root.actualHeadY + (root.isWalking ? Math.sin(root.walkPhase * Math.PI * 4) * root.s * 0.020 * (1.0 - root.targetFix * 0.65) : 0)
        rotation: root.headTilt + root.swayB * 1.2 * (1.0 - root.targetFix * 0.75) + (root.isWalking ? Math.cos(root.walkPhase * Math.PI * 4) * 1.3 * root.facingSmooth * (1.0 - root.targetFix * 0.65) : 0)
        transformOrigin: Item.Bottom
        lookX: root.lookX
        lookY: root.lookY
        lookXL: root.lookXL
        lookXR: root.lookXR
        lookYL: root.lookYL
        lookYR: root.lookYR
        lidL: Math.max(root.blink, root.lidBaseL)
        lidR: Math.max(root.blink, root.lidBaseR)
        lowerLid: (root.hunting || root.mood === "chatter" ? 0.24 : (root.inside ? 0.08 : 0))
        eyeScale: root.eyeScale
        pupilScale: root.pupilScale
        earL: root.earLs
        earR: root.earRs
        mouthOpen: root.mouthOpen
        blush: root.mood === "sulk" ? 0.34 : 0.22
        headYaw: root.standRatio > 0.5 ? root.facingSmooth * 0.38 + root.lookX * 0.55 : root.lookX * 0.65
        whiskerForward: root.whiskerForward
        happySquint: root.happySquint
        sniffPhase: root.sniffPhase
        chatterPhase: root.chatterPhase
        groomLick: root.mood === "groom" ? Math.max(0, Math.sin(root.groomCyclePhase * Math.PI * 2)) : 0
        pupilHippus: root.pupilHippus
    }

    // ── GPU CurveRenderer Tapered Bezier Forelimb (`armShape` — Same Shader Technique as `FelineLimb`!) ──
    Item {
        id: ikArmLayer
        anchors.fill: parent
        z: 3
        visible: root.reach > 0.02

        // Parallel-Offset Tapered Bezier Geometry (Shoulder S -> Elbow E -> Wrist W)
        readonly property real upperW: root.s * 0.22
        readonly property real elbowW: root.s * 0.175
        readonly property real wristW: root.s * 0.145

        readonly property real chordDx: root.pawTargetX - root.shoulder.x
        readonly property real chordDy: root.pawTargetY - root.shoulder.y
        readonly property real chordLen: Math.max(1.0, Math.hypot(chordDx, chordDy))
        // Consistent unit perpendicular normal vector `(nx, ny)` so the left & right edges can NEVER twist!
        readonly property real nx: -chordDy / chordLen
        readonly property real ny:  chordDx / chordLen

        readonly property real sLx: root.shoulder.x - nx * upperW * 0.50
        readonly property real sLy: root.shoulder.y - ny * upperW * 0.50
        readonly property real sRx: root.shoulder.x + nx * upperW * 0.50
        readonly property real sRy: root.shoulder.y + ny * upperW * 0.50

        readonly property real eLx: root.elbowPos.x - nx * elbowW * 0.52
        readonly property real eLy: root.elbowPos.y - ny * elbowW * 0.52
        readonly property real eRx: root.elbowPos.x + nx * elbowW * 0.52
        readonly property real eRy: root.elbowPos.y + ny * elbowW * 0.52

        readonly property real wLx: root.pawTargetX - nx * wristW * 0.48
        readonly property real wLy: root.pawTargetY - ny * wristW * 0.48
        readonly property real wRx: root.pawTargetX + nx * wristW * 0.48
        readonly property real wRy: root.pawTargetY + ny * wristW * 0.48

        // Open-Shoulder start/end points (18% down from shoulder so the root merges seamlessly into torso fur!)
        readonly property real sOpenLx: sLx * 0.82 + eLx * 0.18
        readonly property real sOpenLy: sLy * 0.82 + eLy * 0.18
        readonly property real sOpenRx: sRx * 0.82 + eRx * 0.18
        readonly property real sOpenRy: sRy * 0.82 + eRy * 0.18

        // 1. Seamless Tapered Forelimb Mesh (Identical shader style to `FelineLimb`)
        Shape {
            id: armShape
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            // Pass 1: Volumetric LinearGradient Fill Pass (No stroke)
            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: root.shoulder.x
                    y1: root.shoulder.y
                    x2: root.pawTargetX
                    y2: root.pawTargetY
                    GradientStop { position: 0.0; color: root.fur }
                    GradientStop { position: 0.55; color: root.furTop }
                    GradientStop { position: 1.0; color: root.furBottom }
                }

                startX: ikArmLayer.sLx
                startY: ikArmLayer.sLy
                PathQuad {
                    controlX: ikArmLayer.eLx
                    controlY: ikArmLayer.eLy
                    x: ikArmLayer.wLx
                    y: ikArmLayer.wLy
                }
                PathLine {
                    x: ikArmLayer.wRx
                    y: ikArmLayer.wRy
                }
                PathQuad {
                    controlX: ikArmLayer.eRx
                    controlY: ikArmLayer.eRy
                    x: ikArmLayer.sRx
                    y: ikArmLayer.sRy
                }
            }

            // Pass 2: Open-Top Outline Pass (Leaves shoulder root open to blend 100% seamlessly into body!)
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.furOutline
                strokeWidth: 1.4
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.RoundCap

                startX: ikArmLayer.sOpenLx
                startY: ikArmLayer.sOpenLy
                PathQuad {
                    controlX: ikArmLayer.eLx
                    controlY: ikArmLayer.eLy
                    x: ikArmLayer.wLx
                    y: ikArmLayer.wLy
                }
                PathLine {
                    x: ikArmLayer.wRx
                    y: ikArmLayer.wRy
                }
                PathQuad {
                    controlX: ikArmLayer.eRx
                    controlY: ikArmLayer.eRy
                    x: ikArmLayer.sOpenRx
                    y: ikArmLayer.sOpenRy
                }
            }
        }

        // 2. Cohesive Feline Paw Attached Directly to the Distal Wrist Joint
        Item {
            id: pawWrist
            x: root.pawTargetX
            y: root.pawTargetY
            rotation: root.pawRotation

            transform: Scale {
                origin.x: 0
                origin.y: 0
                xScale: 1.0 + root.toeCup * 0.08 - root.pawWindup * 0.05
                yScale: 1.0 + root.toeSpread * 0.08 - root.pawWindup * 0.05
            }

            // Main Rounded Paw Pad Base (Covers wrist seam cleanly)
            Rectangle {
                id: palmBase
                width: root.s * 0.245
                height: root.s * 0.23
                radius: height * 0.48
                x: -width * 0.42
                y: -height * 0.50
                color: root.furBottom
                border.width: 1.25
                border.color: root.furOutline

                // Soft Heart-Bean Central Metacarpal Cushion
                Rectangle {
                    id: plantarPad
                    width: parent.width * 0.48
                    height: parent.height * 0.46
                    radius: height * 0.46
                    x: parent.width * 0.22
                    y: (parent.height - height) * 0.50
                    color: root.beanColor

                    Rectangle {
                        width: parent.width * 0.30
                        height: width
                        radius: width / 2
                        x: parent.width * 0.20
                        y: parent.height * 0.18
                        color: Qt.lighter(Colours.palette.m3error, 1.45)
                        opacity: 0.72
                    }
                }
            }

            // 4 Snugly-Seated Digital Toe Beans fanning around the front arc of `palmBase`
            Repeater {
                model: 4
                Item {
                    id: toeItem
                    required property int index

                    readonly property bool isInnerToe: index === 1 || index === 2
                    readonly property real baseAngle: {
                        switch (index) {
                        case 0: return -35;
                        case 1: return -11.5;
                        case 2: return 11.5;
                        case 3: return 35;
                        default: return 0;
                        }
                    }
                    readonly property real spreadFactor: 1.0 + root.toeSpread * 0.35 - root.pawWindup * 0.20 - root.toeCup * 0.14
                    readonly property real fannedAngle: baseAngle * spreadFactor
                    readonly property real rad: fannedAngle * Math.PI / 180
                    readonly property real baseDist: root.s * (isInnerToe ? 0.132 : 0.118)
                    readonly property real toeDist: baseDist + root.toeSpread * root.s * 0.015 - root.toeCup * root.s * 0.014

                    x: Math.cos(rad) * toeDist - width * 0.50
                    y: Math.sin(rad) * toeDist - height * 0.50
                    width: root.s * (isInnerToe ? 0.102 : 0.094)
                    height: root.s * (isInnerToe ? 0.116 : 0.106)
                    rotation: fannedAngle + 90

                    // Retractable Claw
                    Shape {
                        id: toeClaw
                        visible: root.clawExtend > 0.02
                        preferredRendererType: Shape.CurveRenderer
                        width: root.s * 0.040
                        height: root.s * (toeItem.isInnerToe ? 0.068 : 0.056) * root.clawExtend
                        x: (parent.width - width) / 2
                        y: -height + 2
                        z: -1

                        ShapePath {
                            strokeColor: Qt.alpha(Colours.palette.m3onPrimaryContainer, 0.50)
                            strokeWidth: 0.95
                            fillColor: Qt.lighter(Colours.palette.m3surface, 1.90)
                            capStyle: ShapePath.RoundCap
                            startX: 0
                            startY: toeClaw.height
                            PathCubic {
                                x: toeClaw.width * 0.5
                                y: 0
                                control1X: toeClaw.width * 0.10
                                control1Y: toeClaw.height * 0.35
                                control2X: toeClaw.width * 0.28
                                control2Y: 0
                            }
                            PathCubic {
                                x: toeClaw.width
                                y: toeClaw.height
                                control1X: toeClaw.width * 0.72
                                control1Y: 0
                                control2X: toeClaw.width * 0.90
                                control2Y: toeClaw.height * 0.35
                            }
                        }
                    }

                    // Toe Fur Knuckle & Digital Cushion Bean
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: root.furBottom
                        border.width: 1.15
                        border.color: root.furOutline

                        Rectangle {
                            width: parent.width * 0.66
                            height: parent.height * 0.64
                            radius: width / 2
                            anchors.centerIn: parent
                            color: root.beanColor

                            Rectangle {
                                width: parent.width * 0.30
                                height: width
                                radius: width / 2
                                x: parent.width * 0.20
                                y: parent.height * 0.16
                                color: Qt.lighter(Colours.palette.m3error, 1.45)
                                opacity: 0.72
                            }
                        }
                    }
                }
            }

            // Curved Hook Slash Swoosh Trail on Strike
            Shape {
                id: swooshArc
                visible: root.slashSwoosh > 0.02
                opacity: root.slashSwoosh * 0.85
                preferredRendererType: Shape.CurveRenderer
                width: root.s * 0.42
                height: root.s * 0.28
                x: -width * 0.18
                y: -height * 0.5
                z: 2

                ShapePath {
                    strokeColor: Qt.alpha(Colours.palette.m3primary, 0.75)
                    strokeWidth: 2.2
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: 0
                    startY: swooshArc.height * 0.85
                    PathCubic {
                        x: swooshArc.width
                        y: swooshArc.height * 0.15
                        control1X: swooshArc.width * 0.38
                        control1Y: -swooshArc.height * 0.08
                        control2X: swooshArc.width * 0.78
                        control2Y: 0
                    }
                }
            }
        }
    }

    // Affectionate Floating Purr / Heart Notes
    Repeater {
        model: 2
        Text {
            id: purrNote
            required property int index
            readonly property bool activePurr: root.mood === "pet" || root.mood === "knead"
            readonly property real baseX: root.headBaseX + root.s * (index === 0 ? 0.08 : 0.88)
            readonly property real baseY: root.headBaseY + root.headDY - root.s * 0.06
            visible: activePurr && opacity > 0.01
            z: 4
            text: index === 0 ? "♥" : "♪"
            color: index === 0 ? Qt.alpha(Colours.palette.m3error, 0.85) : Colours.palette.m3primary
            font.family: Tokens.font.family.sans
            font.pixelSize: Math.max(10, root.s * 0.22)
            font.weight: Font.Bold
            opacity: 0
            x: baseX
            y: baseY

            SequentialAnimation {
                running: purrNote.activePurr && root.running
                loops: Animation.Infinite
                PauseAnimation { duration: purrNote.index * 750 }
                ParallelAnimation {
                    NumberAnimation { target: purrNote; property: "y"; from: purrNote.baseY; to: purrNote.baseY - root.s * 0.32; duration: 1500; easing.type: Easing.OutSine }
                    NumberAnimation { target: purrNote; property: "x"; from: purrNote.baseX; to: purrNote.baseX + (purrNote.index === 0 ? -1 : 1) * root.s * 0.10; duration: 1500; easing.type: Easing.InOutSine }
                    SequentialAnimation {
                        NumberAnimation { target: purrNote; property: "opacity"; to: 0.90; duration: 350 }
                        NumberAnimation { target: purrNote; property: "opacity"; to: 0; duration: 1150 }
                    }
                }
            }
        }
    }

    // Sleeping "z"s
    Repeater {
        model: 2
        Text {
            id: zed
            required property int index
            readonly property real baseX: root.headBaseX + root.s * (0.90 + index * 0.12)
            readonly property real baseY: root.headBaseY + root.headDY - root.s * 0.05 - index * root.s * 0.10
            visible: root.asleep && opacity > 0.01
            z: 4
            text: "z"
            color: Colours.palette.m3onPrimaryContainer
            font.family: Tokens.font.family.sans
            font.pixelSize: Math.max(9, root.s * (0.20 + index * 0.06))
            font.weight: Font.Bold
            opacity: 0
            x: baseX
            y: baseY

            SequentialAnimation {
                running: root.asleep && root.running
                loops: Animation.Infinite
                PauseAnimation { duration: zed.index * 1300 }
                ParallelAnimation {
                    NumberAnimation { target: zed; property: "y"; from: zed.baseY; to: zed.baseY - root.s * 0.35; duration: 2800; easing.type: Easing.OutSine }
                    NumberAnimation { target: zed; property: "x"; from: zed.baseX; to: zed.baseX + root.s * 0.12; duration: 2800; easing.type: Easing.InOutSine }
                    SequentialAnimation {
                        NumberAnimation { target: zed; property: "opacity"; to: 0.85; duration: 600 }
                        NumberAnimation { target: zed; property: "opacity"; to: 0; duration: 2200 }
                    }
                }
            }
        }
    }
}