import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.widgets
import qs.services

Item {
    id: root

    required property string screenName
    required property Item wallpaper
    required property real absX
    required property real absY

    opacity: (LockState.locked && LockState.lockClockVisible) ? 0 : 1

    function reportRect() {
        if (LockState.locked || !screenName)
            return;
        LockState.setDesktopClockRect(screenName, {
            x: root.absX + layout.x,
            y: root.absY + layout.y,
            width: layout.width,
            height: layout.height,
            scale: root.clockScale,
            visible: root.visible && layout.width > 0 && layout.height > 0
        });
    }

    onAbsXChanged: reportRect()
    onAbsYChanged: reportRect()
    onClockScaleChanged: reportRect()
    onVisibleChanged: reportRect()
    Component.onCompleted: Qt.callLater(reportRect)

    property real clockScale: Config.background && Config.background.desktopClock ? Config.background.desktopClock.scale : 1.0
    readonly property bool bgEnabled: Boolean(Config.background && Config.background.desktopClock && Config.background.desktopClock.background && Config.background.desktopClock.background.enabled)
    readonly property bool blurEnabled: bgEnabled && Boolean(Config.background && Config.background.desktopClock && Config.background.desktopClock.background && Config.background.desktopClock.background.blur) && !GameMode.enabled
    readonly property bool shadowEnabled: Boolean(Config.background && Config.background.desktopClock && Config.background.desktopClock.shadow && Config.background.desktopClock.shadow.enabled)

    implicitWidth: Math.round(layout.implicitWidth + (Tokens.padding.large * 2.2 * root.clockScale))
    implicitHeight: Math.round(layout.implicitHeight + (Tokens.padding.large * 1.4 * root.clockScale))

    Item {
        id: clockContainer
        anchors.fill: parent

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
                    hideSource: false
                }
                maskSource: backgroundPlate
                maskEnabled: true
                blurEnabled: true
                blur: 0.8
                blurMax: 32
                autoPaddingEnabled: false
            }
        }

        StyledRect {
            id: backgroundPlate

            visible: root.bgEnabled
            anchors.fill: parent
            radius: Math.round(Tokens.rounding.large * root.clockScale)
            opacity: Config.background && Config.background.desktopClock && Config.background.desktopClock.background ? Config.background.desktopClock.background.opacity : 0.7
            color: Colours.palette.m3surfaceContainerLow
            border.color: "transparent"
            border.width: 0

            layer.enabled: root.blurEnabled || (root.bgEnabled && root.shadowEnabled)
            layer.effect: MultiEffect {
                shadowEnabled: root.bgEnabled && root.shadowEnabled
                shadowColor: Colours.palette.m3shadow
                shadowOpacity: Config.background && Config.background.desktopClock && Config.background.desktopClock.shadow ? Config.background.desktopClock.shadow.opacity : 0.7
                shadowBlur: Config.background && Config.background.desktopClock && Config.background.desktopClock.shadow ? Config.background.desktopClock.shadow.blur : 0.4
            }
        }

        SharedClock {
            id: layout

            anchors.centerIn: parent
            clockScale: root.clockScale
            dateDetailFormat: "d MMMM yyyy"
            shadowEnabled: !root.bgEnabled || root.shadowEnabled
            shadowOpacity: 0.35
            shadowBlur: 0.6

            function reportColors() {
                if (!root.screenName)
                    return;
                LockState.setDesktopClockColors(root.screenName, {
                    primaryColor: layout.primaryColor,
                    secondaryColor: layout.secondaryColor,
                    tertiaryColor: layout.tertiaryColor,
                    onSurfaceColor: layout.onSurfaceColor
                });
            }

            onPrimaryColorChanged: reportColors()
            onSecondaryColorChanged: reportColors()
            onTertiaryColorChanged: reportColors()
            onOnSurfaceColorChanged: reportColors()
            onXChanged: root.reportRect()
            onYChanged: root.reportRect()
            onWidthChanged: root.reportRect()
            onHeightChanged: root.reportRect()
            Component.onCompleted: Qt.callLater(reportColors)
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
