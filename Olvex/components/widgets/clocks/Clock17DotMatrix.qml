import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    property int variant: 0 // 0: Tonal Card, 1: Floating Matrix
    property real clockScale: 1.0
    property color primaryColor: Colours.palette.m3primary
    property color secondaryColor: Colours.palette.m3secondary
    property color tertiaryColor: Colours.palette.m3tertiary
    property color onSurfaceColor: Colours.palette.m3onSurface
    property color surfaceColor: Colours.palette.m3surfaceContainerHigh
    property color surfaceHighColor: Colours.palette.m3surfaceContainerHighest
    property bool showDatePill: true

    readonly property real s: 0.88 * clockScale

    Component.onCompleted: Time.secondsRefCount++
    Component.onDestruction: Time.secondsRefCount--

    implicitWidth: Math.round(236 * s)
    implicitHeight: Math.round(126 * s)

    StyledRect {
        anchors.fill: parent
        radius: Math.round(26 * root.s)
        color: root.variant === 0 ? root.surfaceColor : "transparent"

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Math.round(10 * root.s)

            Canvas {
                id: matrixCanvas
                Layout.alignment: Qt.AlignHCenter
                width: Math.round(196 * root.s)
                height: Math.round(62 * root.s)

                property string hStr: Time.hourStr
                property string mStr: Time.minuteStr
                property int secVal: Time.seconds
                property color onCol: root.primaryColor
                property color accentCol: root.tertiaryColor
                property color offCol: Qt.alpha(root.onSurfaceColor, 0.11)

                onHStrChanged: requestPaint()
                onMStrChanged: requestPaint()
                onSecValChanged: requestPaint()
                onOnColChanged: requestPaint()
                onAccentColChanged: requestPaint()
                onOffColChanged: requestPaint()
                onWidthChanged: requestPaint()

                readonly property var glyphs: ({
                    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
                    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
                    "2": ["01110", "10001", "00001", "00110", "01000", "10000", "11111"],
                    "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
                    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
                    "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
                    "6": ["01110", "10000", "11110", "10001", "10001", "10001", "01110"],
                    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
                    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
                    "9": ["01110", "10001", "10001", "01111", "00001", "00001", "01110"]
                })

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const w = width, h = height;
                    if (w <= 4 || h <= 4)
                        return;

                    // 4 digits (5 cols each) + 1 colon (1 col) + gaps (1 col * 4) = 25 cols, 7 rows
                    const totalCols = 25;
                    const totalRows = 7;
                    const stepX = w / totalCols;
                    const stepY = h / totalRows;
                    const r = Math.min(stepX, stepY) * 0.36;

                    function drawDigit(ch, startCol) {
                        const g = glyphs[ch] || glyphs["0"];
                        for (let row = 0; row < 7; row++) {
                            for (let col = 0; col < 5; col++) {
                                const lit = g[row][col] === "1";
                                ctx.fillStyle = lit ? onCol : offCol;
                                ctx.beginPath();
                                ctx.arc((startCol + col + 0.5) * stepX, (row + 0.5) * stepY, r, 0, Math.PI * 2);
                                ctx.fill();
                            }
                        }
                    }

                    drawDigit(hStr[0] || "0", 0);
                    drawDigit(hStr[1] || "0", 6);

                    // Colon at col 12, rows 2 and 4
                    const colonLit = (secVal % 2) === 0;
                    ctx.fillStyle = colonLit ? accentCol : offCol;
                    ctx.beginPath();
                    ctx.arc(12.5 * stepX, 2.5 * stepY, r * 1.1, 0, Math.PI * 2);
                    ctx.fill();
                    ctx.beginPath();
                    ctx.arc(12.5 * stepX, 4.5 * stepY, r * 1.1, 0, Math.PI * 2);
                    ctx.fill();

                    drawDigit(mStr[0] || "0", 14);
                    drawDigit(mStr[1] || "0", 20);
                }
            }

            StyledText {
                visible: root.showDatePill
                Layout.alignment: Qt.AlignHCenter
                text: (Time.format("ddd") + " • " + Time.format("d MMM") + " • " + String(Time.seconds).padStart(2, "0")).toUpperCase()
                color: root.secondaryColor
                textPointSize: Math.max(6, Math.round(9 * root.s))
                font.family: Tokens.font.family.mono
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2 * root.s
            }
        }
    }
}

