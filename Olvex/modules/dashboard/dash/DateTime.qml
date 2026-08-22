import QtQuick
import QtQuick.Layouts
import M3Shapes
import Quickshell
import Olvex
import Olvex.Config
import Olvex.Services
import qs.components
import qs.components.effects
import qs.services
import qs.utils
import "../../../utils/os_jokes.js" as OsJokes

Item {
    id: root

    property bool dashboardVisible: false
    readonly property bool waveActive: root.dashboardVisible && root.visible && width > 0 && height > 0

    property var osQuotes: OsJokes.jokes
    property int lastQuoteIndex: -1
    property string fullOsQuote: ""
    property string currentOsQuote: ""
    
    function startTypewriter(quoteText: string): void {
        fullOsQuote = quoteText;
        currentOsQuote = "";
        typewriterTimer.charIndex = 0;
        typewriterTimer.restart();
    }

    function pickRandomQuote(): void {
        if (osQuotes.length === 0) return;
        let newIdx = lastQuoteIndex;
        if (osQuotes.length > 1) {
            while (newIdx === lastQuoteIndex) {
                newIdx = Math.floor(Math.random() * osQuotes.length);
            }
        } else {
            newIdx = 0;
        }
        lastQuoteIndex = newIdx;
        startTypewriter(osQuotes[newIdx]);
    }

    onDashboardVisibleChanged: {
        if (dashboardVisible) {
            Time.secondsRefCount++;
            pickRandomQuote();
        } else {
            Time.secondsRefCount = Math.max(0, Time.secondsRefCount - 1);
        }
    }

    Component.onDestruction: {
        if (dashboardVisible)
            Time.secondsRefCount = Math.max(0, Time.secondsRefCount - 1);
    }

    Timer {
        id: typewriterTimer
        interval: 35 // typewriter typing speed
        repeat: true
        property int charIndex: 0
        onTriggered: {
            if (charIndex < root.fullOsQuote.length) {
                root.currentOsQuote += root.fullOsQuote[charIndex];
                charIndex++;
            } else {
                stop();
            }
        }
    }

    Component.onCompleted: {
        pickRandomQuote();
    }

    readonly property color accentColor: Colours.palette.m3primary
    readonly property color fillBase: Colours.light ? Colours.layer(Colours.palette.m3primaryContainer, 1) : Colours.palette.m3primary

    // ── Compiled Hardware GPU Shader Effect (clock_wave.frag.qsb) ──
    ShaderEffect {
        id: gpuWave
        anchors.fill: parent
        z: 0
        visible: gpuWave.status === ShaderEffect.Ready

        property real iTime: waveTimer.elapsed
        property real iFillProgress: waveTimer.fillProgress
        property color iPrimary: Colours.palette.m3primary
        property color iPrimaryContainer: Colours.light ? Colours.layer(Colours.palette.m3primaryContainer, 1) : Colours.palette.m3primary
        property color iOnPrimaryContainer: Colours.light ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onPrimary
        property real iWidth: Math.max(width, 1)
        property real iHeight: Math.max(height, 1)

        fragmentShader: Qt.resolvedUrl("../../../assets/shaders/clock_wave.frag.qsb")
    }

    // Canvas fallback if ShaderEffect isn't ready
    Canvas {
        id: waveCanvas
        anchors.fill: parent
        opacity: 0.82
        z: 0
        visible: gpuWave.status !== ShaderEffect.Ready && root.waveActive

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            function getGerstnerY(x, baseLevel, amplitude, freq, phaseOffset, trochFactor) {
                var p = waveTimer.elapsed * 2.2 + phaseOffset;
                var w1 = Math.sin(x * freq + p);
                var w2 = Math.cos(x * (freq * 1.8) + p * 1.3) * 0.38;
                var norm = (w1 + 1.0) * 0.5;
                var troch = Math.pow(norm, trochFactor) * 2.0 - 1.0;
                var slosh = Math.sin(p * 0.35 + (x / width) * 1.5) * (amplitude * 0.3);
                return baseLevel + (troch * amplitude) + (w2 * amplitude * 0.5) + slosh;
            }

            function drawTrochoidalWave(fillColor, amplitude, freq, phaseOffset, trochFactor, strokeColor) {
                var maxAmplitude = 18;
                var startBase = height + maxAmplitude;
                var endBase = -maxAmplitude;
                var baseLevel = startBase + (endBase - startBase) * waveTimer.fillProgress;

                ctx.beginPath();
                ctx.fillStyle = fillColor;
                ctx.moveTo(0, height);

                for (var x = 0; x <= width; x += 2) {
                    var y = getGerstnerY(x, baseLevel, amplitude, freq, phaseOffset, trochFactor);
                    ctx.lineTo(x, y);
                }
                ctx.lineTo(width, height);
                ctx.closePath();
                ctx.fill();

                if (strokeColor) {
                    ctx.beginPath();
                    ctx.strokeStyle = strokeColor;
                    ctx.lineWidth = 1.8;
                    for (var sx = 0; sx <= width; sx += 2) {
                        var sy = getGerstnerY(sx, baseLevel, amplitude, freq, phaseOffset, trochFactor);
                        if (sx === 0) ctx.moveTo(sx, sy);
                        else ctx.lineTo(sx, sy);
                    }
                    ctx.stroke();
                }
            }

            drawTrochoidalWave(String(Qt.alpha(root.fillBase, 0.92)), 14, 0.016, 0.0, 1.8, String(Qt.alpha(Colours.light ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onPrimary, 0.88)));
            drawTrochoidalWave(String(Qt.alpha(root.fillBase, 0.65)), 10, 0.022, 1.5, 1.5, null);
            drawTrochoidalWave(String(Qt.alpha(root.fillBase, 0.40)), 7,  0.032, 2.9, 1.3, null);
        }
    }

    Timer {
        id: waveTimer
        running: root.waveActive
        repeat: true
        interval: 30

        property real elapsed: 0
        property real fillProgress: 0.0
        property bool isResetting: false

        onTriggered: {
            waveTimer.elapsed += interval / 1000.0;

            var d = new Date();
            var target = (d.getSeconds() + d.getMilliseconds() / 1000) / 60.0;

            if (waveTimer.fillProgress > 0.85 && target < 0.15) {
                waveTimer.isResetting = true;
            }

            if (waveTimer.isResetting) {
                waveTimer.fillProgress -= 0.035;
                if (waveTimer.fillProgress <= target) {
                    waveTimer.fillProgress = target;
                    waveTimer.isResetting = false;
                }
            } else {
                waveTimer.fillProgress += (target - waveTimer.fillProgress) * 0.22;
            }

            if (waveCanvas.visible) waveCanvas.requestPaint();
        }
    }

    // ── Perfect Visual Hierarchy Container ──
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 0
        z: 1

        Item { Layout.preferredHeight: 12 }

        // 1. TOP: Hero Time Stack (90° Clockwise Rotated)
        Column {
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.large

            property string hh: { var _ = Time.minuteStr; return Time.format(GlobalConfig.services.useTwelveHourClock ? "hh A" : "HH").substring(0, 2) }
            property string mm: { var _ = Time.minuteStr; return Time.format("mm") }

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: hhText.implicitHeight
                height: hhText.implicitWidth

                StyledText {
                    id: hhText
                    anchors.centerIn: parent
                    rotation: 90
                    text: parent.parent.hh.split("").join(" ")
                    textPointSize: 58
                    font.weight: Font.Black
                    color: Colours.palette.m3onSurface
                }
            }

            // Animated M3 Capsule Separator
            Rectangle {
                id: sepCapsule
                anchors.horizontalCenter: parent.horizontalCenter
                width: 28
                height: 4
                radius: 2
                color: root.accentColor

                SequentialAnimation on opacity {
                    running: root.waveActive
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.4; duration: 750; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.95; duration: 750; easing.type: Easing.InOutSine }
                }
            }

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: mmText.implicitHeight
                height: mmText.implicitWidth

                StyledText {
                    id: mmText
                    anchors.centerIn: parent
                    rotation: 90
                    text: parent.parent.mm.split("").join(" ")
                    textPointSize: 58
                    font.weight: Font.Black
                    color: Colours.palette.m3onSurface
                }
            }
        }

        Item { Layout.fillHeight: true }

        // 2. MIDDLE: Spinning Seconds Badge
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56

            property var secondShapes: [
                MaterialShape.Circle, MaterialShape.Square, MaterialShape.Slanted, MaterialShape.Arch,
                MaterialShape.Fan, MaterialShape.Arrow, MaterialShape.SemiCircle, MaterialShape.Oval,
                MaterialShape.Pill, MaterialShape.Triangle, MaterialShape.Diamond, MaterialShape.ClamShell,
                MaterialShape.Pentagon, MaterialShape.Gem, MaterialShape.Sunny, MaterialShape.VerySunny,
                MaterialShape.Cookie4Sided, MaterialShape.Cookie6Sided, MaterialShape.Cookie7Sided, MaterialShape.Cookie9Sided,
                MaterialShape.Cookie12Sided, MaterialShape.Ghostish, MaterialShape.Clover4Leaf, MaterialShape.Clover8Leaf,
                MaterialShape.Burst, MaterialShape.SoftBurst, MaterialShape.Boom, MaterialShape.SoftBoom,
                MaterialShape.Flower, MaterialShape.Puffy, MaterialShape.PuffyDiamond, MaterialShape.PixelCircle,
                MaterialShape.PixelTriangle, MaterialShape.Bun, MaterialShape.Heart
            ]

            MaterialShape {
                id: m3DialShape
                anchors.centerIn: parent
                implicitSize: 52
                
                property int s: Time.seconds
                property int currentIndex: 0
                
                onSChanged: {
                    var newIndex = currentIndex;
                    while (newIndex === currentIndex) {
                        newIndex = Math.floor(Math.random() * parent.secondShapes.length);
                    }
                    currentIndex = newIndex;
                }
                
                shape: parent.secondShapes[currentIndex]
                
                color: Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.70)
            }

            StyledText {
                anchors.centerIn: parent
                text: `${Time.format("ss")}s`
                textPointSize: Tokens.font.size.smaller
                font.weight: Font.Bold
                font.family: Tokens.font.family.mono
                color: root.accentColor
            }
        }

        Item { Layout.fillHeight: true }

        // 3. BOTTOM: Quote Banner
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: quoteText.implicitHeight + 8
            Layout.alignment: Qt.AlignHCenter

            StyledText {
                id: quoteText
                anchors.centerIn: parent
                width: parent.width
                text: root.currentOsQuote
                textPointSize: Tokens.font.size.smaller - 1
                font.weight: Font.Medium
                color: Colours.palette.m3onSurface
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            HoverHandler {
                id: quoteHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: {
                    Quickshell.execDetached(["wl-copy", root.fullOsQuote]);
                    Toaster.toast("Quote Copied", "The quote has been copied to your clipboard.", "content_copy", Toast.Success);
                }
            }

            // Hover Icon
            Item {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: -4
                anchors.rightMargin: 0
                width: 20
                height: 20
                opacity: quoteHover.hovered ? 1 : 0
                Behavior on opacity { CAnim {} }

                StyledRect {
                    anchors.fill: parent
                    radius: 10
                    color: Colours.palette.m3surfaceContainerHighest
                    border.color: Colours.palette.m3outlineVariant
                    border.width: 1

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "content_copy"
                        iconPointSize: 10
                        color: Colours.palette.m3onSurface
                    }
                }
            }
        }

        Item { Layout.preferredHeight: 8 }
    }
}
