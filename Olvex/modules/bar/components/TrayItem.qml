import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Olvex.Config
import qs.components
import qs.services
import qs.utils
import qs.components.controls as Controls

Item {
    id: root

    required property SystemTrayItem modelData
    property int itemIndex: 0
    property var bar: null

    implicitWidth: 32
    implicitHeight: 32

    property real itemScale: 1.0
    scale: itemScale

    Behavior on scale {
        Anim {
            type: Anim.FastSpatial
        }
    }

    function toggleMenu(): void {
        if (bar && bar.popouts) {
            const menuName = `traymenu${itemIndex}`;
            if (bar.popouts.hasCurrent && bar.popouts.currentName === menuName) {
                bar.popouts.hasCurrent = false;
            } else {
                bar.popouts.currentName = menuName;
                bar.popouts.currentCenter = Qt.binding(() => root.mapToItem(bar, 0, root.height / 2).y);
                bar.popouts.hasCurrent = true;
            }
        }
    }

    SequentialAnimation {
        id: pressSpring
        NumberAnimation { target: root; property: "itemScale"; to: 0.88; duration: 80; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "itemScale"; to: 1.0; duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
    }

    StateLayer {
        id: stateLayer
        anchors.fill: parent
        radius: Tokens.rounding.full
        color: Colours.palette.m3onSurfaceVariant
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            pressSpring.start();
            if (mouse.button === Qt.LeftButton) {
                TrayService.activate(root.modelData);
                root.toggleMenu();
            } else if (mouse.button === Qt.RightButton) {
                TrayService.secondaryActivate(root.modelData);
                root.toggleMenu();
            }
        }
    }

    IconImage {
        id: icon
        anchors.centerIn: parent
        width: 22
        height: 22
        asynchronous: true
        source: Icons.getTrayIcon(root.modelData.id, root.modelData.icon || root.modelData.attentionIcon)

        layer.enabled: Config.bar.tray.recolour
        layer.effect: MultiEffect {
            colorization: 1.0
            colorizationColor: Colours.palette.m3secondary
        }
    }

    Controls.Tooltip {
        target: stateLayer
        text: root.modelData.tooltip ? (root.modelData.tooltip.text || root.modelData.title || root.modelData.id) : (root.modelData.title || root.modelData.id)
    }
}
