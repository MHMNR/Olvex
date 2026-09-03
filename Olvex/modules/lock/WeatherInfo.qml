
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

ColumnLayout {
    id: root

    required property int rootHeight

    anchors.fill: parent
    anchors.margins: Tokens.padding.large
    spacing: Tokens.spacing.normal

    // ── Header Bar ───────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        StyledRect {
            implicitWidth: 24
            implicitHeight: 24
            radius: Tokens.rounding.small
            color: Qt.alpha(Colours.palette.m3primary, 0.15)

            MaterialIcon {
                anchors.centerIn: parent
                text: Weather.icon || "cloud"
                color: Colours.palette.m3primary
                iconPointSize: 14
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: (Weather.city || qsTr("WEATHER")).toUpperCase()
            color: Colours.palette.m3outline
            font.family: Tokens.font.family.mono
            textPointSize: Tokens.font.size.smaller
            font.weight: Font.Bold
            font.letterSpacing: 1
            elide: Text.ElideRight
        }
    }

    // ── Hero Temperature Row ──────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.large

        StyledText {
            text: Weather.temp || "27°C"
            color: Colours.palette.m3onSurface
            textPointSize: 36
            font.weight: Font.Black
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                text: Weather.description || qsTr("Overcast")
                color: Colours.palette.m3onSurface
                textPointSize: Tokens.font.size.normal
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            StyledText {
                text: Weather.todayHighLow ? `${Weather.todayHighLow} • Feels ${Weather.feelsLike}` : qsTr("Feels like %1").arg(Weather.feelsLike || Weather.temp || "27°C")
                color: Colours.palette.m3outline
                textPointSize: Tokens.font.size.smaller
                elide: Text.ElideRight
            }
        }
    }

    // ── Enriched 4-Chip Info Grid (Humidity, Wind, Sunrise, Sunset) ─────────
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 6

        // Humidity Chip
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 26
            radius: Tokens.rounding.small
            color: Qt.alpha(Colours.palette.m3tertiary, 0.12)

            RowLayout {
                anchors.centerIn: parent
                spacing: 4

                MaterialIcon {
                    text: "water_drop"
                    color: Colours.palette.m3tertiary
                    iconPointSize: 11
                }

                StyledText {
                    text: `${Weather.humidity}%`
                    color: Colours.palette.m3tertiary
                    textPointSize: Tokens.font.size.smaller - 1
                    font.weight: Font.Bold
                }
            }
        }

        // Wind Chip
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 26
            radius: Tokens.rounding.small
            color: Qt.alpha(Colours.palette.m3secondary, 0.12)

            RowLayout {
                anchors.centerIn: parent
                spacing: 4

                MaterialIcon {
                    text: "air"
                    color: Colours.palette.m3secondary
                    iconPointSize: 11
                }

                StyledText {
                    text: Weather.windLabel || "12 km/h"
                    color: Colours.palette.m3secondary
                    textPointSize: Tokens.font.size.smaller - 1
                    font.weight: Font.Bold
                }
            }
        }

        // Sunrise Chip
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 26
            radius: Tokens.rounding.small
            color: Qt.alpha(Colours.palette.m3primary, 0.12)

            RowLayout {
                anchors.centerIn: parent
                spacing: 4

                MaterialIcon {
                    text: "wb_sunny"
                    color: Colours.palette.m3primary
                    iconPointSize: 11
                }

                StyledText {
                    text: Weather.sunrise || "5:45 AM"
                    color: Colours.palette.m3primary
                    textPointSize: Tokens.font.size.smaller - 1
                    font.weight: Font.Bold
                }
            }
        }

        // Sunset Chip
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 26
            radius: Tokens.rounding.small
            color: Qt.alpha(Colours.palette.m3secondary, 0.12)

            RowLayout {
                anchors.centerIn: parent
                spacing: 4

                MaterialIcon {
                    text: "nights_stay"
                    color: Colours.palette.m3secondary
                    iconPointSize: 11
                }

                StyledText {
                    text: Weather.sunset || "6:35 PM"
                    color: Colours.palette.m3secondary
                    textPointSize: Tokens.font.size.smaller - 1
                    font.weight: Font.Bold
                }
            }
        }
    }
}
