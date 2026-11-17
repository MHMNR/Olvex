import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Tonal Bento, 1: Minimal Surface
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property color surfaceColor: Colours.palette.m3surfaceContainerHigh
    property color surfaceHighColor: Colours.palette.m3surfaceContainerHighest
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
        running: root.visible
        onTriggered: root.syncSeconds()
    }

    implicitWidth: Math.round(212 * s)
    implicitHeight: Math.round(156 * s)

    StyledRect {
        anchors.fill: parent
        radius: Math.round(28 * root.s)
        color: root.surfaceColor

        RowLayout {
            anchors.fill: parent
            anchors.margins: Math.round(10 * root.s)
            spacing: Math.round(8 * root.s)

            // Left: Primary tonal time block (HH / MM)
            StyledRect {
                Layout.fillHeight: true
                Layout.preferredWidth: Math.round(102 * root.s)
                radius: Math.round(20 * root.s)
                color: root.variant === 0
                    ? Colours.palette.m3primaryContainer
                    : root.surfaceHighColor

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Math.round(-6 * root.s)

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Time.hourStr
                        color: root.variant === 0
                            ? Colours.palette.m3onPrimaryContainer
                            : root.primaryColor
                        textPointSize: Math.max(15, Math.round(36 * root.s))
                        font.family: Tokens.font.family.sans
                        font.weight: Font.Black
                        font.letterSpacing: -1.0 * root.s
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Time.minuteStr
                        color: root.variant === 0
                            ? Qt.alpha(Colours.palette.m3onPrimaryContainer, 0.82)
                            : root.onSurfaceColor
                        textPointSize: Math.max(15, Math.round(36 * root.s))
                        font.family: Tokens.font.family.sans
                        font.weight: Font.DemiBold
                        font.letterSpacing: -1.0 * root.s
                    }
                }
            }

            // Right: Stacked Date Badge + Live Seconds / AM-PM Tile
            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                spacing: Math.round(8 * root.s)

                // Top-right: Day Number + Month tonal badge
                StyledRect {
                    visible: root.showDatePill
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Math.round(20 * root.s)
                    color: root.variant === 0
                        ? Colours.palette.m3tertiaryContainer
                        : Colours.palette.m3primaryContainer

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Math.round(-2 * root.s)

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Time.format("d")
                            color: root.variant === 0
                                ? Colours.palette.m3onTertiaryContainer
                                : Colours.palette.m3onPrimaryContainer
                            textPointSize: Math.max(12, Math.round(22 * root.s))
                            font.family: Tokens.font.family.sans
                            font.weight: Font.Black
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Time.format("MMM").toUpperCase()
                            color: Qt.alpha(root.variant === 0
                                ? Colours.palette.m3onTertiaryContainer
                                : Colours.palette.m3onPrimaryContainer, 0.78)
                            textPointSize: Math.max(6, Math.round(8.5 * root.s))
                            font.family: Tokens.font.family.sans
                            font.weight: Font.Bold
                            font.letterSpacing: 1.0 * root.s
                        }
                    }
                }

                // Bottom-right: Weekday + Live Seconds Progress Tile
                StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(58 * root.s)
                    radius: Math.round(18 * root.s)
                    color: root.variant === 0
                        ? Colours.palette.m3secondaryContainer
                        : root.surfaceHighColor

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - Math.round(16 * root.s)
                        spacing: Math.round(5 * root.s)

                        RowLayout {
                            Layout.fillWidth: true

                            StyledText {
                                text: Time.format("ddd").toUpperCase()
                                color: root.variant === 0
                                    ? Colours.palette.m3onSecondaryContainer
                                    : root.onSurfaceColor
                                textPointSize: Math.max(7, Math.round(9.5 * root.s))
                                font.family: Tokens.font.family.sans
                                font.weight: Font.Black
                            }

                            Item { Layout.fillWidth: true }

                            StyledText {
                                text: String(Time.seconds).padStart(2, "0")
                                color: root.variant === 0
                                    ? Colours.palette.m3onSecondaryContainer
                                    : root.primaryColor
                                textPointSize: Math.max(7, Math.round(9.5 * root.s))
                                font.family: Tokens.font.family.mono
                                font.weight: Font.Bold
                            }
                        }

                        // Smooth continuous 60s progress bar
                        StyledRect {
                            Layout.fillWidth: true
                            height: Math.max(3, Math.round(4 * root.s))
                            radius: height / 2
                            color: Qt.alpha(root.variant === 0
                                ? Colours.palette.m3onSecondaryContainer
                                : root.onSurfaceColor, 0.16)

                            StyledRect {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(height, parent.width * (root.smoothSeconds / 60.0))
                                radius: height / 2
                                color: root.variant === 0
                                    ? Colours.palette.m3onSecondaryContainer
                                    : root.tertiaryColor
                            }
                        }
                    }
                }
            }
        }
    }
}
