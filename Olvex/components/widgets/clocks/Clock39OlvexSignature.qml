import QtQuick
import QtQuick.Layouts
import M3Shapes
import Olvex.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    property int variant: 0 // 0: Morph Dial, 1: Hero Card
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property color surfaceColor: Colours.palette.m3surfaceContainerHigh
    property color surfaceHighColor: Colours.palette.m3surfaceContainerHighest
    property bool showDatePill: true

    readonly property real s: 0.90 * clockScale
    readonly property string userLabel: (SysInfo.user || "USER").toUpperCase()
    readonly property var morphShapes: [
        MaterialShape.Circle,
        MaterialShape.Square,
        MaterialShape.Slanted,
        MaterialShape.Arch,
        MaterialShape.Oval,
        MaterialShape.Pill,
        MaterialShape.Diamond,
        MaterialShape.ClamShell,
        MaterialShape.Pentagon,
        MaterialShape.Gem,
        MaterialShape.Sunny,
        MaterialShape.VerySunny,
        MaterialShape.Cookie4Sided,
        MaterialShape.Cookie6Sided,
        MaterialShape.Cookie7Sided,
        MaterialShape.Cookie9Sided,
        MaterialShape.Cookie12Sided,
        MaterialShape.Ghostish,
        MaterialShape.Clover4Leaf,
        MaterialShape.Clover8Leaf,
        MaterialShape.Burst,
        MaterialShape.SoftBurst,
        MaterialShape.SoftBoom,
        MaterialShape.Flower,
        MaterialShape.Puffy,
        MaterialShape.PuffyDiamond
    ]
    property real smoothSeconds: 0
    property real morphClock: 0

    function tick(dt) {
        morphClock += dt * 0.48;
        const now = new Date();
        smoothSeconds = now.getSeconds() + now.getMilliseconds() / 1000.0;
    }

    Component.onCompleted: {
        Time.secondsRefCount++;
        tick(0);
    }
    Component.onDestruction: Time.secondsRefCount--

    FrameAnimation {
        running: root.visible
        onTriggered: root.tick(frameTime)
    }

    implicitWidth: variant === 0 ? hybridCard.implicitWidth : heroCard.implicitWidth
    implicitHeight: variant === 0 ? hybridCard.implicitHeight : heroCard.implicitHeight

    // Variant 0: Smooth Continuous Morphing Dial + User Digital Readout
    StyledRect {
        id: hybridCard
        anchors.centerIn: parent
        visible: root.variant === 0
        implicitWidth: Math.round(258 * root.s)
        implicitHeight: Math.round(140 * root.s)
        radius: Math.round(30 * root.s)
        color: root.surfaceColor

        RowLayout {
            anchors.fill: parent
            anchors.margins: Math.round(14 * root.s)
            spacing: Math.round(14 * root.s)

            // Left: Smoothly & continuously morphing M3Shapes dial across 26 shapes
            Item {
                Layout.alignment: Qt.AlignVCenter
                width: Math.round(108 * root.s)
                height: width

                MaterialShape {
                    anchors.fill: parent
                    implicitSize: width
                    color: root.surfaceHighColor
                    readonly property int idxA: Math.floor(root.morphClock) % root.morphShapes.length
                    readonly property int idxB: (idxA + 1) % root.morphShapes.length
                    readonly property real rawT: root.morphClock - Math.floor(root.morphClock)
                    fromShape: root.morphShapes[idxA]
                    toShape: root.morphShapes[idxB]
                    morphProgress: 0.5 - 0.5 * Math.cos(rawT * Math.PI)
                }

                SlottedHand {
                    angleDeg: (Time.hours % 12) * 30 + Time.minutes * 0.5
                    handLength: parent.height * 0.24
                    handWidth: Math.max(3.5, parent.width * 0.06)
                    handColor: root.primaryColor
                    slotColor: root.surfaceHighColor
                }

                SlottedHand {
                    angleDeg: Time.minutes * 6 + Time.seconds * 0.1
                    handLength: parent.height * 0.35
                    handWidth: Math.max(2.5, parent.width * 0.042)
                    handColor: root.onSurfaceColor
                    slotColor: root.surfaceHighColor
                }

                ContinuousSecondHand {
                    handLength: parent.height * 0.39
                    handWidth: Math.max(1.5, 1.8 * root.clockScale)
                    handColor: root.tertiaryColor
                    active: root.visible && root.variant === 0
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.max(5, Math.round(parent.width * 0.08))
                    height: width
                    radius: width / 2
                    color: root.tertiaryColor
                }
            }

            // Right: Username Pill + Time + Date + Full-width Seconds Rail
            ColumnLayout {
                id: rightCol
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Math.round(5 * root.s)

                StyledRect {
                    Layout.alignment: Qt.AlignLeft
                    Layout.maximumWidth: rightCol.width
                    implicitWidth: Math.round(userTxt.implicitWidth + 16 * root.s)
                    implicitHeight: Math.round(userTxt.implicitHeight + 5 * root.s)
                    radius: height / 2
                    color: Colours.palette.m3primaryContainer

                    StyledText {
                        id: userTxt
                        anchors.centerIn: parent
                        text: root.userLabel
                        color: Colours.palette.m3onPrimaryContainer
                        textPointSize: Math.max(6, Math.round(8 * root.s))
                        font.family: Tokens.font.family.sans
                        font.weight: Font.Black
                        font.letterSpacing: 1.4 * root.s
                        elide: Text.ElideRight
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Time.hourStr + ":" + Time.minuteStr
                    color: root.primaryColor
                    textPointSize: Math.max(14, Math.round(28 * root.s))
                    font.family: Tokens.font.family.sans
                    font.weight: Font.Black
                    font.letterSpacing: -0.8 * root.s
                }

                StyledText {
                    visible: root.showDatePill
                    Layout.fillWidth: true
                    text: (Time.format("ddd") + " • " + Time.format("d MMM")).toUpperCase()
                    color: root.secondaryColor
                    textPointSize: Math.max(6, Math.round(8.5 * root.s))
                    font.family: Tokens.font.family.sans
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.7 * root.s
                    elide: Text.ElideRight
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.topMargin: Math.round(2 * root.s)
                    height: Math.max(3, Math.round(4 * root.s))
                    radius: height / 2
                    color: Qt.alpha(root.onSurfaceColor, 0.14)

                    StyledRect {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(height, parent.width * (root.smoothSeconds / 60.0))
                        radius: height / 2
                        color: root.tertiaryColor
                    }
                }
            }
        }
    }

    // Variant 1: Hero Card (Username Pill + Giant Typo + Live Seconds)
    StyledRect {
        id: heroCard
        anchors.centerIn: parent
        visible: root.variant === 1
        implicitWidth: Math.round(258 * root.s)
        implicitHeight: Math.round(140 * root.s)
        radius: Math.round(30 * root.s)
        color: Colours.palette.m3primaryContainer

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - Math.round(30 * root.s)
            spacing: Math.round(6 * root.s)

            RowLayout {
                Layout.fillWidth: true

                StyledRect {
                    Layout.maximumWidth: Math.round(heroCard.width * 0.65)
                    implicitWidth: Math.round(heroUser.implicitWidth + 16 * root.s)
                    implicitHeight: Math.round(heroUser.implicitHeight + 5 * root.s)
                    radius: height / 2
                    color: Colours.palette.m3onPrimaryContainer

                    StyledText {
                        id: heroUser
                        anchors.centerIn: parent
                        text: root.userLabel
                        color: Colours.palette.m3primaryContainer
                        textPointSize: Math.max(6, Math.round(8 * root.s))
                        font.family: Tokens.font.family.sans
                        font.weight: Font.Black
                        font.letterSpacing: 1.4 * root.s
                        elide: Text.ElideRight
                    }
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    text: String(Time.seconds).padStart(2, "0") + "S"
                    color: Qt.alpha(Colours.palette.m3onPrimaryContainer, 0.78)
                    textPointSize: Math.max(7, Math.round(9.5 * root.s))
                    font.family: Tokens.font.family.mono
                    font.weight: Font.Bold
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Time.hourStr + ":" + Time.minuteStr
                color: Colours.palette.m3onPrimaryContainer
                textPointSize: Math.max(18, Math.round(44 * root.s))
                font.family: Tokens.font.family.sans
                font.weight: Font.Black
                font.letterSpacing: -1.5 * root.s
            }

            StyledText {
                visible: root.showDatePill
                Layout.alignment: Qt.AlignHCenter
                text: (Time.format("dddd") + " • " + Time.format("d MMM")).toUpperCase()
                color: Qt.alpha(Colours.palette.m3onPrimaryContainer, 0.80)
                textPointSize: Math.max(6, Math.round(8.5 * root.s))
                font.family: Tokens.font.family.sans
                font.weight: Font.DemiBold
                font.letterSpacing: 1.1 * root.s
            }
        }
    }
}
