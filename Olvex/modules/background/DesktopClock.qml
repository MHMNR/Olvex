
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    required property Item wallpaper
    required property real absX
    required property real absY

    property real clockScale: Config.background && Config.background.desktopClock ? Config.background.desktopClock.scale : 1.0
    readonly property bool bgEnabled: Boolean(Config.background && Config.background.desktopClock && Config.background.desktopClock.background && Config.background.desktopClock.background.enabled)
    readonly property bool blurEnabled: bgEnabled && Boolean(Config.background && Config.background.desktopClock && Config.background.desktopClock.background && Config.background.desktopClock.background.blur) && !GameMode.enabled
    readonly property bool invertColors: Boolean(Config.background && Config.background.desktopClock && Config.background.desktopClock.invertColors)
    readonly property bool useLightSet: Colours.light ? !invertColors : invertColors
    readonly property color safePrimary: useLightSet ? Colours.palette.m3primaryContainer : Colours.palette.m3primary
    readonly property color safeSecondary: useLightSet ? Colours.palette.m3secondaryContainer : Colours.palette.m3secondary
    readonly property color safeTertiary: useLightSet ? Colours.palette.m3tertiaryContainer : Colours.palette.m3tertiary
    readonly property color safeOnSurface: Colours.palette.m3onSurface

    implicitWidth: layout.implicitWidth + (Tokens.padding.large * 4 * root.clockScale)
    implicitHeight: layout.implicitHeight + (Tokens.padding.large * 2.5 * root.clockScale)

    Item {
        id: clockContainer
        anchors.fill: parent

        layer.enabled: Boolean(Config.background && Config.background.desktopClock && Config.background.desktopClock.shadow && Config.background.desktopClock.shadow.enabled)
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Colours.palette.m3shadow
            shadowOpacity: Config.background && Config.background.desktopClock && Config.background.desktopClock.shadow ? Config.background.desktopClock.shadow.opacity : 0.7
            shadowBlur: Config.background && Config.background.desktopClock && Config.background.desktopClock.shadow ? Config.background.desktopClock.shadow.blur : 0.4
        }

        Loader {
            asynchronous: true
            anchors.fill: parent
            active: root.blurEnabled

            sourceComponent: MultiEffect {
                source: ShaderEffectSource {
                    sourceItem: root.wallpaper
                    sourceRect: Qt.rect(root.absX, root.absY, root.width, root.height)
                    live: false
                    recursive: false
                }
                maskSource: backgroundPlate
                maskEnabled: true
                blurEnabled: true
                blur: 1
                blurMax: 64
                autoPaddingEnabled: false
            }
        }

        StyledRect {
            id: backgroundPlate

            visible: root.bgEnabled
            anchors.fill: parent
            radius: Tokens.rounding.large * root.clockScale
            opacity: Config.background && Config.background.desktopClock && Config.background.desktopClock.background ? Config.background.desktopClock.background.opacity : 0.7
            color: Colours.palette.m3surfaceContainerLow
            border.color: Colours.palette.m3outlineVariant
            border.width: 1

            layer.enabled: root.blurEnabled
        }

        ColumnLayout {
            id: layout

            anchors.centerIn: parent
            spacing: 8 * root.clockScale

            // ── Top Date & Day Capsule Badge ──
            StyledRect {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: dateRow.implicitWidth + (20 * root.clockScale)
                implicitHeight: dateRow.implicitHeight + (8 * root.clockScale)
                radius: Tokens.rounding.full
                color: Qt.alpha(root.safePrimary, 0.12)

                RowLayout {
                    id: dateRow
                    anchors.centerIn: parent
                    spacing: 8 * root.clockScale

                    StyledText {
                        text: Time.format("dddd").toUpperCase()
                        textPointSize: Tokens.font.size.normal * 0.9 * root.clockScale
                        font.letterSpacing: 3
                        font.weight: Font.Bold
                        color: root.safePrimary
                    }

                    StyledRect {
                        width: 4 * root.clockScale
                        height: 4 * root.clockScale
                        radius: Tokens.rounding.full
                        color: root.safeTertiary
                        Layout.alignment: Qt.AlignVCenter
                    }

                    StyledText {
                        text: Time.format("MMMM d").toUpperCase()
                        textPointSize: Tokens.font.size.normal * 0.9 * root.clockScale
                        font.letterSpacing: 2
                        font.weight: Font.Medium
                        color: root.safeSecondary
                    }
                }
            }

            // ── Main Time Display ──
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 4 * root.clockScale

                StyledText {
                    text: Time.hourStr
                    textPointSize: Tokens.font.size.extraLarge * 3.6 * root.clockScale
                    font.weight: Font.Black
                    color: root.safePrimary
                }

                StyledText {
                    text: ":"
                    textPointSize: Tokens.font.size.extraLarge * 3.6 * root.clockScale
                    font.weight: Font.Bold
                    color: root.safeTertiary
                    opacity: 0.85
                    Layout.topMargin: -Tokens.padding.large * 1.8 * root.clockScale
                }

                StyledText {
                    text: Time.minuteStr
                    textPointSize: Tokens.font.size.extraLarge * 3.6 * root.clockScale
                    font.weight: Font.Black
                    color: root.safeSecondary
                }

                Loader {
                    asynchronous: true
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: Tokens.padding.large * 1.6 * root.clockScale
                    Layout.leftMargin: 4 * root.clockScale

                    active: GlobalConfig.services.useTwelveHourClock
                    visible: active

                    sourceComponent: StyledRect {
                        implicitWidth: amPmText.implicitWidth + (12 * root.clockScale)
                        implicitHeight: amPmText.implicitHeight + (4 * root.clockScale)
                        radius: Tokens.rounding.small
                        color: Qt.alpha(root.safeSecondary, 0.15)

                        StyledText {
                            id: amPmText
                            anchors.centerIn: parent
                            text: Time.amPmStr
                            textPointSize: Tokens.font.size.normal * 0.85 * root.clockScale
                            font.weight: Font.Bold
                            font.letterSpacing: 1
                            color: root.safeSecondary
                        }
                    }
                }
            }
        }
    }

    Behavior on clockScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on implicitWidth {
        Anim {
            type: Anim.StandardSmall
        }
    }
}
