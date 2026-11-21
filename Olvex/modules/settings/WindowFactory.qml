pragma Singleton

import "../../components"
import "../../components/controls"
import "../../components/containers"
import QtQuick
import Quickshell
import qs.components
import qs.services
import qs.utils
import "../setup"

Singleton {
    id: root

    function create(parent, props) {
        if (SetupFactory.active) return;
        settingsWindow.createObject(parent || dummy, props || {});
    }

    QtObject {
        id: dummy
    }

    Component {
        id: settingsWindow

        FloatingWindow {
            id: win

            property alias active: cc.active
            property alias navExpanded: cc.navExpanded
            property alias currentId: cc.currentId
            property alias activeSection: cc.activeSection

            // Transparent window background for glass transparency + Hyprland blur
            color: "transparent"

            onVisibleChanged: {
                if (!visible)
                    destroy();
            }

            // Track content size scaled cleanly to display resolution
            readonly property var _resolvedScreen: win.screen || (Screens.screens.find(s => s.focused) ?? Screens.screens[0] ?? null)
            readonly property real uiScale: UiScale.forScreen(_resolvedScreen)
            readonly property Item scaledContentRoot: cc

            implicitWidth: Math.round(cc.implicitWidth * win.uiScale)
            implicitHeight: Math.round(cc.implicitHeight * win.uiScale)

            minimumSize.width: Math.round(940 * win.uiScale)
            minimumSize.height: Math.round(676 * win.uiScale)

            title: {
                const id = cc.currentId || cc.active || "";
                if (!id)
                    return qsTr("Olvex Settings");
                const name = id.charAt(0).toUpperCase() + id.slice(1);
                return qsTr("Olvex Settings - %1").arg(name);
            }

            SettingsWindow {
                id: cc

                x: 0
                y: 0
                transformOrigin: Item.TopLeft
                scale: win.uiScale
                width: UiScale.virtualWidth(win.width, win.uiScale)
                height: UiScale.virtualHeight(win.height, win.uiScale)
                screen: win._resolvedScreen
                onClose: win.destroy()
                floating: true
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
