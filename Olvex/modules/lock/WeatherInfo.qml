pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

ColumnLayout {
    id: root

    required property int rootHeight

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: 12
    spacing: 10

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.padding.large
        Layout.bottomMargin: Tokens.padding.small

        StyledText {
            Layout.fillWidth: true
            text: qsTr("WEATHER")
            color: Colours.palette.m3outline
            font.family: Tokens.font.family.mono
            textPointSize: Tokens.font.size.smaller
            font.weight: 600
        }

        MaterialIcon {
            text: "cloud_queue"
            color: Colours.palette.m3primary
            iconPointSize: Tokens.font.size.large
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.padding.large
        spacing: Tokens.spacing.large

        StyledText {
            text: Weather.temp
            color: Colours.current.m3onSurface
            textPointSize: 32
            font.weight: 600
        }

        ColumnLayout {
            spacing: 2
            
            StyledText {
                text: Weather.description
                color: Colours.current.m3onSurface
                textPointSize: Tokens.font.size.small
                font.weight: 500
            }

            StyledText {
                text: qsTr("Humidity: %1%").arg(Weather.humidity)
                color: Colours.current.m3primary
                textPointSize: Tokens.font.size.small
            }
        }
    }
}
