
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

    function shiftMonth(delta) {
        dashState.currentDate = new Date(currYear, currMonth + delta, 1)
    }

    component NavBtn: StyledRect {
        id: btn
        property string icon: ""
        signal triggered()

        implicitWidth: 22
        implicitHeight: 22
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
        anchors.margins: 12
        spacing: 8

        // Complication strip — today always legible at a glance
        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: Tokens.rounding.small
            color: Colours.tileFill

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 6
                anchors.topMargin: -3
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 3
                    Layout.fillHeight: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
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
                        anchors.verticalCenterOffset: -3
                        spacing: -2

                        StyledText {
                            text: root.todayDay
                            color: Colours.palette.m3onSurface
                            textPointSize: Tokens.font.size.extraLarge
                            font.weight: Font.Light
                        }

                        StyledText {
                            text: root.todayWeekday
                            color: Colours.palette.m3onSurfaceVariant
                            textPointSize: Tokens.font.size.smaller
                            font.weight: Font.Medium
                            opacity: 0.75
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    Layout.topMargin: 6
                    Layout.bottomMargin: 6
                    color: Qt.alpha(Colours.palette.m3outlineVariant, 0.35)
                }

                ColumnLayout {
                    Layout.fillWidth: true
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
                    icon: "chevron_left"
                    onTriggered: root.shiftMonth(-1)
                }

                NavBtn {
                    icon: "chevron_right"
                    onTriggered: root.shiftMonth(1)
                }
            }
        }

        DayOfWeekRow {
            Layout.fillWidth: true
            locale: monthGrid.locale

            delegate: StyledText {
                required property var model

                horizontalAlignment: Text.AlignHCenter
                text: locale.dayName(model.day, Locale.ShortFormat).toUpperCase()
                textPointSize: Tokens.font.size.smaller
                font.weight: Font.Medium
                font.letterSpacing: 0.6
                color: Colours.palette.m3onSurfaceVariant
                opacity: 0.45
            }
        }

        Item {
            id: monthGridArea

            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property real cellHeight: height > 0 ? height / 6 : 28

            // Sliding today marker — underline that travels with the date
            Rectangle {
                id: todayMark

                readonly property Item todayCell: monthGrid.contentItem.children.find(
                    c => c.model && c.model.today && c.model.month === monthGrid.month) ?? null

                width: todayCell ? 16 : 0
                height: 2
                radius: 1
                color: Colours.palette.m3primary
                visible: todayCell !== null
                x: todayCell ? todayCell.x + (todayCell.width - width) / 2 : 0
                y: todayCell ? todayCell.y + todayCell.height - 3 : 0

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
                locale: root.locale

                delegate: Item {
                    id: dayCell

                    required property var model

                    implicitWidth: implicitHeight
                    implicitHeight: monthGridArea.cellHeight

                    readonly property bool inMonth: model.month === monthGrid.month
                    readonly property bool isToday: model.today

                    StyledText {
                        id: dayLabel
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: dayCell.isToday && dayCell.inMonth ? -1 : 0
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
                        opacity: dayCell.inMonth ? (dayCell.isToday ? 1 : 0.82) : 0.22
                    }
                }
            }
        }
    }
}