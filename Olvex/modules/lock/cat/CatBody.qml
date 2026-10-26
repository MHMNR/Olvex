import QtQuick
import QtQuick.Shapes
import Olvex.Config
import qs.services

// GPU Curve-Shader & Procedurally Articulated Feline Body:
// - Seamless Joint Blending (Upper shoulder & thigh merge into torso without internal seam lines)
// - Removed internal haunch crease line & bottom pill shadows
// - 2.5D Volumetric Gradients (Dorsal highlight to ventral ambient occlusion)
// - Velocity-Synced 4-Beat Lateral Digitigrade Gait with Zero Ground Slip
Item {
    id: root

    required property real s
    required property color fur
    required property color furOutline

    property string mood: "watch"
    property real facing: 1          // Target facing: 1 = right, -1 = left
    property real facingSmooth: 1    // Continuous -1..1 for smooth 3D body turn
    property bool isWalking: false
    property real walkPhase: 0
    property real walkSpeedNorm: 0   // 0..1 instantaneous normalized velocity
    property real standRatio: 0      // 0 = sitting loaf, 1 = quadruped stance
    property real anticip: 0         // 0..1 crouch coil before pounce
    property real lunge: 0           // 0..1 explosive pounce extension
    property real breath: 0          // 0..1 diaphragmatic breathing
    property real wiggle: 0          // -1..1 pre-pounce pelvic calibration wiggle
    property real reach: 0           // paw swat reach
    property bool pawLeft: false     // which front paw is swatting
    property real feetSpread: 0.20   // sitting paws spread
    property bool hunting: false     // stalking mode
    property real bsx: 1
    property real bsy: 1

    // Interactive & procedural channels
    property real kneadPhase: 0      // 0..1 alternating biscuit-making phase
    property real scratchPhase: 0    // 0..1 hind-leg ear scratch oscillation
    property real spineTurnBend: 0   // Lateral spine bend when turning

    // Smooth postural morph weights (0..1)
    property real stretchAmt: mood === "stretch" ? 1.0 : 0.0
    Behavior on stretchAmt { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }

    property real sulkAmt: mood === "sulk" ? 1.0 : 0.0
    Behavior on sulkAmt { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    property real startleAmt: mood === "startle" ? 1.0 : 0.0
    Behavior on startleAmt { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

    property real petAmt: (mood === "pet" || mood === "knead") ? 1.0 : 0.0
    Behavior on petAmt { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    property real sleepAmt: (mood === "sleep" || mood === "stir") ? 1.0 : (mood === "drowsy" ? 0.45 : 0.0)
    Behavior on sleepAmt { NumberAnimation { duration: 480; easing.type: Easing.InOutSine } }

    // Palette & Volumetric Shading Colors
    readonly property color furTop: Qt.lighter(fur, 1.07)
    readonly property color furBottom: Qt.darker(fur, 1.12)
    readonly property color furDark: Qt.darker(fur, 1.20)
    readonly property color furDeepAO: Qt.darker(fur, 1.32)
    readonly property color furLight: Qt.lighter(fur, 1.22)
    readonly property color furStripe: Qt.alpha(Colours.palette.m3primary, 0.46)
    readonly property color beanColor: Qt.alpha(Colours.palette.m3error, 0.76)

    readonly property real bodyW: s * 1.30
    readonly property real bodyH: s * 0.80

    width: bodyW
    height: bodyH

    // ── Velocity-Locked 4-Beat Lateral Sequence Digitigrade Gait ────────────
    // Returns Qt.vector4d(footX, footY, midJointX, pawPitchDeg)
    function calcLimbKinematics(phaseOffset, isHind) {
        if (!root.isWalking && root.standRatio < 0.05) {
            return Qt.vector4d(0, 0, 0, 0);
        }

        const p = ((root.walkPhase + phaseOffset) % 1.0 + 1.0) % 1.0;
        const activeAmp = root.isWalking ? Math.max(0.25, Math.min(1.0, root.walkSpeedNorm * 1.15)) : 0.0;
        const stride = root.s * (root.hunting ? 0.24 : 0.20) * activeAmp;
        const maxLift = root.s * (root.hunting ? 0.08 : 0.14) * activeAmp;
        const dir = root.facingSmooth;

        let fx = 0;
        let fy = 0;
        let pitch = 0;

        // Pounce anticipation & lunge hind-leg spring propulsion
        if (root.anticip > 0.01 || root.lunge > 0.01) {
            if (isHind) {
                fx = -dir * root.s * (0.08 * root.anticip + 0.16 * root.lunge);
                fy = 0;
                const hockBack = fx - dir * root.s * (0.08 + 0.04 * root.anticip);
                return Qt.vector4d(fx, fy, hockBack, 10 * dir * root.lunge);
            } else {
                fx = dir * root.s * (0.05 * root.anticip - 0.04 * root.lunge);
                fy = 0;
                return Qt.vector4d(fx, fy, fx * 0.45, 0);
            }
        }

        // Anterior bow stretch: forelimbs reach far forward, hindlimbs brace back
        if (root.stretchAmt > 0.01) {
            if (!isHind) {
                fx = dir * root.s * 0.27 * root.stretchAmt;
                return Qt.vector4d(fx, 0, fx * 0.44, -12 * dir * root.stretchAmt);
            } else {
                fx = -dir * root.s * 0.09 * root.stretchAmt;
                return Qt.vector4d(fx, 0, fx - dir * root.s * 0.065, 0);
            }
        }

        // Startle wide stance brace
        if (root.startleAmt > 0.01) {
            fx = (isHind ? -1 : 1) * dir * root.s * 0.08 * root.startleAmt;
            fy = -root.s * 0.035 * root.startleAmt;
            return Qt.vector4d(fx, fy, fx * 0.5, 0);
        }

        if (p < 0.40) {
            // SWING PHASE: Paw peels off ground, flexes wrist/hock, arcs forward
            const t = p / 0.40;
            const smoothT = 0.5 - 0.5 * Math.cos(t * Math.PI);
            fx = (-stride + smoothT * 2.0 * stride) * dir;
            fy = -Math.pow(Math.sin(t * Math.PI), 0.80) * maxLift;
            pitch = Math.sin(Math.min(1.0, t * 1.15) * Math.PI) * (isHind ? -28 : 32) * dir;
        } else {
            // STANCE PHASE: Linear backward translation matching forward body velocity
            const t = (p - 0.40) / 0.60;
            fx = (stride - t * 2.0 * stride) * dir;
            fy = 0;
            pitch = 0;
        }

        const anatomicalBend = (isHind ? -root.s * 0.075 : -root.s * 0.030) * dir;
        const swingLead = fy < 0 ? dir * root.s * (isHind ? 0.020 : 0.045) : 0;
        const jx = fx * 0.54 + anatomicalBend + swingLead;

        return Qt.vector4d(fx, fy, jx, pitch);
    }

    readonly property vector4d limbNearHind:  calcLimbKinematics(0.00, true)
    readonly property vector4d limbNearFront: calcLimbKinematics(0.23, false)
    readonly property vector4d limbFarHind:   calcLimbKinematics(0.50, true)
    readonly property vector4d limbFarFront:  calcLimbKinematics(0.73, false)

    // ── Spinal Biomechanics & Scapular/Pelvic Oscillation ───────────────────
    readonly property real stalkDrop: (root.hunting ? root.s * 0.105 : 0)
                                    + root.anticip * root.s * 0.145
                                    + root.stretchAmt * root.s * 0.11
                                    - root.startleAmt * root.s * 0.08
                                    - root.lunge * root.s * 0.03

    readonly property real scapulaBob: root.isWalking
        ? Math.sin((root.walkPhase * 2.0 + 0.15) * Math.PI * 2) * root.s * 0.028 * Math.min(1.0, root.walkSpeedNorm + 0.25)
        : 0
    readonly property real pelvisBob: (root.isWalking
        ? Math.sin((root.walkPhase * 2.0 - 0.25) * Math.PI * 2) * root.s * 0.024 * Math.min(1.0, root.walkSpeedNorm + 0.25)
        : 0) + root.wiggle * root.s * 0.022

    readonly property real spineFlexY: (scapulaBob + pelvisBob) * 0.5
    readonly property real spinePitch: root.isWalking
        ? (scapulaBob - pelvisBob) * 16.0 * root.facingSmooth / Math.max(1, root.s)
        : (root.stretchAmt * 8.5 * root.facingSmooth
           - root.anticip * 4.5 * root.facingSmooth
           + root.lunge * 3.0 * root.facingSmooth
           - root.petAmt * 2.8 * root.facingSmooth)

    readonly property real shoulderRatioX: 0.50 + root.facingSmooth * 0.19
    readonly property real hipRatioX:      0.50 - root.facingSmooth * 0.27
    readonly property real farOffsetX:     root.facingSmooth * root.s * 0.055

    // ── Seamless Anatomical Digitigrade Limb Component ──────────────────────
    component FelineLimb: Item {
        id: limb
        property real anchorX: 0
        property real anchorY: 0
        property vector4d kin: Qt.vector4d(0, 0, 0, 0)
        property bool isHind: false
        property bool isFar: false

        readonly property real upperW: root.s * (isHind ? 0.235 : 0.185)
        readonly property real lowerW: root.s * (isHind ? 0.132 : 0.128)
        readonly property real footX: anchorX + kin.x
        readonly property real footY: root.height - root.s * 0.065 + kin.y
        readonly property real jointX: anchorX + kin.z
        readonly property real jointY: (anchorY + footY) * (isHind ? 0.56 : 0.50) + (kin.y * 0.22)
        readonly property real stifleX: anchorX + (root.facingSmooth * upperW * 0.52) + kin.x * 0.25
        readonly property real stifleY: anchorY + (footY - anchorY) * 0.34

        anchors.fill: parent

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            // 1. Volumetric Gradient Fill Pass
            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: limb.anchorX
                    y1: limb.anchorY
                    x2: limb.footX
                    y2: limb.footY
                    GradientStop { position: 0.0; color: limb.isFar ? root.furDeepAO : root.fur }
                    GradientStop { position: 0.45; color: limb.isFar ? root.furDark : root.fur }
                    GradientStop { position: 1.0; color: limb.isFar ? root.furDark : root.furBottom }
                }

                startX: limb.anchorX - root.facingSmooth * limb.upperW * 0.48
                startY: limb.anchorY
                PathQuad {
                    controlX: limb.jointX - root.facingSmooth * limb.lowerW * 0.58
                    controlY: limb.jointY
                    x: limb.footX - root.facingSmooth * limb.lowerW * 0.44
                    y: limb.footY
                }
                PathLine {
                    x: limb.footX + root.facingSmooth * limb.lowerW * 0.48
                    y: limb.footY
                }
                PathCubic {
                    control1X: limb.jointX + root.facingSmooth * limb.lowerW * 0.52
                    control1Y: limb.jointY + (limb.isHind ? -root.s * 0.03 : 0)
                    control2X: limb.isHind ? limb.stifleX : (limb.anchorX + root.facingSmooth * limb.upperW * 0.48)
                    control2Y: limb.isHind ? limb.stifleY : (limb.anchorY + root.s * 0.06)
                    x: limb.anchorX + root.facingSmooth * limb.upperW * 0.48
                    y: limb.anchorY
                }
            }

            // 2. Open-Top Outline Pass (Blends seamlessly into torso)
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.furOutline
                strokeWidth: 1.4
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.RoundCap

                startX: limb.anchorX - root.facingSmooth * limb.upperW * 0.48
                startY: limb.anchorY + root.s * 0.05
                PathQuad {
                    controlX: limb.jointX - root.facingSmooth * limb.lowerW * 0.58
                    controlY: limb.jointY
                    x: limb.footX - root.facingSmooth * limb.lowerW * 0.44
                    y: limb.footY
                }
                PathLine {
                    x: limb.footX + root.facingSmooth * limb.lowerW * 0.48
                    y: limb.footY
                }
                PathCubic {
                    control1X: limb.jointX + root.facingSmooth * limb.lowerW * 0.52
                    control1Y: limb.jointY + (limb.isHind ? -root.s * 0.03 : 0)
                    control2X: limb.isHind ? limb.stifleX : (limb.anchorX + root.facingSmooth * limb.upperW * 0.48)
                    control2Y: limb.isHind ? limb.stifleY : (limb.anchorY + root.s * 0.06)
                    x: limb.anchorX + root.facingSmooth * limb.upperW * 0.48
                    y: limb.anchorY + root.s * 0.05
                }
            }
        }

        // Articulated Digitigrade Paw Pad
        Item {
            width: root.s * (limb.isFar ? 0.21 : 0.235)
            height: root.s * 0.135
            x: limb.footX - width * 0.48 + root.facingSmooth * root.s * 0.025
            y: limb.footY - height * 0.46
            rotation: limb.kin.w

            Rectangle {
                anchors.fill: parent
                radius: height * 0.48
                color: limb.isFar ? root.furDark : root.furBottom
                border.width: 1.25
                border.color: root.furOutline

                Repeater {
                    model: limb.isFar ? 0 : 2
                    Rectangle {
                        required property int index
                        width: 1.1
                        height: parent.height * 0.44
                        radius: 0.5
                        color: Qt.alpha(root.furOutline, 0.65)
                        x: parent.width * (root.facingSmooth >= 0 ? (0.42 + index * 0.24) : (0.34 + index * 0.24))
                        y: parent.height - height - 1
                    }
                }

                Rectangle {
                    visible: !limb.isFar && limb.kin.y < -root.s * 0.022
                    width: parent.width * 0.48
                    height: parent.height * 0.38
                    radius: height / 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    color: root.beanColor
                }
            }
        }
    }

    // ── 1. FAR LIMBS (Behind torso when standing/walking) ───────────────────
    Item {
        id: farLimbs
        anchors.fill: parent
        z: 0
        visible: root.standRatio > 0.04
        opacity: root.standRatio

        FelineLimb {
            isHind: true
            isFar: true
            anchorX: parent.width * root.hipRatioX + root.farOffsetX
            anchorY: parent.height * 0.48 + root.stalkDrop * 0.45 + root.pelvisBob
            kin: root.limbFarHind
        }

        FelineLimb {
            isHind: false
            isFar: true
            anchorX: parent.width * root.shoulderRatioX + root.farOffsetX
            anchorY: parent.height * 0.50 + root.stalkDrop + root.scapulaBob
            kin: root.limbFarFront
            visible: !(root.reach > 0.02 && ((root.facingSmooth >= 0 && !root.pawLeft) || (root.facingSmooth < 0 && root.pawLeft)))
        }
    }

    // ── 2. VOLUMETRIC ARTICULATED TORSO ─────────────────────────────────────
    Item {
        id: torso
        anchors.fill: parent
        z: 1

        y: root.stalkDrop * 0.65 + root.spineFlexY
        rotation: root.spinePitch + root.wiggle * 2.2

        readonly property real turnForeshorten: 1.0 - (1.0 - Math.abs(root.facingSmooth)) * 0.14 * root.standRatio

        transform: Scale {
            origin.x: torso.width * 0.5
            origin.y: torso.height
            xScale: root.bsx * torso.turnForeshorten * (1.0 + 0.016 * root.breath) * (1.0 + 0.06 * root.anticip + 0.18 * root.lunge) * (1.0 + 0.08 * root.standRatio)
            yScale: root.bsy * (1.0 + 0.028 * root.breath) * (1.0 - 0.12 * root.anticip - 0.07 * root.lunge) * (1.0 - 0.05 * root.standRatio)
        }

        readonly property real topYBase: height * (0.06 + 0.05 * root.standRatio + 0.09 * root.sleepAmt)
        readonly property real dorsalArchY: topYBase
            - root.sulkAmt * height * 0.16
            - root.startleAmt * height * 0.26
            - root.petAmt * height * 0.09
            + root.stretchAmt * height * 0.21
            + root.anticip * height * 0.05
            - root.lunge * height * 0.06
            - root.breath * height * 0.026

        readonly property real croupY: topYBase - (root.stretchAmt + root.petAmt * 0.4) * height * 0.09 + root.pelvisBob
        readonly property real scapulaY: topYBase + root.stretchAmt * height * 0.11 - (root.hunting ? height * 0.03 : 0) + root.scapulaBob

        readonly property real leftTopY:  root.facingSmooth >= 0 ? croupY : scapulaY
        readonly property real rightTopY: root.facingSmooth >= 0 ? scapulaY : croupY
        readonly property real bellyY: height * (0.98 - 0.15 * root.standRatio - 0.08 * root.startleAmt + 0.02 * root.sleepAmt + 0.03 * root.breath)

        readonly property real spikeH: root.s * 0.095 * root.startleAmt
        readonly property real ruffCenterX: width * (0.50 + root.facingSmooth * 0.12 * root.standRatio)
        readonly property real ruffHalfW: width * (0.23 - 0.04 * root.standRatio)
        readonly property real ruffTopY: height * (0.34 + 0.08 * root.standRatio)
        readonly property real ruffBotY: bellyY - 2
        readonly property real ruffMidY: (ruffTopY + ruffBotY) * 0.52
        readonly property real neckX: width * (0.50 + root.facingSmooth * 0.18 * root.standRatio)
        readonly property real neckW: width * 0.22

        Shape {
            id: bodyShape
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            // Main Torso Silhouette
            ShapePath {
                strokeColor: root.furOutline
                strokeWidth: 1.6
                joinStyle: ShapePath.RoundJoin
                fillGradient: LinearGradient {
                    x1: torso.width * 0.5
                    y1: torso.dorsalArchY
                    x2: torso.width * 0.5
                    y2: torso.bellyY
                    GradientStop { position: 0.0; color: root.furTop }
                    GradientStop { position: 0.62; color: root.fur }
                    GradientStop { position: 1.0; color: root.furBottom }
                }

                startX: torso.width * 0.12
                startY: torso.height * 0.54

                PathCubic {
                    control1X: torso.width * 0.10
                    control1Y: torso.leftTopY + torso.height * 0.08
                    control2X: torso.width * 0.26
                    control2Y: torso.leftTopY
                    x: torso.width * 0.50 + root.spineTurnBend * root.s * 0.08
                    y: torso.dorsalArchY
                }

                PathCubic {
                    control1X: torso.width * 0.74
                    control1Y: torso.rightTopY
                    control2X: torso.width * 0.90
                    control2Y: torso.rightTopY + torso.height * 0.08
                    x: torso.width * 0.88
                    y: torso.height * 0.54
                }

                PathCubic {
                    control1X: torso.width * 0.90
                    control1Y: torso.height * 0.86
                    control2X: torso.width * 0.75
                    control2Y: torso.bellyY
                    x: torso.width * 0.50
                    y: torso.bellyY
                }

                PathCubic {
                    control1X: torso.width * 0.25
                    control1Y: torso.bellyY
                    control2X: torso.width * 0.10
                    control2Y: torso.height * 0.86
                    x: torso.width * 0.12
                    y: torso.height * 0.54
                }
            }

            // Bristled Dorsal Fur Spikes (Piloerection during Startle)
            ShapePath {
                strokeColor: root.startleAmt > 0.05 ? root.furOutline : "transparent"
                strokeWidth: 1.3
                fillColor: root.startleAmt > 0.05 ? root.furTop : "transparent"
                joinStyle: ShapePath.RoundJoin

                startX: torso.width * 0.34
                startY: torso.dorsalArchY + root.s * 0.03
                PathLine { x: torso.width * 0.39; y: torso.dorsalArchY - torso.spikeH }
                PathLine { x: torso.width * 0.44; y: torso.dorsalArchY + root.s * 0.01 }
                PathLine { x: torso.width * 0.50; y: torso.dorsalArchY - torso.spikeH * 1.25 }
                PathLine { x: torso.width * 0.56; y: torso.dorsalArchY + root.s * 0.01 }
                PathLine { x: torso.width * 0.61; y: torso.dorsalArchY - torso.spikeH }
                PathLine { x: torso.width * 0.66; y: torso.dorsalArchY + root.s * 0.03 }
            }

            // Plush Cream Chest Ruff & Underbelly Patch
            ShapePath {
                fillColor: Qt.alpha(root.furLight, 0.85)
                strokeColor: "transparent"

                startX: torso.ruffCenterX - torso.ruffHalfW
                startY: torso.ruffMidY

                PathCubic {
                    control1X: torso.ruffCenterX - torso.ruffHalfW * 0.85
                    control1Y: torso.ruffTopY
                    control2X: torso.ruffCenterX + torso.ruffHalfW * 0.85
                    control2Y: torso.ruffTopY
                    x: torso.ruffCenterX + torso.ruffHalfW
                    y: torso.ruffMidY
                }
                PathCubic {
                    control1X: torso.ruffCenterX + torso.ruffHalfW * 0.90
                    control1Y: torso.ruffBotY
                    control2X: torso.ruffCenterX - torso.ruffHalfW * 0.90
                    control2Y: torso.ruffBotY
                    x: torso.ruffCenterX - torso.ruffHalfW
                    y: torso.ruffMidY
                }
            }

            // Soft Chin / Neck Ambient Occlusion Shadow on Upper Chest
            ShapePath {
                fillColor: Qt.alpha(root.furDeepAO, 0.22)
                strokeColor: "transparent"

                startX: torso.neckX - torso.neckW
                startY: torso.height * 0.24
                PathQuad {
                    controlX: torso.neckX
                    controlY: torso.height * 0.44
                    x: torso.neckX + torso.neckW
                    y: torso.height * 0.24
                }
                PathQuad {
                    controlX: torso.neckX
                    controlY: torso.height * 0.14
                    x: torso.neckX - torso.neckW
                    y: torso.height * 0.24
                }
            }
        }

        // 3 Dorsal Tabby Stripes
        Repeater {
            model: 3
            Rectangle {
                required property int index
                width: Math.max(2.2, root.s * 0.042)
                height: root.s * (index === 1 ? 0.15 : 0.12)
                radius: width / 2
                color: root.furStripe
                x: torso.width * (0.50 + (index - 1) * 0.16 - root.facingSmooth * 0.05 * root.standRatio) - width / 2
                y: torso.dorsalArchY + root.s * 0.02 + Math.abs(index - 1) * root.s * 0.018
                rotation: (index - 1) * 9 * (root.standRatio > 0.3 ? root.facingSmooth : 1)
            }
        }
    }

    // ── 3. NEAR LIMBS, SITTING PAWS, KNEADING & EAR-SCRATCHING (Foreground) ─
    Item {
        id: nearPaws
        anchors.fill: parent
        z: 2

        // A. SITTING / LOAFING / KNEADING FRONT PAWS
        Item {
            anchors.fill: parent
            opacity: Math.max(0.0, 1.0 - root.standRatio * 1.35)
            visible: opacity > 0.02 && root.sleepAmt < 0.85

            Repeater {
                model: 2
                Item {
                    required property int index
                    readonly property real kneadLift: (root.mood === "pet" || root.mood === "knead")
                        ? Math.max(0, Math.sin((root.kneadPhase + index * 0.5) * Math.PI * 2)) * root.s * 0.075
                        : 0
                    readonly property real kneadScaleX: 1.0 + (kneadLift / (root.s * 0.075 + 0.001)) * 0.14

                    width: root.s * 0.25 * kneadScaleX
                    height: root.s * 0.155
                    x: parent.width * 0.5 + (index === 0 ? -1 : 1) * root.s * root.feetSpread - width / 2
                    y: parent.height - height + 1 - kneadLift
                    rotation: (index === 0 ? -1 : 1) * (kneadLift / (root.s * 0.075 + 0.001)) * 8
                    visible: !(root.reach > 0.02 && ((index === 0 && root.pawLeft) || (index === 1 && !root.pawLeft)))

                    Rectangle {
                        anchors.fill: parent
                        radius: height * 0.48
                        color: root.fur
                        border.width: 1.25
                        border.color: root.furOutline

                        Repeater {
                            model: 2
                            Rectangle {
                                required property int index
                                width: 1.15
                                height: parent.height * 0.44
                                radius: 0.5
                                color: Qt.alpha(root.furOutline, 0.65)
                                x: parent.width * (0.35 + index * 0.30)
                                y: parent.height - height - 1
                            }
                        }
                    }
                }
            }
        }

        // B. HIND-LEG EAR SCRATCHING PAW
        Item {
            id: scratchHindLeg
            visible: root.mood === "scratch"
            x: parent.width * 0.64
            y: parent.height * 0.12 + Math.sin(root.scratchPhase * Math.PI * 8) * root.s * 0.055
            width: root.s * 0.32
            height: root.s * 0.15
            rotation: -42 + Math.sin(root.scratchPhase * Math.PI * 8) * 16

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: root.fur
                border.width: 1.25
                border.color: root.furOutline

                Rectangle {
                    width: parent.width * 0.36
                    height: parent.height * 0.56
                    radius: height / 2
                    anchors.right: parent.right
                    anchors.rightMargin: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.beanColor
                }
            }
        }

        // C. SEAMLESS JOINTED QUADRUPED NEAR LIMBS
        Item {
            anchors.fill: parent
            opacity: Math.min(1.0, root.standRatio * 1.25)
            visible: opacity > 0.02

            FelineLimb {
                isHind: true
                isFar: false
                anchorX: parent.width * root.hipRatioX
                anchorY: parent.height * 0.48 + root.stalkDrop * 0.45 + root.pelvisBob
                kin: root.limbNearHind
            }

            FelineLimb {
                isHind: false
                isFar: false
                anchorX: parent.width * root.shoulderRatioX
                anchorY: parent.height * 0.50 + root.stalkDrop + root.scapulaBob
                kin: root.limbNearFront
                visible: !(root.reach > 0.02 && ((root.facingSmooth >= 0 && root.pawLeft) || (root.facingSmooth < 0 && !root.pawLeft)))
            }
        }
    }
}