pragma Singleton

import "../../components"
import "../../components/controls"
import "../../components/containers"
import QtQuick
import Quickshell
import qs.components
import qs.services

Singleton {
    id: root

    function create(parent: Item, props: var): void {
        settingsWindow.createObject(parent ?? dummy, props);
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

            // Solid opaque surface matching theme mode; Hyprland natively clips window corners.
            color: Colours.palette.m3surface

            onVisibleChanged: {
                if (!visible)
                    destroy();
            }

            // Track content size; allow slight resize for bento density
            implicitWidth: cc.implicitWidth
            implicitHeight: cc.implicitHeight

            minimumSize.width: 900
            minimumSize.height: 620
            maximumSize.width: Math.max(cc.implicitWidth * 1.25, 1600)
            maximumSize.height: Math.max(cc.implicitHeight * 1.15, 1200)

            title: {
                const id = cc.currentId || cc.active || "";
                if (!id)
                    return qsTr("Olvex Settings");
                const name = id.charAt(0).toUpperCase() + id.slice(1);
                return qsTr("Olvex Settings - %1").arg(name);
            }

            SettingsWindow {
                id: cc

                anchors.fill: parent
                screen: win.screen
                onClose: win.destroy()
                floating: true
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
