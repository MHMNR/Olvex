pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import Olvex

Item {
    id: effect

    property color accentColor: Colours.palette.m3primary
    property color secondaryColor: Qt.hsla(
        (accentColor.hslHue + 0.08) % 1.0,
        accentColor.hslSaturation * 0.8,
        Math.min(accentColor.hslLightness * 1.3, 1.0),
        1.0
    )
    property int numBars: 32
    property int contentMargin: 8

    RowLayout {
        anchors.fill: parent
        anchors.margins: effect.contentMargin
        spacing: 3

        Repeater {
            model: Math.min(Audio.cava.values ? Audio.cava.values.length : 0, effect.numBars)

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignBottom

                // val drives both rects — same Behavior so they stay in sync
                property real val: Math.max(0.01, Math.min(1.0, Audio.cava.values[index]))
                property real barH: parent.height * val

                Behavior on val {
                    NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
                }

                // ── Outer soft halo ───────────────────────────────────────
                // Horizontal gradient fades to transparent at edges.
                // Width == cell width → NEVER overflows. No blur needed.
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: parent.barH
                    radius: width / 2
                    color: "transparent"   // filled by gradient below

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.alpha(effect.accentColor, 0.0) }
                        GradientStop { position: 0.35; color: Qt.alpha(effect.accentColor, 0.25) }
                        GradientStop { position: 0.5;  color: Qt.alpha(effect.accentColor, 0.35) }
                        GradientStop { position: 0.65; color: Qt.alpha(effect.accentColor, 0.25) }
                        GradientStop { position: 1.0; color: Qt.alpha(effect.accentColor, 0.0) }
                    }
                }

                // ── Bright core bar ───────────────────────────────────────
                // Thin, solid, gradient top→bottom. Width is a fraction of
                // cell width → stays well inside parent → no bleed possible.
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(2, parent.width * 0.45)
                    height: parent.barH
                    radius: width

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: effect.secondaryColor }
                        GradientStop { position: 1.0; color: effect.accentColor }
                    }
                }
            }
        }
    }
}
