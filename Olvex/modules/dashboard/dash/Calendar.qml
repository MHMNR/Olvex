import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Olvex.Config
import Olvex.Services
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property DashboardState dashState

    readonly property var now: new Date()
    readonly property int currMonth: dashState.currentDate.getMonth()
    readonly property int currYear: dashState.currentDate.getFullYear()
    readonly property var locale: Qt.locale()
    readonly property string monthLabel: locale.standaloneMonthName(currMonth, Locale.LongFormat).toUpperCase()
    readonly property int todayDay: now.getDate()
    readonly property string todayWeekday: locale.dayName(now.getDay(), Locale.LongFormat)
    readonly property bool isCurrentMonth: currMonth === now.getMonth() && currYear === now.getFullYear()

    readonly property real contentWidth: root.width > 28 ? (root.width - 28) : 312
    readonly property real colWidth: contentWidth / 7

    function shiftMonth(delta) {
        dashState.currentDate = new Date(currYear, currMonth + delta, 1)
    }

    component NavBtn: StyledRect {
        id: btn
        property string icon: ""
        signal triggered()

        implicitWidth: 24
        implicitHeight: 24
        radius: width / 2
        color: btnMa.containsMouse
            ? (Colours.light ? Colours.tileFillHover : Qt.alpha(Colours.palette.m3onSurface, 0.08))
            : "transparent"

        MaterialIcon {
            anchors.centerIn: parent
            text: btn.icon
            color: Colours.palette.m3onSurfaceVariant
            iconPointSize: 14
        }

        MouseArea {
            id: btnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.triggered()
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            if (event.angleDelta.y > 0)
                root.shiftMonth(-1)
            else if (event.angleDelta.y < 0)
                root.shiftMonth(1)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // Complication strip — today always legible at a glance
        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: Tokens.rounding.small
            color: Colours.tileFill
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.2)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 3
                    Layout.preferredHeight: 24
                    Layout.alignment: Qt.AlignVCenter
                    radius: 1.5
                    color: Colours.palette.m3primary
                }

                MouseArea {
                    Layout.preferredWidth: todayCol.implicitWidth
                    Layout.fillHeight: true
                    enabled: !root.isCurrentMonth
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: dashState.currentDate = new Date()

                    ColumnLayout {
                        id: todayCol
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: -1

                        StyledText {
                            text: root.todayDay
                            color: Colours.palette.m3onSurface
                            textPointSize: Tokens.font.size.larger
                            font.weight: Font.DemiBold
                        }

                        StyledText {
                            text: root.todayWeekday
                            color: Colours.palette.m3onSurfaceVariant
                            textPointSize: Tokens.font.size.small
                            font.weight: Font.Medium
                            opacity: 0.75
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 22
                    Layout.alignment: Qt.AlignVCenter
                    color: Qt.alpha(Colours.palette.m3outlineVariant, 0.35)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0

                    StyledText {
                        text: root.monthLabel
                        color: Colours.palette.m3onSurface
                        textPointSize: Tokens.font.size.small
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.8
                    }

                    StyledText {
                        text: root.currYear
                        color: Colours.palette.m3onSurfaceVariant
                        textPointSize: Tokens.font.size.smaller
                        opacity: 0.65
                    }
                }

                NavBtn {
                    Layout.alignment: Qt.AlignVCenter
                    icon: "chevron_left"
                    onTriggered: root.shiftMonth(-1)
                }

                NavBtn {
                    Layout.alignment: Qt.AlignVCenter
                    icon: "chevron_right"
                    onTriggered: root.shiftMonth(1)
                }
            }
        }

        DayOfWeekRow {
            id: dayOfWeekRow
            Layout.fillWidth: true
            locale: monthGrid.locale
            spacing: 0
            padding: 0
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0

            delegate: Item {
                required property var model

                width: root.colWidth
                implicitWidth: root.colWidth
                implicitHeight: 18

                StyledText {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: dayOfWeekRow.locale.dayName(model.day, Locale.ShortFormat).toUpperCase()
                    textPointSize: Tokens.font.size.smaller
                    font.weight: Font.Medium
                    font.letterSpacing: 0.6
                    color: Colours.palette.m3onSurfaceVariant
                    opacity: 0.55
                }
            }
        }

        Item {
            id: monthGridArea

            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property real cellHeight: height > 0 ? height / 6 : 24

            // Sliding today marker — underline that travels with the date
            Rectangle {
                id: todayMark

                readonly property Item todayCell: {
                    if (!monthGrid.contentItem || !monthGrid.contentItem.children) return null;
                    const kids = monthGrid.contentItem.children;
                    for (let i = 0; i < kids.length; ++i) {
                        const c = kids[i];
                        if (c.model && c.model.today && c.model.month === monthGrid.month) {
                            return c;
                        }
                    }
                    return null;
                }

                width: todayCell ? 18 : 0
                height: 2
                radius: 1
                color: Colours.palette.m3primary
                visible: todayCell !== null && root.isCurrentMonth
                x: todayCell ? todayCell.x + (todayCell.width - width) / 2 : 0
                y: todayCell ? todayCell.y + todayCell.height - 2 : 0

                Behavior on x {
                    Anim { type: Anim.DefaultSpatial }
                }
                Behavior on y {
                    Anim { type: Anim.DefaultSpatial }
                }
            }

            MonthGrid {
                id: monthGrid

                anchors.fill: parent
                month: root.currMonth
                year: root.currYear
                spacing: 0
                padding: 0
                leftPadding: 0
                rightPadding: 0
                topPadding: 0
                bottomPadding: 0
                locale: root.locale

                delegate: Item {
                    id: dayCell

                    required property var model

                    width: root.colWidth
                    implicitWidth: root.colWidth
                    height: monthGridArea.cellHeight
                    implicitHeight: monthGridArea.cellHeight

                    readonly property bool inMonth: model.month === monthGrid.month
                    readonly property bool isToday: model.today

                    StyledText {
                        id: dayLabel
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Tokens.font.family.mono
                        text: {
                            const d = Number(dayCell.model.day)
                            return d < 10 ? ("0" + d) : String(d)
                        }
                        textPointSize: Tokens.font.size.smaller
                        font.weight: dayCell.isToday && dayCell.inMonth ? Font.DemiBold : Font.Normal
                        color: dayCell.isToday && dayCell.inMonth
                            ? Colours.palette.m3primary
                            : Colours.palette.m3onSurface
                        opacity: dayCell.inMonth ? (dayCell.isToday ? 1 : 0.85) : 0.22
                    }
                }
            }
        }
    }
}