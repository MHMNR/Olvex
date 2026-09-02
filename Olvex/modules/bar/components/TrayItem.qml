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
    width: implicitWidth
    height: implicitHeight

    readonly property bool isMenuOpen: bar && bar.popouts && bar.popouts.hasCurrent && bar.popouts.currentName === `traymenu${itemIndex}`
    readonly property bool needsAttention: (modelData.status === "NeedsAttention") || (!!modelData.attentionIcon && modelData.attentionIcon !== "")
    readonly property bool recolour: Config.bar ? Config.bar.tray.recolour : (GlobalConfig.bar.tray.recolour ?? true)

    property real itemScale: 1.0
    scale: itemScale

    Behavior on scale {
        Anim {
            type: Anim.FastSpatial
        }
    }

    function toggleMenu() {
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
        NumberAnimation { target: root; property: "itemScale"; to: 0.92; duration: 70; easing.type: Easing.OutCubic }
        SpringAnimation { target: root; property: "itemScale"; to: 1.0; spring: 5.0; damping: 0.65 }
    }

    // Active pill background when its flyout menu is open
    Rectangle {
        anchors.fill: parent
        radius: Tokens.rounding.full
        color: Colours.palette.m3secondaryContainer
        opacity: root.isMenuOpen ? 0.85 : 0.0
        Behavior on opacity { Anim { type: Anim.FastEffects } }
    }

    StateLayer {
        id: stateLayer
        anchors.fill: parent
        radius: Tokens.rounding.full
        color: Colours.palette.m3onSurfaceVariant
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            pressSpring.start();
            if (mouse.button === Qt.LeftButton || mouse.button === Qt.RightButton) {
                root.toggleMenu();
            } else if (mouse.button === Qt.MiddleButton) {
                TrayService.secondaryActivate(root.modelData);
            }
        }
    }

    IconImage {
        id: icon
        anchors.centerIn: parent
        width: 20
        height: 20
        smooth: true
        asynchronous: true
        source: Icons.getTrayIcon(root.modelData.id, root.modelData.icon || root.modelData.attentionIcon)

        layer.enabled: root.recolour
        layer.smooth: true
        layer.effect: MultiEffect {
            colorization: 1.0
            colorizationColor: root.isMenuOpen ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3secondary
        }
    }

    // Attention badge dot
    Rectangle {
        id: attentionDot
        visible: root.needsAttention
        width: 6
        height: 6
        radius: 3
        color: Colours.palette.m3primary
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 3
        anchors.rightMargin: 3
        z: 3

        SequentialAnimation on opacity {
            running: root.needsAttention
            loops: Animation.Infinite
            NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
        }
    }

    Controls.Tooltip {
        target: stateLayer
        text: root.modelData.tooltip ? (root.modelData.tooltip.text || root.modelData.title || root.modelData.id) : (root.modelData.title || root.modelData.id)
    }
}

