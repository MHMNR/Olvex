import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Olvex.Config
import qs.components
import qs.services
import "steps"

// Olvex first-run setup wizard (UI only; system access lives in SetupBackend).
Item {
    id: root

    signal closeRequested

    property int pending: 0
    property int dir: 1
    property bool busy: true
    readonly property int last: wizState.stepCount - 1
    readonly property bool showFooter: wizState.step > 0 && wizState.step < last

    // Stage 1 -> Stage 2 Apple-style Logo Intro & Window Morph state
    property real leftBeamTip: 0.0
    property real leftBeamTail: 0.0
    property real leftBeamFold: 0.0
    property real rightBeamTip: 0.0
    property real rightBeamTail: 0.0
    property real rightBeamFold: 0.0
    property real waveDrawProgress: 0.0
    property real waveSettle: 0.0
    property real waveAmpProgress: 0.0
    property real resonancePulse: 0.0
    property real heroFloatScale: 4.15
    property real dockProgressX: 0.0
    property real dockProgressY: 0.0
    property real dockScaleProgress: 0.0
    property real windowRevealProgress: 0.0
    property real contentRevealProgress: 0.0
    property real headerTextProgress: 0.0
    property real logoMasterOpacity: 1.0
    property bool helloActive: false

    readonly property real currentLogoScale: root.heroFloatScale + (1.0 - root.heroFloatScale) * root.dockScaleProgress

    readonly property var stepComponents: [cHello, cDisplay, cTheme, cApps, cShortcuts, cFinish]

    function goTo(index) {
        if (busy || index < 0 || index > last || index === wizState.step)
            return;
        dir = index > wizState.step ? 1 : -1;
        pending = index;
        transition.restart();
    }

    function next() {
        goTo(wizState.step + 1);
    }

    function back() {
        goTo(wizState.step - 1);
    }

    function finish() {
        SetupFactory.markComplete();
        backendObj.finish();
        exitAnim.start();
    }

    SetupState {
        id: wizState
    }

    SetupBackend {
        id: backendObj
    }

    // Sync blur rule with Hyprland on toggle (blur enabled by default)
    Connections {
        target: wizState
        function onTransparencyChanged() {
            SetupFactory.syncSetupBlur(true, wizState.transparency);
        }
    }

    Shortcut {
        sequence: "Return"
        enabled: !root.busy
        onActivated: {
            if (wizState.step === root.last)
                root.finish();
            else
                root.next();
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: !root.busy && wizState.step > 0 && wizState.step < root.last
        onActivated: root.back()
    }

    // Window surface: clean flat M3 surface matching Settings app & Dashboard
    StyledRect {
        id: windowSurface
        anchors.fill: parent
        radius: 28
        color: wizState.windowBackground
        border.width: 0
        border.color: "transparent"
        opacity: root.windowRevealProgress
        scale: 0.94 + (0.06 * root.windowRevealProgress)

        Behavior on color {
            CAnim {}
        }
    }

    Item {
        id: card

        anchors.fill: parent
        opacity: root.contentRevealProgress
        scale: 0.96 + (0.04 * root.contentRevealProgress)

        Component.onCompleted: introSequence.start()

        // Master Apple-style 3-phase intro sequence:
        // Phase 1: Olvex 3-part vector mark ignites with comet stroke trim, angular chevron fold-in,
        //          and a living traveling sinusoidal wave at center screen (zero background disc).
        // Phase 2: Harmonic resonance pulse & levitation hold at apex.
        // Phase 3: Aerodynamic banked arc morph into the top-left header slot while the Setup Window
        //          surface, shadow, and "Bonjour" calligraphy materialize around it.
        SequentialAnimation {
            id: introSequence

            PauseAnimation {
                duration: 110
            }

            // Phase 1 & 2: Rich Vector Assembly + Traveling Wave + Harmonic Resonance
            ParallelAnimation {
                // Continuous center levitation scale (4.15 -> 4.88 -> 5.02)
                SequentialAnimation {
                    NumberAnimation {
                        target: root
                        property: "heroFloatScale"
                        from: 4.15
                        to: 4.88
                        duration: 940
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]
                    }
                    NumberAnimation {
                        target: root
                        property: "heroFloatScale"
                        to: 5.04
                        duration: 420
                        easing.type: Easing.InOutSine
                    }
                }

                // Left Roof Beam (#675FFF): Comet tip shoot + tail anchor + angular fold
                NumberAnimation {
                    target: root
                    property: "leftBeamTip"
                    from: 0.0
                    to: 1.0
                    duration: 640
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]
                }
                NumberAnimation {
                    target: root
                    property: "leftBeamTail"
                    from: 0.0
                    to: 1.0
                    duration: 780
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
                }
                NumberAnimation {
                    target: root
                    property: "leftBeamFold"
                    from: 0.0
                    to: 1.0
                    duration: 820
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.18
                }

                // Right Roof Beam (#FF8A5B): Staggered 85ms comet tip + tail anchor + angular fold
                SequentialAnimation {
                    PauseAnimation {
                        duration: 85
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: root
                            property: "rightBeamTip"
                            from: 0.0
                            to: 1.0
                            duration: 640
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]
                        }
                        NumberAnimation {
                            target: root
                            property: "rightBeamTail"
                            from: 0.0
                            to: 1.0
                            duration: 780
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
                        }
                        NumberAnimation {
                            target: root
                            property: "rightBeamFold"
                            from: 0.0
                            to: 1.0
                            duration: 820
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.18
                        }
                    }
                }

                // M3 Expressive Wave: Progressive ribbon draw + multi-cycle traveling sine wave
                SequentialAnimation {
                    PauseAnimation {
                        duration: 180
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: root
                            property: "waveDrawProgress"
                            from: 0.0
                            to: 1.0
                            duration: 760
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]
                        }
                        NumberAnimation {
                            target: root
                            property: "waveAmpProgress"
                            from: 0.0
                            to: 1.0
                            duration: 840
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.32
                        }
                        NumberAnimation {
                            target: root
                            property: "waveSettle"
                            from: 0.0
                            to: 1.0
                            duration: 1120
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]
                        }
                    }
                }

                // Harmonic Resonance Pulse when chevron & wave lock at apex
                SequentialAnimation {
                    PauseAnimation {
                        duration: 740
                    }
                    NumberAnimation {
                        target: root
                        property: "resonancePulse"
                        from: 0.0
                        to: 1.0
                        duration: 280
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: root
                        property: "resonancePulse"
                        to: 0.0
                        duration: 340
                        easing.type: Easing.InOutSine
                    }
                }
            }

            // Phase 3: Aerodynamic Spatial Morph to Header Slot + Window Materialization
            ParallelAnimation {
                // Separate X/Y/Scale splines produce a natural sweeping 2D Bezier trajectory
                NumberAnimation {
                    target: root
                    property: "dockProgressX"
                    from: 0.0
                    to: 1.0
                    duration: 820
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.24, 1.0, 0.32, 1.0, 1.0, 1.0]
                }

                NumberAnimation {
                    target: root
                    property: "dockProgressY"
                    from: 0.0
                    to: 1.0
                    duration: 820
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]
                }

                NumberAnimation {
                    target: root
                    property: "dockScaleProgress"
                    from: 0.0
                    to: 1.0
                    duration: 820
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.20, 1.0, 0.34, 1.0, 1.0, 1.0]
                }

                SequentialAnimation {
                    PauseAnimation {
                        duration: 200
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: root
                            property: "windowRevealProgress"
                            from: 0.0
                            to: 1.0
                            duration: 620
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]
                        }
                        NumberAnimation {
                            target: root
                            property: "contentRevealProgress"
                            from: 0.0
                            to: 1.0
                            duration: 640
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]
                        }
                        ScriptAction {
                            script: root.helloActive = true
                        }
                    }
                }

                SequentialAnimation {
                    PauseAnimation {
                        duration: 440
                    }
                    NumberAnimation {
                        target: root
                        property: "headerTextProgress"
                        from: 0.0
                        to: 1.0
                        duration: 460
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]
                    }
                }
            }

            ScriptAction {
                script: root.busy = false
            }
        }

        SequentialAnimation {
            id: exitAnim

            ParallelAnimation {
                NumberAnimation {
                    target: root
                    property: "windowRevealProgress"
                    to: 0.0
                    duration: 360
                    easing.type: Easing.InCubic
                }
                NumberAnimation {
                    target: root
                    property: "contentRevealProgress"
                    to: 0.0
                    duration: 340
                    easing.type: Easing.InCubic
                }
                NumberAnimation {
                    target: root
                    property: "logoMasterOpacity"
                    to: 0.0
                    duration: 300
                    easing.type: Easing.InCubic
                }
            }
            ScriptAction {
                script: root.closeRequested()
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Header
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                Layout.leftMargin: 28
                Layout.rightMargin: 28
                spacing: 10

                // Target slot where olvexHeroLogo docks at the end of the intro morph
                Item {
                    id: headerLogoSlot
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 22
                    Layout.alignment: Qt.AlignVCenter
                }

                StyledText {
                    text: qsTr("Olvex Setup")
                    font.weight: Font.DemiBold
                    textPointSize: Tokens.font.size.large
                    color: Colours.light ? "#1C1819" : Colours.palette.m3onSurface
                    opacity: root.headerTextProgress
                    transform: Translate {
                        x: (1.0 - root.headerTextProgress) * -10
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                SetupButton {
                    kind: SetupButton.Text
                    implicitHeight: 36
                    label: qsTr("Skip setup")
                    opacity: (wizState.step < root.last ? 1 : 0) * root.headerTextProgress
                    disabled: wizState.step >= root.last || root.busy
                    onClicked: root.finish()
                }
            }

            // Step stage
            Item {
                id: stage

                property real slideX: 0

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Loader {
                    id: stepLoader

                    width: stage.width
                    height: stage.height
                    sourceComponent: cHello
                    transform: Translate {
                        x: stage.slideX
                    }
                }
            }

            // Footer
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 76
                opacity: root.showFooter ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }
                }

                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: Qt.alpha(Colours.palette.m3outlineVariant, 0.12)
                }

                StepDots {
                    anchors.centerIn: parent
                    count: wizState.stepCount
                    current: wizState.step
                }
            }
        }

        // Secondary Back Action Button (visible across Steps 1..5)
        SetupButton {
            id: backButton
            z: 50

            readonly property real destY: {
                if (wizState.step === root.last) return card.height - 82 + Math.round((50 - 44) / 2);
                return card.height - 76 + Math.round((76 - 44) / 2);
            }

            x: 28
            y: destY
            implicitHeight: 44
            kind: SetupButton.Text
            label: qsTr("Back")
            icon: "arrow_back"
            iconTrailing: false
            opacity: wizState.step > 0 ? 1.0 : 0.0
            visible: opacity > 0.01
            disabled: wizState.step <= 0

            Behavior on y { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            onClicked: root.back()
        }

        // Primary Morphing Action Button (Get Started -> Continue -> Enter Olvex)
        SetupButton {
            id: morphButton
            z: 50

            readonly property real destX: {
                if (wizState.step === 0) return Math.round((card.width - destW) / 2);
                if (wizState.step === root.last) return Math.round((card.width - destW) / 2);
                return card.width - 28 - destW;
            }
            readonly property real destY: {
                if (wizState.step === 0) return Math.round(card.height * 0.735);
                if (wizState.step === root.last) return card.height - 82;
                return card.height - 76 + Math.round((76 - destH) / 2);
            }
            readonly property real destW: {
                if (wizState.step === 0) return 196;
                if (wizState.step === root.last) return 220;
                return 152;
            }
            readonly property real destH: {
                if (wizState.step === root.last) return 50;
                return 44;
            }

            x: destX
            y: destY
            implicitWidth: destW
            implicitHeight: destH
            width: implicitWidth
            height: implicitHeight

            label: {
                if (wizState.step === 0) return qsTr("Get Started");
                if (wizState.step === root.last) return qsTr("Enter Olvex");
                return qsTr("Continue");
            }
            icon: "arrow_forward"

            readonly property int motionDuration: 360
            readonly property var motionEasing: Easing.OutCubic

            Behavior on x { NumberAnimation { duration: morphButton.motionDuration; easing.type: morphButton.motionEasing } }
            Behavior on y { NumberAnimation { duration: morphButton.motionDuration; easing.type: morphButton.motionEasing } }
            Behavior on width { NumberAnimation { duration: morphButton.motionDuration; easing.type: morphButton.motionEasing } }
            Behavior on height { NumberAnimation { duration: morphButton.motionDuration; easing.type: morphButton.motionEasing } }

            onClicked: {
                if (wizState.step === root.last) {
                    root.finish();
                } else {
                    root.next();
                }
            }
        }
    }

    // Continuous Hero-to-Header Olvex Logo (z: 100)
    // Pure vector mark (zero background disc) with locked brand colors (#675FFF & #FF8A5B).
    Item {
        id: olvexHeroLogo
        z: 100

        readonly property real designW: 180.0
        readonly property real designH: 155.0

        readonly property real startCenterX: root.width * 0.5
        readonly property real startCenterY: root.height * 0.5
        readonly property real targetCenterX: 28 + 13
        readonly property real targetCenterY: 28
        readonly property real arcOffsetY: Math.sin(root.dockProgressY * Math.PI) * -22.0

        width: 26
        height: 22
        x: (startCenterX + (targetCenterX - startCenterX) * root.dockProgressX) - (width * 0.5)
        y: (startCenterY + (targetCenterY - startCenterY) * root.dockProgressY) + arcOffsetY - (height * 0.5)
        rotation: Math.sin(root.dockScaleProgress * Math.PI) * -4.5
        opacity: root.logoMasterOpacity

        readonly property real shapeScale: (width / designW) * root.currentLogoScale

        // Left Roof Beam (Locked Brand Indigo #675FFF)
        Shape {
            id: leftBeamShape
            width: olvexHeroLogo.designW
            height: olvexHeroLogo.designH
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: (((1.0 - root.leftBeamFold) * -26.0) - (root.resonancePulse * 3.2)) * olvexHeroLogo.shapeScale
            anchors.verticalCenterOffset: (((1.0 - root.leftBeamFold) * 28.0) - (root.resonancePulse * 2.2)) * olvexHeroLogo.shapeScale
            scale: olvexHeroLogo.shapeScale
            rotation: (1.0 - root.leftBeamFold) * -14.0
            transformOrigin: Item.Center
            opacity: Math.min(1.0, root.leftBeamTip * 1.85)
            preferredRendererType: Shape.CurveRenderer

            readonly property real tailT: (1.0 - root.leftBeamTail) * 0.44
            readonly property real tipT: 0.12 + (0.88 * root.leftBeamTip)

            ShapePath {
                strokeColor: "#675FFF"
                strokeWidth: 16 + (12 * root.leftBeamTail) + (3.2 * root.resonancePulse)
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                fillColor: "transparent"

                startX: 28 + (73 - 28) * leftBeamShape.tailT
                startY: 114 + (20 - 114) * leftBeamShape.tailT
                PathLine {
                    x: 28 + (73 - 28) * leftBeamShape.tipT
                    y: 114 + (20 - 114) * leftBeamShape.tipT
                }
            }
        }

        // Right Roof Beam (Locked Brand Coral #FF8A5B)
        Shape {
            id: rightBeamShape
            width: olvexHeroLogo.designW
            height: olvexHeroLogo.designH
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: (((1.0 - root.rightBeamFold) * 26.0) + (root.resonancePulse * 3.2)) * olvexHeroLogo.shapeScale
            anchors.verticalCenterOffset: (((1.0 - root.rightBeamFold) * 28.0) - (root.resonancePulse * 2.2)) * olvexHeroLogo.shapeScale
            scale: olvexHeroLogo.shapeScale
            rotation: (1.0 - root.rightBeamFold) * 14.0
            transformOrigin: Item.Center
            opacity: Math.min(1.0, root.rightBeamTip * 1.85)
            preferredRendererType: Shape.CurveRenderer

            readonly property real tailT: (1.0 - root.rightBeamTail) * 0.44
            readonly property real tipT: 0.12 + (0.88 * root.rightBeamTip)

            ShapePath {
                strokeColor: "#FF8A5B"
                strokeWidth: 16 + (12 * root.rightBeamTail) + (3.2 * root.resonancePulse)
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                fillColor: "transparent"

                startX: 152 + (107 - 152) * rightBeamShape.tailT
                startY: 114 + (20 - 114) * rightBeamShape.tailT
                PathLine {
                    x: 152 + (107 - 152) * rightBeamShape.tipT
                    y: 114 + (20 - 114) * rightBeamShape.tipT
                }
            }
        }

        // Wavy Signal Line (Living Traveling Sine Wave -> Canonical Olvex Wave)
        Shape {
            id: waveShape
            width: olvexHeroLogo.designW
            height: olvexHeroLogo.designH
            anchors.centerIn: parent
            anchors.verticalCenterOffset: (((1.0 - root.waveDrawProgress) * 24.0) + (root.resonancePulse * 2.6)) * olvexHeroLogo.shapeScale
            scale: olvexHeroLogo.shapeScale
            transformOrigin: Item.Center
            opacity: Math.min(1.0, root.waveDrawProgress * 1.75)
            preferredRendererType: Shape.CurveRenderer

            readonly property real amp: (14.0 * root.waveAmpProgress) + (3.0 * root.resonancePulse)
            readonly property real phi: (1.0 - root.waveSettle) * 5.4
            readonly property real span: 160.0 * root.waveDrawProgress
            readonly property real midX: 10.0 + (span * 0.5)
            readonly property real endX: 10.0 + span

            ShapePath {
                strokeColor: Colours.light ? "#1D1D1F" : "#F5F5F7"
                strokeWidth: 6 + (4 * root.waveDrawProgress) + (1.4 * root.resonancePulse)
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                fillColor: "transparent"

                startX: 10.0
                startY: 130.0 - (waveShape.amp * 0.35 * Math.sin(waveShape.phi))
                PathCubic {
                    control1X: 10.0 + (waveShape.span * 0.1875)
                    control1Y: 130.0 - (waveShape.amp * Math.cos(waveShape.phi))
                    control2X: 10.0 + (waveShape.span * 0.3125)
                    control2Y: 130.0 + (waveShape.amp * Math.cos(waveShape.phi))
                    x: waveShape.midX
                    y: 130.0 + (waveShape.amp * 0.38 * Math.sin(waveShape.phi))
                }
                PathCubic {
                    control1X: 10.0 + (waveShape.span * 0.6875)
                    control1Y: 130.0 - (waveShape.amp * Math.cos(waveShape.phi))
                    control2X: 10.0 + (waveShape.span * 0.8125)
                    control2Y: 130.0 + (waveShape.amp * Math.cos(waveShape.phi))
                    x: waveShape.endX
                    y: 130.0 - (waveShape.amp * 0.35 * Math.sin(waveShape.phi))
                }
            }
        }
    }

    SequentialAnimation {
        id: transition

        ScriptAction {
            script: root.busy = true
        }
        ParallelAnimation {
            NumberAnimation {
                target: stage
                property: "slideX"
                to: -48 * root.dir
                duration: 200
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: stepLoader
                property: "opacity"
                to: 0
                duration: 200
            }
        }
        ScriptAction {
            script: {
                wizState.step = root.pending;
                stepLoader.sourceComponent = root.stepComponents[root.pending];
                stage.slideX = 64 * root.dir;
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: stage
                property: "slideX"
                to: 0
                duration: 320
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: stepLoader
                property: "opacity"
                to: 1
                duration: 320
            }
        }
        ScriptAction {
            script: root.busy = false
        }
    }

    Component {
        id: cHello

        HelloHero {
            active: root.helloActive
            onRequestAdvance: root.next()
        }
    }

    Component {
        id: cDisplay

        Step1Display {
            wiz: wizState
            backend: backendObj
        }
    }

    Component {
        id: cTheme

        Step2Theme {
            wiz: wizState
            backend: backendObj
        }
    }

    Component {
        id: cApps

        Step3Apps {
            wiz: wizState
            backend: backendObj
        }
    }

    Component {
        id: cShortcuts

        Step4Shortcuts {
            wiz: wizState
            backend: backendObj
        }
    }

    Component {
        id: cFinish

        Step5Finish {
            wiz: wizState
            backend: backendObj
            onEditStepRequested: step => root.goTo(step)
            onFinishRequested: root.finish()
        }
    }
}
