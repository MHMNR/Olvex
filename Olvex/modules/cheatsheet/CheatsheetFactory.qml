pragma Singleton

import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    property var currentInstance: null

    function toggle() {
        if (currentInstance) {
            close();
        } else {
            open();
        }
    }

    function open() {
        if (currentInstance) return;
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

            implicitWidth: 840
            implicitHeight: 640
            minimumSize.width: 720
            minimumSize.height: 480

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
                anchors.fill: parent
                onCloseRequested: {
                    if (root.currentInstance === win) root.currentInstance = null;
                    win.destroy();
                }
            }
        }
    }
}
