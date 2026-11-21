pragma Singleton

import QtQuick
import Quickshell
import qs.services
import qs.utils
import "../setup"

Singleton {
    id: root

    property var currentInstance: null

    function toggle() {
        if (SetupFactory.active) return;
        if (currentInstance) {
            close();
        } else {
            open();
        }
    }

    function open() {
        if (SetupFactory.active) return;
        if (currentInstance) {
            close();
        }
        currentInstance = windowComponent.createObject(dummy);
    }

    function close() {
        if (currentInstance) {
            currentInstance.destroy();
            currentInstance = null;
        }
    }

    QtObject {
        id: dummy
    }

    Component {
        id: windowComponent

        FloatingWindow {
            id: win

            color: "transparent"
            title: qsTr("Olvex Shortcuts")
            visible: true

            property bool isReady: false
            Component.onCompleted: {
                isReady = true;
            }

            readonly property var _resolvedScreen: win.screen || (Screens.screens.find(s => s.focused) ?? Screens.screens[0] ?? null)
            readonly property real uiScale: UiScale.forScreen(_resolvedScreen)
            readonly property Item scaledContentRoot: csWin

            implicitWidth: Math.round(880 * uiScale)
            implicitHeight: Math.round(660 * uiScale)
            minimumSize.width: Math.round(680 * uiScale)
            minimumSize.height: Math.round(500 * uiScale)

            onVisibleChanged: {
                if (isReady && !visible) {
                    if (root.currentInstance === win) root.currentInstance = null;
                    destroy();
                }
            }

            Component.onDestruction: {
                if (root.currentInstance === win) root.currentInstance = null;
            }

            CheatsheetWindow {
                id: csWin
                x: 0
                y: 0
                transformOrigin: Item.TopLeft
                scale: win.uiScale
                width: UiScale.virtualWidth(win.width, win.uiScale)
                height: UiScale.virtualHeight(win.height, win.uiScale)
                onCloseRequested: {
                    if (root.currentInstance === win) root.currentInstance = null;
                    win.destroy();
                }
            }
        }
    }
}
