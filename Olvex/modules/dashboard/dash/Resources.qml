import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Olvex.Config
import Olvex.Services
import qs.components
import qs.components.effects
import qs.components.misc
import qs.services
import qs.utils

Item {
    id: root

    required property DrawerVisibilities visibilities

    readonly property color accentColor: Colours.palette.m3primary

    Component.onCompleted: SystemUsage.refCount++
    Component.onDestruction: SystemUsage.refCount--

    RowLayout {
        anchors.centerIn: parent
        spacing: 16

        Repeater {
            model: 3
            delegate: ColumnLayout {
                id: colDelegate
                Layout.fillHeight: true
                spacing: 8

                // Dynamic properties for reactivity
                property real val: index === 0 ? SystemUsage.cpuPerc :
                                   index === 1 ? SystemUsage.memPerc :
                                   (SystemUsage.disks.length > 0 ? SystemUsage.disks[0].perc : 0)
                property string iconTxt: index === 0 ? "memory" : index === 1 ? "memory_alt" : "hard_disk"
                property color col1: index === 0 ? Colours.palette.m3primary : index === 1 ? Colours.palette.m3secondary : Colours.palette.m3tertiary
                property color col2: index === 0 ? Qt.alpha(Colours.palette.m3primary, 0.4) : index === 1 ? Qt.alpha(Colours.palette.m3secondary, 0.4) : Qt.alpha(Colours.palette.m3tertiary, 0.4)
                property string labelTxt: index === 0 ? "CPU" : index === 1 ? "RAM" : "DISK"

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: colDelegate.iconTxt
                    color: colDelegate.col1
                    iconPointSize: 14
                }

                // Fluid Liquid Meter
                StyledClippingRect {
                    id: meterRect
                    Layout.alignment: Qt.AlignHCenter
                    height: 120 // Fixed height for symmetry
                    Layout.preferredWidth: 32 // Wider to show fluid
                    radius: 16 // Full pill shape
                    color: Qt.alpha("#ffffff", 0.05)
                    border.color: Qt.alpha("#ffffff", 0.05)
                    border.width: 1

                    property real animatedVal: colDelegate.val
                    Behavior on animatedVal {
                        NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
                    }

                    Canvas {
                        id: canvas
                        anchors.fill: parent
                        property real phase: 0

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);

                            function drawWave(fillColor, amplitude, freq, phaseOffset) {
                                ctx.beginPath();
                                ctx.fillStyle = fillColor; // Direct QColor assignment works best in QML Canvas
                                
                                var startBase = height + amplitude;
                                var endBase = -amplitude;
                                var base = startBase + (endBase - startBase) * meterRect.animatedVal;
                                
                                ctx.moveTo(0, height);
                                for (var x = 0; x <= width; x++) {
                                    var y = base + Math.sin(x * freq + canvas.phase + phaseOffset) * amplitude;
                                    ctx.lineTo(x, y);
                                }
                                ctx.lineTo(width, height);
                                ctx.closePath();
                                ctx.fill();
                            }

                            // Render two liquid layers for depth
                            drawWave(colDelegate.col2, 4, 0.1, 0);
                            drawWave(colDelegate.col1, 3, 0.15, 1.5);
                        }

                        Timer {
                            running: true
                            repeat: true
                            interval: 16
                            onTriggered: {
                                canvas.phase += 0.06;
                                canvas.requestPaint();
                            }
                        }
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: `${Math.round(colDelegate.val * 100)}%`
                    color: "#ffffff"
                    textPointSize: 8
                    font.weight: 700
                    opacity: 0.9
                }
            }
        }
    }
}
