import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    readonly property var _desktopClockCfg: (Config.background && Config.background.desktopClock)
        ? Config.background.desktopClock
        : (GlobalConfig.background && GlobalConfig.background.desktopClock ? GlobalConfig.background.desktopClock : null)

    // Extensible clock style identifier shared across Desktop, Card Lockscreen, and Minimal Lockscreen.
    // Future styles can be added as Components and dispatched in styleLoader.
    property string clockStyle: (_desktopClockCfg && _desktopClockCfg.style)
        ? _desktopClockCfg.style
        : "classic"

    property real clockScale: (_desktopClockCfg && _desktopClockCfg.scale !== undefined)
        ? _desktopClockCfg.scale
        : 1.0
    readonly property bool invertColors: Boolean(_desktopClockCfg && _desktopClockCfg.invertColors)
    readonly property bool adaptiveColor: (_desktopClockCfg && _desktopClockCfg.adaptiveTextColor !== undefined)
        ? Boolean(_desktopClockCfg.adaptiveTextColor)
        : true
    readonly property bool dominantIsDark: (_desktopClockCfg && _desktopClockCfg.dominantIsDark !== undefined)
        ? Boolean(_desktopClockCfg.dominantIsDark)
        : !Colours.light
    readonly property bool useLightSet: adaptiveColor ? !dominantIsDark : (Colours.light ? !invertColors : invertColors)

    property bool syncFromLockState: false
    property string lockScreenName: ""
    readonly property var _lockedColors: syncFromLockState ? LockState.getDesktopClockColors(lockScreenName) : null

    property color primaryColor: _lockedColors ? _lockedColors.primaryColor : (useLightSet ? Colours.palette.m3primaryContainer : Colours.palette.m3primary)
    property color secondaryColor: _lockedColors ? _lockedColors.secondaryColor : (useLightSet ? Colours.palette.m3secondaryContainer : Colours.palette.m3secondary)
    property color tertiaryColor: _lockedColors ? _lockedColors.tertiaryColor : (useLightSet ? Colours.palette.m3tertiaryContainer : Colours.palette.m3tertiary)
    property color onSurfaceColor: _lockedColors ? _lockedColors.onSurfaceColor : (useLightSet ? Colours.palette.m3surfaceContainerLowest : Colours.palette.m3onSurface)

    property bool showDatePill: true
    property string dateDetailFormat: "d MMMM yyyy"
    property bool shadowEnabled: true
    property real shadowOpacity: 0.35
    property real shadowBlur: 0.6

    implicitWidth: styleLoader.item ? styleLoader.item.implicitWidth : 0
    implicitHeight: styleLoader.item ? styleLoader.item.implicitHeight : 0

    Loader {
        id: styleLoader
        anchors.centerIn: parent
        sourceComponent: {
            switch (root.clockStyle) {
            case "classic":
            default:
                return classicClockComponent;
            }
        }
    }

    Component {
        id: classicClockComponent

        ColumnLayout {
            id: clockCol
            spacing: Math.round(6 * root.clockScale)

            layer.enabled: root.shadowEnabled
            layer.smooth: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Colours.palette.m3shadow
                shadowOpacity: root.shadowOpacity
                shadowBlur: root.shadowBlur
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 2
            }

            // ── Top Date & Day Capsule Badge ────────────────────────────────
            StyledRect {
                visible: root.showDatePill
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: Math.round(dateRow.implicitWidth + (16 * root.clockScale))
                implicitHeight: Math.round(dateRow.implicitHeight + (6 * root.clockScale))
                radius: Tokens.rounding.full
                color: Qt.alpha(root.primaryColor, 0.14)

                RowLayout {
                    id: dateRow
                    anchors.centerIn: parent
                    spacing: Math.round(6 * root.clockScale)

                    StyledText {
                        text: Time.format("dddd").toUpperCase()
                        textPointSize: Math.max(7, Math.round(Tokens.font.size.small * 0.9 * root.clockScale))
                        font.letterSpacing: 1.8 * root.clockScale
                        font.weight: Font.DemiBold
                        color: root.primaryColor
                    }

                    StyledRect {
                        width: Math.max(3, Math.round(3.5 * root.clockScale))
                        height: width
                        radius: Tokens.rounding.full
                        color: root.tertiaryColor
                        Layout.alignment: Qt.AlignVCenter
                    }

                    StyledText {
                        text: Time.format(root.dateDetailFormat).toUpperCase()
                        textPointSize: Math.max(7, Math.round(Tokens.font.size.small * 0.9 * root.clockScale))
                        font.letterSpacing: 1.4 * root.clockScale
                        font.weight: Font.Medium
                        color: root.secondaryColor
                    }
                }
            }

            // ── Main Time Display ───────────────────────────────────────────
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Math.round(3 * root.clockScale)

                StyledText {
                    text: Time.hourStr
                    color: root.onSurfaceColor
                    textPointSize: Math.max(20, Math.floor(Tokens.font.size.extraLarge * 2.35 * root.clockScale))
                    font.family: Tokens.font.family.clock
                    font.weight: Font.Bold
                }

                StyledText {
                    text: ":"
                    color: root.primaryColor
                    textPointSize: Math.max(20, Math.floor(Tokens.font.size.extraLarge * 2.35 * root.clockScale))
                    font.family: Tokens.font.family.clock
                    font.weight: Font.DemiBold
                    opacity: 0.85
                    Layout.topMargin: -Math.round(Tokens.padding.small * 1.4 * root.clockScale)
                }

                StyledText {
                    text: Time.minuteStr
                    color: root.primaryColor
                    textPointSize: Math.max(20, Math.floor(Tokens.font.size.extraLarge * 2.35 * root.clockScale))
                    font.family: Tokens.font.family.clock
                    font.weight: Font.Bold
                }

                Loader {
                    asynchronous: true
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: Math.round(Tokens.padding.normal * 0.85 * root.clockScale)
                    Layout.leftMargin: Math.round(3 * root.clockScale)

                    active: GlobalConfig.services.useTwelveHourClock
                    visible: active

                    sourceComponent: StyledRect {
                        implicitWidth: Math.round(amPmText.implicitWidth + (9 * root.clockScale))
                        implicitHeight: Math.round(amPmText.implicitHeight + (4 * root.clockScale))
                        radius: Math.max(4, Math.round(Tokens.rounding.extraSmall * 1.5 * root.clockScale))
                        color: Qt.alpha(root.primaryColor, 0.16)

                        StyledText {
                            id: amPmText
                            anchors.centerIn: parent
                            text: Time.amPmStr
                            color: root.primaryColor
                            textPointSize: Math.max(7, Math.round(Tokens.font.size.small * 0.82 * root.clockScale))
                            font.family: Tokens.font.family.clock
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.8 * root.clockScale
                        }
                    }
                }
            }
        }
    }
}

