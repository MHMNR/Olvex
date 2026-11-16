import QtQuick
import QtQuick.Shapes
import Olvex.Config
import qs.services

// GPU Curve-Shader & Volumetric Feline Head with NaN-Proof Stereoscopic Eye Tracking:
// - Full-Range Spherical Eyeball Iris & Pupil Tracking (Crisp cursor lock)
// - True Pointed Feline Vertical Spindle Slit-to-Round Pupil (`ShapePath` Cubic Spindle)
// - Curved Emotional Eyelids & Happy Crescent Squint (`^ ^`)
// - Diagonal Nictitating Membrane (3rd Eyelid)
// - Independent 180-Degree Pinna Ear Swivel & Concha Foreshortening
// - Sniffing Rhinarium, "Ekekek" Prey Jaw Chatter, & Grooming Tongue
Item {
    id: root

    required property real size

    property real lookX: 0
    property real lookY: 0
    property real lookXL: 0
    property real lookXR: 0
    property real lookYL: 0
    property real lookYR: 0
    property real lidL: 0
    property real lidR: 0
    property real lowerLid: 0
    property real eyeScale: 1
    property real pupilScale: 1
    property real earL: 0
    property real earR: 0
    property real mouthOpen: 0
    property real blush: 0.22
    property real headYaw: 0
    property real whiskerForward: 0

    // Expressive & Anatomical Channels
    property real happySquint: 0     // 0..1 happy arched eyes (`^ ^`)
    property real sniffPhase: 0      // 0..1 rapid nose twitch & whisker puff
    property real chatterPhase: 0    // 0..1 rapid "ekekek" prey jaw chatter
    property real groomLick: 0       // 0..1 pink tongue peeking out while washing
    property real pupilHippus: 0     // -1..1 subtle micro-pulsation of pupil

    function safeVal(v, defVal) {
        return Number.isFinite(v) ? v : defVal;
    }

    readonly property real safeYaw: safeVal(headYaw, 0)
    readonly property real headH: size * 0.84
    readonly property real parallaxFaceX: safeYaw * size * 0.052
    readonly property real parallaxMuzzleX: safeYaw * size * 0.074
    readonly property real parallaxEarX: -safeYaw * size * 0.030

    readonly property color fur: Colours.palette.m3primaryContainer
    readonly property color furTop: Qt.lighter(fur, 1.08)
    readonly property color furBottom: Qt.darker(fur, 1.10)
    readonly property color furLight: Qt.lighter(fur, 1.20)
    readonly property color outline: Qt.alpha(Colours.palette.m3onPrimaryContainer, 0.38)
    readonly property color stripe: Qt.alpha(Colours.palette.m3primary, 0.50)
    readonly property color eyeDark: Qt.darker(Colours.palette.m3tertiary, 2.8)
    readonly property color iris: Colours.palette.m3tertiary
    readonly property color sclera: Qt.tint("#ffffff", Qt.alpha(Colours.palette.m3surface, 0.06))
    readonly property color highlight: Qt.lighter(Colours.palette.m3tertiaryContainer, 2.4)
    readonly property color noseColor: Qt.alpha(Colours.palette.m3error, 0.86)
    readonly property color innerEar: Qt.alpha(Colours.palette.m3tertiary, 0.48)
    readonly property color mouthColor: Qt.alpha(Colours.palette.m3onPrimaryContainer, 0.68)

    implicitWidth: size
    implicitHeight: headH
    width: implicitWidth
    height: implicitHeight

    // ── Anatomical Feline Pinna (Curved Ear with Volumetric Concha) ─────────
    component Ear: Item {
        required property Item cat
        id: ear
        property real tilt: 0
        property bool mirrored: false
        readonly property real safeTilt: Number.isFinite(tilt) ? tilt : 0
        readonly property real swivelFactor: Math.max(0.52, 1.0 - Math.abs(safeTilt) / 55.0)

        width: cat.size * 0.38
        height: cat.size * 0.43
        transformOrigin: Item.Bottom
        rotation: safeTilt

        Item {
            anchors.fill: parent
            transform: Scale {
                origin.x: ear.width / 2
                xScale: ear.mirrored ? -1 : 1
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                // Outer Pinna Shell
                ShapePath {
                    strokeColor: cat.outline
                    strokeWidth: 1.5
                    joinStyle: ShapePath.RoundJoin
                    fillGradient: LinearGradient {
                        x1: ear.width * 0.2
                        y1: 0
                        x2: ear.width * 0.5
                        y2: ear.height
                        GradientStop { position: 0.0; color: cat.furTop }
                        GradientStop { position: 1.0; color: cat.fur }
                    }
                    startX: ear.width * 0.02
                    startY: ear.height
                    PathCubic {
                        control1X: -ear.width * 0.02
                        control1Y: ear.height * 0.48
                        control2X: ear.width * 0.08
                        control2Y: ear.height * 0.06
                        x: ear.width * 0.22
                        y: ear.height * 0.02
                    }
                    PathCubic {
                        control1X: ear.width * 0.36
                        control1Y: -ear.height * 0.02
                        control2X: ear.width * 0.82
                        control2Y: ear.height * 0.38
                        x: ear.width * 0.98
                        y: ear.height * 0.80
                    }
                    PathLine { x: ear.width * 0.02; y: ear.height }
                }

                // Inner Pinna Concha
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: ear.width * 0.25
                        y1: ear.height * 0.18
                        x2: ear.width * 0.45
                        y2: ear.height * 0.88
                        GradientStop { position: 0.0; color: cat.innerEar }
                        GradientStop { position: 1.0; color: Qt.darker(cat.innerEar, 1.35) }
                    }
                    startX: ear.width * 0.16
                    startY: ear.height * 0.88
                    PathCubic {
                        control1X: ear.width * 0.14
                        control1Y: ear.height * 0.52
                        control2X: ear.width * 0.19
                        control2Y: ear.height * 0.22
                        x: ear.width * 0.27
                        y: ear.height * 0.18
                    }
                    PathCubic {
                        control1X: ear.width * 0.36
                        control1Y: ear.height * 0.16
                        control2X: ear.width * (0.28 + 0.38 * ear.swivelFactor)
                        control2Y: ear.height * 0.48
                        x: ear.width * (0.34 + 0.40 * ear.swivelFactor)
                        y: ear.height * 0.78
                    }
                    PathLine { x: ear.width * 0.16; y: ear.height * 0.88 }
                }

                // Fluffy Inner Tragus Ear Tuft
                ShapePath {
                    fillColor: cat.furLight
                    strokeColor: "transparent"
                    startX: ear.width * 0.14
                    startY: ear.height * 0.86
                    PathQuad {
                        controlX: ear.width * 0.36
                        controlY: ear.height * 0.66
                        x: ear.width * 0.48
                        y: ear.height * 0.74
                    }
                    PathQuad {
                        controlX: ear.width * 0.34
                        controlY: ear.height * 0.84
                        x: ear.width * 0.14
                        y: ear.height * 0.86
                    }
                }
            }
        }
    }

    // ── Glassy Feline Eye with Crisp Full-Range Spherical Gaze ──────────────
    component Eye: Item {
        required property Item cat
        id: eye
        property real lid: 0
        property real lx: 0
        property real ly: 0
        property bool isRight: false

        readonly property real ew: cat.size * 0.268 * cat.eyeScale
        readonly property real eh: cat.size * 0.332 * cat.eyeScale

        readonly property real slx: Number.isFinite(lx) ? lx : 0
        readonly property real sly: Number.isFinite(ly) ? ly : 0
        readonly property real gazeMag: Math.hypot(slx, sly)
        readonly property real normScale: gazeMag > 1.0 ? (1.0 / gazeMag) : 1.0
        readonly property real clx: slx * normScale
        readonly property real cly: sly * normScale

        width: ew
        height: eh

        // Sclera / Eyeball Base
        Rectangle {
            id: scleraRect
            anchors.fill: parent
            radius: width / 2
            color: cat.sclera
            border.width: Math.max(1.2, cat.size * 0.02)
            border.color: cat.eyeDark
        }

        // Iris + Limbal Ring + Pointed Feline Spindle Pupil
        Rectangle {
            id: irisRect
            width: eye.ew * 0.72
            height: eye.eh * 0.78
            radius: width / 2
            x: (eye.width - width) * 0.5 + eye.clx * eye.ew * 0.155
            y: (eye.height - height) * 0.5 + eye.cly * eye.eh * 0.135

            border.width: Math.max(1.1, width * 0.065)
            border.color: Qt.darker(cat.iris, 1.9)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.darker(cat.iris, 1.6) }
                GradientStop { position: 0.60; color: cat.iris }
                GradientStop { position: 1.0; color: Qt.lighter(cat.iris, 1.42) }
            }

            // True Feline Vertical Spindle Slit-to-Round Pupil
            Shape {
                id: pupilShape
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                readonly property real effectiveScale: cat.pupilScale + cat.pupilHippus * 0.04
                readonly property real dilation: Math.max(0.0, Math.min(1.0, (effectiveScale - 0.88) / 0.54))
                readonly property real halfH: height * (0.36 + 0.02 * dilation)
                readonly property real halfW: width * (0.09 + 0.30 * dilation)
                readonly property real cx: width * 0.5 + eye.clx * width * 0.12
                readonly property real cy: height * 0.5 + eye.cly * height * 0.11
                readonly property real ctrlSpreadY: halfH * (0.38 + 0.22 * dilation)

                ShapePath {
                    fillColor: cat.eyeDark
                    strokeColor: "transparent"
                    startX: pupilShape.cx
                    startY: pupilShape.cy - pupilShape.halfH

                    PathCubic {
                        control1X: pupilShape.cx + pupilShape.halfW
                        control1Y: pupilShape.cy - pupilShape.ctrlSpreadY
                        control2X: pupilShape.cx + pupilShape.halfW
                        control2Y: pupilShape.cy + pupilShape.ctrlSpreadY
                        x: pupilShape.cx
                        y: pupilShape.cy + pupilShape.halfH
                    }

                    PathCubic {
                        control1X: pupilShape.cx - pupilShape.halfW
                        control1Y: pupilShape.cy + pupilShape.ctrlSpreadY
                        control2X: pupilShape.cx - pupilShape.halfW
                        control2Y: pupilShape.cy - pupilShape.ctrlSpreadY
                        x: pupilShape.cx
                        y: pupilShape.cy - pupilShape.halfH
                    }
                }
            }

            // Primary Corneal Specular Highlight
            Rectangle {
                width: parent.width * 0.34
                height: width
                radius: width / 2
                color: cat.highlight
                x: parent.width * 0.14 + eye.clx * parent.width * 0.04
                y: parent.height * 0.09 + eye.cly * parent.height * 0.04
            }

            // Secondary Pinpoint Highlight
            Rectangle {
                width: parent.width * 0.15
                height: width
                radius: width / 2
                color: cat.highlight
                opacity: 0.85
                x: parent.width * 0.62
                y: parent.height * 0.64
            }
        }

        // Feline Nictitating Membrane (3rd Eyelid)
        Rectangle {
            readonly property real nictStrength: Math.max(0, Math.sin(eye.lid * Math.PI) * 0.55 + (eye.lid > 0.3 && eye.lid < 0.75 ? 0.25 : 0))
            visible: nictStrength > 0.04 && eye.lid < 0.92 && cat.happySquint < 0.3
            width: eye.width * 0.65 * nictStrength
            height: eye.height * 0.90
            radius: width * 0.4
            x: eye.isRight ? -2 : (eye.width - width + 2)
            y: eye.height * 0.10
            rotation: eye.isRight ? 18 : -18
            color: Qt.alpha(cat.sclera, 0.72)
        }

        // Upper Eyelid Mask
        Rectangle {
            x: -2
            y: -2
            width: eye.width + 4
            height: (eye.height + 4) * eye.lid
            color: cat.fur
            visible: eye.lid > 0.01
        }

        // Lower Eyelid Squint Mask
        Rectangle {
            readonly property real effLower: Math.max(cat.lowerLid, cat.happySquint * 0.68)
            x: -2
            y: eye.height - (eye.height + 2) * effLower
            width: eye.width + 4
            height: (eye.height + 4) * effLower
            radius: cat.happySquint > 0.2 ? width * 0.45 : 0
            color: cat.fur
            visible: effLower > 0.01
        }

        // Curved Upper Lash Line / Happy Crescent Arch (`^ ^`)
        Shape {
            id: lashShape
            visible: eye.lid > 0.10 || cat.happySquint > 0.25
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            readonly property real lashY: (eye.height + 2) * eye.lid - 2
            readonly property real archLift: cat.happySquint * eye.height * 0.32

            ShapePath {
                strokeColor: cat.eyeDark
                strokeWidth: Math.max(1.8, cat.size * 0.034)
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: eye.width * 0.05
                startY: lashShape.lashY + lashShape.archLift * 0.35
                PathQuad {
                    controlX: eye.width * 0.50
                    controlY: lashShape.lashY - lashShape.archLift
                    x: eye.width * 0.95
                    y: lashShape.lashY + lashShape.archLift * 0.35
                }
            }
        }
    }

    // ── Ears (Behind Cranium with Counter-Parallax) ─────────────────────────
    Ear {
        cat: root
        x: root.size * 0.02 + root.parallaxEarX
        y: -root.size * 0.19
        tilt: -root.earL
    }
    Ear {
        cat: root
        x: root.size * 0.60 + root.parallaxEarX
        y: -root.size * 0.19
        mirrored: true
        tilt: root.earR
    }

    // ── Volumetric Cranium & Cheek Ruff Silhouette ──────────────────────────
    Shape {
        id: headShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.outline
            strokeWidth: 1.5
            joinStyle: ShapePath.RoundJoin
            fillGradient: LinearGradient {
                x1: root.size * 0.5
                y1: 0
                x2: root.size * 0.5
                y2: root.headH
                GradientStop { position: 0.0; color: root.furTop }
                GradientStop { position: 0.68; color: root.fur }
                GradientStop { position: 1.0; color: root.furBottom }
            }

            startX: root.size * 0.50
            startY: 0

            PathCubic {
                control1X: root.size * 0.84
                control1Y: 0
                control2X: root.size * 0.98
                control2Y: root.headH * 0.25
                x: root.size * 0.99
                y: root.headH * 0.56
            }

            PathCubic {
                control1X: root.size * 1.04
                control1Y: root.headH * 0.76
                control2X: root.size * 0.82
                control2Y: root.headH * 1.0
                x: root.size * 0.50
                y: root.headH * 1.0
            }

            PathCubic {
                control1X: root.size * 0.18
                control1Y: root.headH * 1.0
                control2X: -root.size * 0.04
                control2Y: root.headH * 0.76
                x: root.size * 0.01
                y: root.headH * 0.56
            }

            PathCubic {
                control1X: root.size * 0.02
                control1Y: root.headH * 0.25
                control2X: root.size * 0.16
                control2Y: 0
                x: root.size * 0.50
                y: 0
            }
        }
    }

    // Forehead Tabby Stripes
    Repeater {
        model: 3
        Rectangle {
            required property int index
            width: Math.max(2, root.size * 0.04)
            height: root.size * (index === 1 ? 0.135 : 0.095)
            radius: width / 2
            color: root.stripe
            x: root.size * 0.5 - width / 2 + (index - 1) * root.size * 0.085 + root.parallaxFaceX * 0.75
            y: root.size * 0.045
        }
    }

    // Cheek Blush Pads
    Rectangle {
        x: root.size * 0.08 + root.parallaxFaceX
        y: root.headH * 0.63
        width: root.size * 0.15
        height: root.size * 0.085
        radius: height / 2
        color: Qt.alpha(Colours.palette.m3error, root.blush + root.happySquint * 0.16)
    }
    Rectangle {
        x: root.size * 0.77 + root.parallaxFaceX
        y: root.headH * 0.63
        width: root.size * 0.15
        height: root.size * 0.085
        radius: height / 2
        color: Qt.alpha(Colours.palette.m3error, root.blush + root.happySquint * 0.16)
    }

    // Stereoscopic Eyes
    Eye {
        cat: root
        isRight: false
        x: root.size * 0.27 - width / 2 + root.parallaxFaceX
        y: root.headH * 0.46 - height / 2
        lid: root.lidL
        lx: root.lookXL
        ly: root.lookYL
    }
    Eye {
        cat: root
        isRight: true
        x: root.size * 0.73 - width / 2 + root.parallaxFaceX
        y: root.headH * 0.46 - height / 2
        lid: root.lidR
        lx: root.lookXR
        ly: root.lookYR
    }

    // ── Plump Whisker Pads ──────────────────────────────────────────────────
    Row {
        readonly property real padPuff: 1.0 + Math.sin(root.sniffPhase * Math.PI * 6) * 0.08 + root.whiskerForward * 0.06
        x: root.size * 0.5 - width / 2 + root.parallaxMuzzleX
        y: root.headH * 0.63 - Math.abs(Math.sin(root.sniffPhase * Math.PI * 6)) * 1.5
        spacing: -root.size * 0.02
        opacity: 0.72

        Rectangle {
            width: root.size * 0.13 * parent.padPuff
            height: root.size * 0.095
            radius: height / 2
            color: root.furLight
        }
        Rectangle {
            width: root.size * 0.13 * parent.padPuff
            height: root.size * 0.095
            radius: height / 2
            color: root.furLight
        }
    }

    // ── Anatomical Triangular Feline Nose Leather ───────────────────────────
    Shape {
        id: noseLeather
        readonly property real sniffTwitchY: Math.sin(root.sniffPhase * Math.PI * 8) * root.size * 0.016
        readonly property real sniffFlareW: 1.0 + Math.abs(Math.sin(root.sniffPhase * Math.PI * 8)) * 0.12
        width: root.size * 0.11 * sniffFlareW
        height: root.size * 0.075
        x: root.size * 0.5 - width / 2 + root.parallaxMuzzleX
        y: root.headH * 0.61 + sniffTwitchY
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.noseColor
            strokeColor: "transparent"
            startX: noseLeather.width * 0.5
            startY: noseLeather.height
            PathCubic {
                control1X: noseLeather.width * 0.15
                control1Y: noseLeather.height * 0.85
                control2X: -noseLeather.width * 0.10
                control2Y: 0
                x: noseLeather.width * 0.5
                y: 0
            }
            PathCubic {
                control1X: noseLeather.width * 1.10
                control1Y: 0
                control2X: noseLeather.width * 0.85
                control2Y: noseLeather.height * 0.85
                x: noseLeather.width * 0.5
                y: noseLeather.height
            }
        }
    }

    // ── Grooming Pink Tongue Flick ──────────────────────────────────────────
    Rectangle {
        visible: root.groomLick > 0.05 && root.mouthOpen < 0.1
        width: root.size * 0.09
        height: root.size * 0.11 * root.groomLick
        radius: width / 2
        x: root.size * 0.5 - width / 2 + root.parallaxMuzzleX
        y: root.headH * 0.68
        color: Qt.alpha(root.noseColor, 0.88)
    }

    // ── Mouth: Closed ":3" Philtrum, Chattering Jaw, or Open Yawn ───────────
    readonly property real effectiveMouthOpen: Math.max(
        root.mouthOpen,
        root.chatterPhase > 0.01 ? (0.14 + Math.abs(Math.sin(root.chatterPhase * Math.PI * 10)) * 0.24) : 0
    )

    Shape {
        x: root.size * 0.5 + root.parallaxMuzzleX
        y: root.headH * 0.61 + root.size * 0.075
        visible: root.effectiveMouthOpen < 0.05
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.mouthColor
            strokeWidth: Math.max(1.2, root.size * 0.022)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: -2 * root.size * 0.052
            startY: 0
            PathArc {
                x: 0; y: 0
                radiusX: root.size * 0.052; radiusY: root.size * (0.048 + root.happySquint * 0.015)
                direction: PathArc.Counterclockwise
            }
            PathArc {
                x: 2 * root.size * 0.052; y: 0
                radiusX: root.size * 0.052; radiusY: root.size * (0.048 + root.happySquint * 0.015)
                direction: PathArc.Counterclockwise
            }
        }
    }

    Rectangle {
        visible: root.effectiveMouthOpen >= 0.05
        width: root.size * 0.21 * (0.62 + 0.38 * root.effectiveMouthOpen)
        height: root.size * 0.27 * root.effectiveMouthOpen
        radius: Math.min(width, height) / 2
        x: root.size * 0.5 - width / 2 + root.parallaxMuzzleX
        y: root.headH * 0.63 + root.size * 0.08
        color: Qt.darker(root.noseColor, 2.4)
        clip: true

        Rectangle {
            width: parent.width * 0.66
            height: parent.height * 0.46
            radius: height / 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.06
            color: Qt.alpha(root.noseColor, 0.82)
        }

        Repeater {
            model: 2
            Rectangle {
                required property int index
                visible: root.effectiveMouthOpen > 0.22
                width: Math.max(2, parent.width * 0.14)
                height: Math.max(2, parent.height * 0.20)
                radius: width * 0.35
                x: parent.width * (index === 0 ? 0.20 : 0.66)
                y: -1
                color: root.sclera
            }
        }
    }

    // ── Curved Tapered Vibrissae (Whiskers) ─────────────────────────────────
    readonly property real whiskerQuiver: (root.sniffPhase > 0 ? Math.sin(root.sniffPhase * Math.PI * 10) * 4.5 : 0)
                                        + (root.chatterPhase > 0 ? Math.sin(root.chatterPhase * Math.PI * 12) * 3.5 : 0)

    Repeater {
        model: 3
        Shape {
            required property int index
            width: root.size * 0.32
            height: root.size * 0.08
            x: -root.size * 0.19 + root.parallaxMuzzleX * 0.5
            y: root.headH * 0.64 + (index - 1) * root.size * 0.045
            transformOrigin: Item.Right
            rotation: (index - 1) * 12 - root.whiskerForward * 9 + root.whiskerQuiver

            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.alpha(Colours.palette.m3onPrimaryContainer, 0.44)
                strokeWidth: 1.25
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: root.size * 0.32
                startY: root.size * 0.02
                PathQuad {
                    controlX: root.size * 0.16
                    controlY: 0
                    x: 0
                    y: root.size * 0.045
                }
            }
        }
    }

    Repeater {
        model: 3
        Shape {
            required property int index
            width: root.size * 0.32
            height: root.size * 0.08
            x: root.size * 0.87 + root.parallaxMuzzleX * 0.5
            y: root.headH * 0.64 + (index - 1) * root.size * 0.045
            transformOrigin: Item.Left
            rotation: -(index - 1) * 12 + root.whiskerForward * 9 - root.whiskerQuiver

            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.alpha(Colours.palette.m3onPrimaryContainer, 0.44)
                strokeWidth: 1.25
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: 0
                startY: root.size * 0.02
                PathQuad {
                    controlX: root.size * 0.16
                    controlY: 0
                    x: root.size * 0.32
                    y: root.size * 0.045
                }
            }
        }
    }
}