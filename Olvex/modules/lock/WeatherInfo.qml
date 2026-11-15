import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services
import "../dashboard/dash"

Item {
    id: root

    required property int rootHeight

    anchors.fill: parent

    readonly property string cityLabel: {
        const raw = Weather.city || qsTr("Weather");
        return raw.replace(/\S+/g, function (word) {
            return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
        });
    }

    readonly property string detailLine: {
        if (!Weather.hasData)
            return qsTr("Loading…");
        const parts = [];
        if (Weather.description)
            parts.push(Weather.description);
        if (Weather.feelsLike)
            parts.push(qsTr("feels %1").arg(Weather.feelsLike));
        return parts.join(" · ");
    }

    Component.onCompleted: Weather.reload()

    // Live animated sky/weather shader background (clipped cleanly to card rounding)
    StyledClippingRect {
        anchors.fill: parent
        z: 0
        radius: Tokens.rounding.large
        color: "transparent"
        clip: true

        WeatherBg {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.round(parent.height * 1.75)
            bgOpacity: Colours.light ? 0.55 : 0.82
            active: LockState.locked
        }
    }

    ColumnLayout {
        z: 1
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        // ── Signature M3 Header Pill (matches Dashboard SmallWeather) ────────
        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            radius: Tokens.rounding.small
            color: Colours.tileFill

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 3
                    Layout.fillHeight: true
                    Layout.topMargin: 6
                    Layout.bottomMargin: 6
                    radius: 1.5
                    color: Colours.palette.m3primary
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: root.cityLabel
                    color: Colours.palette.m3onSurface
                    textPointSize: Tokens.font.size.normal
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4

                    MaterialIcon {
                        text: Weather.icon
                        color: Colours.palette.m3primary
                        iconPointSize: 13
                    }

                    StyledText {
                        text: Weather.todayHighLow
                        color: Colours.palette.m3onSurfaceVariant
                        font.family: Tokens.font.family.mono
                        textPointSize: Tokens.font.size.smaller - 2
                        font.weight: Font.Bold
                    }
                }
            }
        }

        // ── Open-Sky Hero Area (left temp/detail, right sky left completely open) ──
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 2
            spacing: 2

            Item { Layout.fillHeight: true }

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
                textPointSize: Tokens.font.size.smaller - 1
                font.weight: Font.Medium
                color: Colours.palette.m3onSurface
                opacity: 0.92
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Item { Layout.fillHeight: true }
        }

        // ── Compact Bottom Stats Row (keeps upper/right sky clear for Moon/Sun) ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            HeroStat {
                icon: "water_drop"
                value: `${Weather.humidity}%`
            }

            HeroStat {
                icon: "air"
                value: Weather.windLabel
            }

            HeroStat {
                icon: Weather.isDay ? "wb_twilight" : "wb_sunny"
                value: Weather.isDay ? Weather.sunset : Weather.sunrise
            }
        }
    }

    component HeroStat: StyledRect {
        id: stat

        required property string icon
        required property string value

        Layout.fillWidth: true
        implicitHeight: 22
        radius: Tokens.rounding.small
        color: Colours.tileFill

        RowLayout {
            anchors.centerIn: parent
            spacing: 4

            MaterialIcon {
                text: stat.icon
                iconPointSize: 12
                color: Colours.palette.m3primary
            }

            StyledText {
                text: stat.value
                textPointSize: Tokens.font.size.smaller - 2
                font.family: Tokens.font.family.mono
                font.weight: Font.DemiBold
                color: Colours.palette.m3onSurface
            }
        }
    }
}
