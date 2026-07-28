import QtQuick
import QtQuick.Layouts
import Olvex.Config
import Olvex.Services
import qs.components
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    readonly property color accentColor: Colours.palette.m3primary

    // --- Animated Wave Background (Minute Progress) ---
    Canvas {
        id: waveCanvas
        anchors.fill: parent
        opacity: 0.55
        z: 0

        property real phase: 0
        property real fillProgress: 0.0
        property bool isResetting: false

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            function drawWave(fillColor, amplitude, freq, phaseOffset) {
                ctx.beginPath();
                ctx.fillStyle = fillColor;
                
                // Base goes from bottom (height + max_amplitude) to top (-max_amplitude)
                var maxAmplitude = 10;
                var startBase = height + maxAmplitude;
                var endBase = -maxAmplitude;
                var base = startBase + (endBase - startBase) * waveCanvas.fillProgress;
                
                ctx.moveTo(0, height);
                for (var x = 0; x <= width; x++) {
                    var y = base + Math.sin(x * freq + waveCanvas.phase + phaseOffset) * amplitude;
                    ctx.lineTo(x, y);
                }
                ctx.lineTo(width, height);
                ctx.closePath();
                ctx.fill();
            }

            // Use System Accent Palette
            drawWave(String(Colours.palette.m3tertiary), 10, 0.016, 0);
            drawWave(String(Colours.palette.m3secondary), 7,  0.022, 1.2);
            drawWave(String(Colours.palette.m3primary), 5,  0.028, 2.5);
        }

        Timer {
            running: true
            repeat: true
            interval: 16
            onTriggered: {
                waveCanvas.phase += 0.045;
                
                // Calculate actual progress based on seconds and milliseconds
                var d = new Date();
                var target = (d.getSeconds() + d.getMilliseconds() / 1000) / 60.0;
                
                // Detect wrap-around (minute changed)
                if (waveCanvas.fillProgress > 0.8 && target < 0.2) {
                    waveCanvas.isResetting = true;
                }
                
                if (waveCanvas.isResetting) {
                    // Smooth, fast drop animation (takes ~800ms to empty)
                    waveCanvas.fillProgress -= 0.02;
                    if (waveCanvas.fillProgress <= target) {
                        waveCanvas.fillProgress = target;
                        waveCanvas.isResetting = false;
                    }
                } else {
                    // Smooth follow for the rising animation
                    waveCanvas.fillProgress += (target - waveCanvas.fillProgress) * 0.15;
                }
                
                waveCanvas.requestPaint();
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 0
        z: 1

        // Top Clock Icon — top-left
        StyledRect {
            Layout.alignment: Qt.AlignLeft
            width: 36; height: 36; radius: 18
            color: Qt.alpha(root.accentColor, 0.10)
            border.color: Qt.alpha(root.accentColor, 0.18)
            border.width: 1
            MaterialIcon {
                anchors.centerIn: parent
                text: "schedule"
                color: root.accentColor
                font.pointSize: 16
            }
        }

        Item { Layout.fillHeight: true }

        // Time Section
        Column {
            Layout.alignment: Qt.AlignHCenter
            spacing: 0

            StyledText {
                text: Time.hourStr
                font.pointSize: 48
                font.weight: 800
                color: "#ffffff"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Three dots separator
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                Repeater {
                    model: 3
                    Rectangle {
                        width: 5; height: 5; radius: 2.5
                        color: index === 1 ? "#ffffff" : root.accentColor
                        opacity: 0.7
                    }
                }
            }

            StyledText {
                text: Time.minuteStr
                font.pointSize: 48
                font.weight: 800
                color: "#ffffff"
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        Item { Layout.preferredHeight: 6 }

        // AM/PM + Day row
        Column {
            Layout.alignment: Qt.AlignHCenter
            spacing: 1

            StyledText {
                text: Time.amPmStr
                font.pointSize: 18
                font.weight: 700
                color: root.accentColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: Time.format("dddd")
                font.pointSize: 10
                font.weight: 400
                color: Qt.alpha("#ffffff", 0.55)
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: Time.format("dd")
                font.pointSize: 28
                font.weight: 800
                color: root.accentColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        Item { Layout.preferredHeight: 10 }

        // Decorative Dot Grid
        Grid {
            Layout.alignment: Qt.AlignHCenter
            columns: 4
            rows: 2
            columnSpacing: 7
            rowSpacing: 7

            Repeater {
                model: 8
                Rectangle {
                    width: 4; height: 4; radius: 2
                    color: root.accentColor
                    opacity: 0.3
                }
            }
        }

        Item { Layout.preferredHeight: 8 }
    }
}
