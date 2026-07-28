pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    readonly property real pad: 16
    readonly property real gapSection: 8
    readonly property real gapHero: 6

    // M3 Expressive surface stack — one shape step inside GlassCard (24 → 12)
    readonly property real insetPanelRadius: Tokens.rounding.small

    readonly property var upcomingForecast: {
        const all = Weather.forecast ?? []
        if (all.length <= 1)
            return []
        return all.slice(1, 7)
    }

    readonly property string cityLabel: {
        const raw = Weather.city || qsTr("Weather")
        return raw.replace(/\S+/g, function(word) {
            return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()
        })
    }

    readonly property string detailLine: {
        if (!Weather.hasData)
            return qsTr("Loading…")
        const parts = []
        if (Weather.description)
            parts.push(Weather.description)
        if (Weather.feelsLike)
            parts.push(qsTr("feels %1").arg(Weather.feelsLike))
        return parts.join(" · ")
    }

    Component.onCompleted: Weather.reload()

    WeatherBg {
        anchors.fill: parent
        z: 0
        bgOpacity: 0.2
    }

    ColumnLayout {
        z: 1
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: 0

        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: Tokens.rounding.small
            color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 1)
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.28)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 6
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 3
                    Layout.fillHeight: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                    radius: 1.5
                    color: Colours.palette.m3primary
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: root.cityLabel
                    color: Colours.palette.m3onSurface
                    textPointSize: Tokens.font.size.large
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    text: Weather.hasData ? Weather.icon : "cloud_sync"
                    font.family: Tokens.font.family.material
                    iconPointSize: Tokens.font.size.small
                    color: Colours.palette.m3secondary
                    fill: 1
                    animate: Weather.hasData
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: root.gapHero
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    text: Weather.hasData ? Weather.temp : "--°"
                    textPointSize: Tokens.font.size.extraLarge
                    font.weight: Font.Black
                    font.family: Tokens.font.family.mono
                    color: Colours.palette.m3primary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.detailLine
                    textPointSize: Tokens.font.size.smaller
                    font.weight: Font.Medium
                    color: Colours.palette.m3onSurfaceVariant
                    opacity: 0.8
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                spacing: 8

                HeroStat {
                    icon: "water_drop"
                    value: Weather.hasData ? `${Weather.humidity}%` : "--"
                    tint: Colours.palette.m3secondary
                }

                HeroStat {
                    icon: "air"
                    value: Weather.hasData ? Weather.windLabel : "--"
                    tint: Colours.palette.m3tertiary
                }

                HeroStat {
                    icon: "thermostat"
                    value: Weather.hasData ? Weather.todayHighLow : "--"
                    tint: Colours.palette.m3primary
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: root.gapSection
            color: Qt.alpha(Colours.palette.m3outlineVariant, 0.35)
        }

        WeekForecastStrip {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: root.gapSection
            forecast: root.upcomingForecast
        }
    }

    component HeroStat: RowLayout {
        id: stat

        required property string icon
        required property string value
        property color tint: Colours.palette.m3onSurfaceVariant

        spacing: 6

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            text: stat.icon
            font.family: Tokens.font.family.material
            iconPointSize: 14
            color: stat.tint
            fill: 1
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: stat.value
            textPointSize: Tokens.font.size.small
            font.weight: Font.Medium
            font.family: Tokens.font.family.mono
            color: Colours.palette.m3onSurface
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    component WeekForecastStrip: StyledRect {
        id: strip

        required property var forecast

        readonly property var displayRange: {
            const days = strip.forecast ?? []
            if (days.length === 0)
                return { min: 0, max: 1, span: 1 }

            const useF = GlobalConfig.services.useFahrenheit
            let min = Number.POSITIVE_INFINITY
            let max = Number.NEGATIVE_INFINITY

            for (let i = 0; i < days.length; i++) {
                const day = days[i]
                const lo = useF ? day.minTempF : day.minTempC
                const hi = useF ? day.maxTempF : day.maxTempC
                min = Math.min(min, lo)
                max = Math.max(max, hi)
            }

            return {
                min: min,
                max: max,
                span: Math.max(1, max - min)
            }
        }

        radius: root.insetPanelRadius
        color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 1)
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.28)

        function dayLabel(day: var): string {
            if (!day)
                return "--"
            const short = new Date(day.date).toLocaleDateString(Qt.locale(), "ddd")
            return short.slice(0, 3).toUpperCase()
        }

        function dayHigh(day: var): string {
            if (!day)
                return "--"
            if (GlobalConfig.services.useFahrenheit)
                return `${day.maxTempF}°`
            return `${day.maxTempC}°`
        }

        function dayLow(day: var): string {
            if (!day)
                return "--"
            if (GlobalConfig.services.useFahrenheit)
                return `${day.minTempF}°`
            return `${day.minTempC}°`
        }

        function daySwing(day: var): real {
            const range = strip.displayRange
            if (!day || !range || range.span <= 0)
                return 0.35

            const useF = GlobalConfig.services.useFahrenheit
            const hi = useF ? day.maxTempF : day.maxTempC
            const lo = useF ? day.minTempF : day.minTempC
            return Math.max(0.22, Math.min(1, (hi - lo) / range.span))
        }

        readonly property real cellPad: 4
        readonly property real cellGap: 4
        readonly property real tempGap: 6
        readonly property real rowInset: 8

        RowLayout {
            anchors.fill: parent
            anchors.margins: strip.rowInset
            spacing: 0

            Repeater {
                model: strip.forecast ?? []

                delegate: RowLayout {
                    id: dayRow

                    required property int index
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    readonly property real swing: strip.daySwing(dayRow.modelData)

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: strip.cellPad
                            spacing: strip.cellGap

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                horizontalAlignment: Text.AlignHCenter
                                text: strip.dayLabel(dayRow.modelData)
                                textPointSize: Tokens.font.size.small
                                font.weight: Font.Medium
                                font.letterSpacing: 0.6
                                color: Colours.palette.m3onSurfaceVariant
                                opacity: 0.65
                                elide: Text.ElideNone
                            }

                            MaterialIcon {
                                Layout.alignment: Qt.AlignHCenter
                                text: dayRow.modelData?.icon ?? "cloud"
                                font.family: Tokens.font.family.material
                                iconPointSize: 20
                                color: Colours.palette.m3onSurfaceVariant
                                fill: 1
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                horizontalAlignment: Text.AlignHCenter
                                text: strip.dayHigh(dayRow.modelData)
                                textPointSize: Tokens.font.size.small
                                font.family: Tokens.font.family.mono
                                font.bold: true
                                font.weight: Font.Bold
                                color: Colours.palette.m3onSurface
                                elide: Text.ElideNone
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: strip.tempGap
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                horizontalAlignment: Text.AlignHCenter
                                text: strip.dayLow(dayRow.modelData)
                                textPointSize: Tokens.font.size.small
                                font.family: Tokens.font.family.mono
                                font.bold: false
                                font.weight: Font.Normal
                                color: Colours.palette.m3onSurfaceVariant
                                elide: Text.ElideNone
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 2
                                Layout.topMargin: strip.cellGap

                                StyledRect {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: Math.max(8, parent.width * dayRow.swing)
                                    height: 2
                                    radius: 1
                                    color: Qt.alpha(Colours.palette.m3outlineVariant, 0.24)
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        Layout.topMargin: strip.rowInset
                        Layout.bottomMargin: strip.rowInset
                        visible: dayRow.index < (strip.forecast?.length ?? 0) - 1
                        color: Colours.palette.m3outlineVariant
                        opacity: 0.35
                    }
                }
            }
        }
    }
}