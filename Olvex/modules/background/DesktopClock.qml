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

    property real uiScale: 1.0
    property real clockScale: (Config.background && Config.background.desktopClock ? Config.background.desktopClock.scale : 1.0) * root.uiScale
    readonly property bool bgEnabled: false
    readonly property bool blurEnabled: Boolean(Config.background && Config.background.desktopClock && Config.background.desktopClock.background && Config.background.desktopClock.background.blur) && !GameMode.enabled
    readonly property bool shadowEnabled: Boolean(Config.background && Config.background.desktopClock && Config.background.desktopClock.shadow && Config.background.desktopClock.shadow.enabled)

    implicitWidth: Math.round(layout.implicitWidth)
    implicitHeight: Math.round(layout.implicitHeight)

    Item {
        id: clockContainer
        anchors.fill: parent

        SharedClock {
            id: layout

            anchors.centerIn: parent
            clockScale: root.clockScale
            wallpaper: root.wallpaper
            absX: root.absX + x
            absY: root.absY + y
            blurEnabled: root.blurEnabled
            dateDetailFormat: "d MMMM yyyy"
            shadowEnabled: root.shadowEnabled
            shadowOpacity: 0.35
            shadowBlur: 0.6

            function reportColors() {
                if (!root.screenName)
                    return;
                LockState.setDesktopClockColors(root.screenName, {
                    primaryColor: layout.primaryColor,
                    secondaryColor: layout.secondaryColor,
                    tertiaryColor: layout.tertiaryColor,
                    onSurfaceColor: layout.onSurfaceColor,
                    surfaceColor: layout.surfaceColor,
                    surfaceHighColor: layout.surfaceHighColor
                });
            }

            onPrimaryColorChanged: reportColors()
            onSecondaryColorChanged: reportColors()
            onTertiaryColorChanged: reportColors()
            onOnSurfaceColorChanged: reportColors()
            onSurfaceColorChanged: reportColors()
            onSurfaceHighColorChanged: reportColors()
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
