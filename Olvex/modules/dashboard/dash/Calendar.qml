import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Olvex.Config
import Olvex.Services
import qs.components
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    required property DashboardState dashState

    readonly property color accentColor: Colours.palette.m3primary
    readonly property color textColor: "#ffffff"
    readonly property color mutedColor: Qt.alpha("#ffffff", 0.4)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        // Header
        RowLayout {
            Layout.fillWidth: true

            HeaderButton {
                icon: "chevron_left"
                onClicked: monthGrid.month--
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: monthGrid.title
                color: root.accentColor
                font.pointSize: 14
                font.weight: 700
                font.capitalization: Font.Capitalize
            }

            HeaderButton {
                icon: "chevron_right"
                onClicked: monthGrid.month++
            }
        }

        // Days Grid
        MonthGrid {
            id: monthGrid
            Layout.fillWidth: true
            Layout.fillHeight: true

            delegate: Item {
                id: dayCell
                required property var model

                implicitWidth: implicitHeight
                implicitHeight: 32

                // Today Highlight
                StyledRect {
                    anchors.centerIn: parent
                    width: 26; height: 26; radius: 13
                    color: "transparent"
                    border.color: root.accentColor
                    border.width: 2
                    visible: model.today

                    Elevation {
                        anchors.fill: parent
                        level: 2
                        color: Qt.alpha(root.accentColor, 0.35)
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    text: dayCell.model.day
                    color: {
                        if (dayCell.model.today) return "#ffffff";
                        if (dayCell.model.dayOfWeek === 0 || dayCell.model.dayOfWeek === 6) return root.accentColor;
                        return dayCell.model.month === monthGrid.month ? root.textColor : root.mutedColor;
                    }
                    font.pointSize: 11
                    font.weight: dayCell.model.today ? 700 : 500
                    opacity: dayCell.model.month === monthGrid.month ? 1 : 0.3
                }
            }
        }
    }

    component HeaderButton: StyledRect {
        id: btn
        required property string icon
        signal clicked()

        implicitWidth: 28; implicitHeight: 28; radius: 8
        color: Qt.alpha(root.accentColor, 0.08)
        border.color: Qt.alpha(root.accentColor, 0.15)
        border.width: 1

        MaterialIcon {
            anchors.centerIn: parent
            text: btn.icon
            color: root.accentColor
            font.pointSize: 14
        }

        MouseArea {
            anchors.fill: parent
            onClicked: btn.clicked()
        }
    }
}
