import QtQuick
import QtQuick.Layouts
import qs.components
import qs.components.effects
import qs.services
import Olvex.Config

Item {
    id: root

    readonly property color accentColor: Colours.palette.m3primary
    readonly property color softAccentColor: Colours.palette.m3secondary
    readonly property color textColor: "#fff4fb"

    Component.onCompleted: Weather.reload()

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        MaterialIcon {
            Layout.preferredWidth: 48
            animate: true
            text: Weather.icon
            color: root.softAccentColor
            font.pointSize: 32
            fill: 1
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                text: Weather.temp
                color: root.accentColor
                font.pointSize: 18
                font.weight: 800
            }

            StyledText {
                Layout.fillWidth: true
                text: Weather.description
                color: Qt.alpha(root.textColor, 0.7)
                font.pointSize: 9
                font.weight: 500
                elide: Text.ElideRight
            }
        }

        StyledRect {
            Layout.preferredWidth: 72
            Layout.preferredHeight: 56
            radius: 12
            color: Qt.alpha("#27233d", 0.4)
            border.color: Qt.alpha("#ffffff", 0.04)
            border.width: 1

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 6

                StatRow {
                    icon: "water_drop"
                    text: `${Weather.humidity}%`
                }

                StatRow {
                    icon: "air"
                    text: `${Math.round(Weather.windSpeed)}`
                }
            }
        }
    }

    component StatRow: RowLayout {
        required property string icon
        required property string text

        spacing: 6

        MaterialIcon {
            text: parent.icon
            color: root.accentColor
            font.pointSize: 12
            fill: 1
        }

        StyledText {
            text: parent.text
            color: root.textColor
            font.pointSize: 10
            font.weight: 600
        }

    }

}
