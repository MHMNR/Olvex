import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Tonal Card, 1: Floating Dots
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property bool showDatePill: true

    readonly property real s: 0.90 * clockScale

    Component.onCompleted: Time.secondsRefCount++
    Component.onDestruction: Time.secondsRefCount--

    implicitWidth: Math.round(210 * s)
    implicitHeight: Math.round(142 * s)

    StyledRect {
        anchors.fill: parent
        radius: Math.round(26 * root.s)
        color: root.variant === 0 ? Colours.palette.m3surfaceContainerHigh : "transparent"

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Math.round(10 * root.s)

            // 6 BCD columns: H1, H2, M1, M2, S1, S2 (4 bits each)
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Math.round(10 * root.s)

                Repeater {
                    model: {
                        const h = Time.hourStr;
                        const m = Time.minuteStr;
                        const sec = String(Time.seconds).padStart(2, "0");
                        return [
                            { digit: parseInt(h[0] || "0"), col: root.primaryColor },
                            { digit: parseInt(h[1] || "0"), col: root.primaryColor },
                            { digit: parseInt(m[0] || "0"), col: root.onSurfaceColor },
                            { digit: parseInt(m[1] || "0"), col: root.onSurfaceColor },
                            { digit: parseInt(sec[0] || "0"), col: root.tertiaryColor },
                            { digit: parseInt(sec[1] || "0"), col: root.tertiaryColor }
                        ];
                    }

                    ColumnLayout {
                        required property var modelData
                        spacing: Math.round(5 * root.s)

                        Repeater {
                            model: 4
                            StyledRect {
                                required property int index
                                readonly property int bit: 3 - index
                                readonly property bool isOn: ((modelData.digit >> bit) & 1) === 1
                                width: Math.round(15 * root.s)
                                height: width
                                radius: width / 2
                                color: isOn ? modelData.col : Qt.alpha(root.onSurfaceColor, 0.14)
                                Behavior on color {
                                    CAnim { duration: Tokens.anim.durations.small }
                                }
                            }
                        }
                    }
                }
            }

            StyledText {
                visible: root.showDatePill
                Layout.alignment: Qt.AlignHCenter
                text: Time.hourStr + ":" + Time.minuteStr + ":" + String(Time.seconds).padStart(2, "0") + " • " + Time.format("ddd d").toUpperCase()
                color: root.secondaryColor
                textPointSize: Math.max(6, Math.round(8.5 * root.s))
                font.family: Tokens.font.family.mono
                font.weight: Font.Bold
                font.letterSpacing: 0.8 * root.s
            }
        }
    }
}

