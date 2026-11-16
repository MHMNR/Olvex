import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Vertical Bar, 1: Dot Divider
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property bool showDatePill: true

    readonly property real s: 0.90 * clockScale
    property real smoothSeconds: 0

    function syncSeconds() {
        const now = new Date();
        smoothSeconds = now.getSeconds() + now.getMilliseconds() / 1000.0;
    }

    Component.onCompleted: {
        Time.secondsRefCount++;
        syncSeconds();
    }
    Component.onDestruction: Time.secondsRefCount--

    FrameAnimation {
        running: root.visible && root.variant === 0
        onTriggered: root.syncSeconds()
    }

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: Math.round(6 * root.s)

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Math.round(12 * root.s)

            StyledText {
                text: Time.hourStr
                color: root.primaryColor
                textPointSize: Math.max(20, Math.round(54 * root.s))
                font.family: Tokens.font.family.clock
                font.weight: Font.Black
            }

            // Variant 0: Smooth vertical seconds level bar
            StyledRect {
                visible: root.variant === 0
                width: Math.max(4, Math.round(6 * root.s))
                height: Math.round(52 * root.s)
                radius: width / 2
                color: Qt.alpha(root.onSurfaceColor, 0.16)

                StyledRect {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Math.max(width, parent.height * (root.smoothSeconds / 60.0))
                    radius: width / 2
                    color: root.tertiaryColor
                }
            }

            // Variant 1: Pulsing twin dots
            ColumnLayout {
                visible: root.variant === 1
                spacing: Math.round(10 * root.s)

                Repeater {
                    model: 2
                    StyledRect {
                        width: Math.max(5, Math.round(8 * root.s))
                        height: width
                        radius: width / 2
                        color: root.tertiaryColor
                        opacity: (Time.seconds % 2 === 0) ? 1.0 : 0.3
                        Behavior on opacity {
                            Anim { duration: Tokens.anim.durations.small }
                        }
                    }
                }
            }

            StyledText {
                text: Time.minuteStr
                color: root.onSurfaceColor
                textPointSize: Math.max(20, Math.round(54 * root.s))
                font.family: Tokens.font.family.clock
                font.weight: Font.Light
            }
        }

        StyledText {
            visible: root.showDatePill
            Layout.alignment: Qt.AlignHCenter
            text: (Time.format("dddd") + " • " + Time.format("d MMM")).toUpperCase()
            color: root.secondaryColor
            textPointSize: Math.max(6, Math.round(9 * root.s))
            font.family: Tokens.font.family.sans
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2 * root.s
        }
    }
}

