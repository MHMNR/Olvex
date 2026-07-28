import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Olvex.Config
import qs.services
import qs.utils
import qs.components.controls as Controls

MouseArea {
    id: root

    required property SystemTrayItem modelData

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    implicitWidth: Tokens.font.size.small * 2
    implicitHeight: Tokens.font.size.small * 2

    onClicked: event => {
        if (event.button === Qt.LeftButton)
            modelData.activate();
        else
            modelData.secondaryActivate();
    }

    IconImage {
        id: icon

        anchors.fill: parent
        asynchronous: true
        source: Icons.getTrayIcon(root.modelData.id, root.modelData.icon || root.modelData.attentionIcon)

        layer.enabled: Config.bar.tray.recolour
        layer.effect: MultiEffect {
            colorization: 1.0
            colorizationColor: Colours.palette.m3secondary
        }
    }

    Controls.Tooltip {
        target: root
        // Prioritize tooltip text, fallback to title, then ID
        text: root.modelData.tooltip ? (root.modelData.tooltip.text || root.modelData.title || root.modelData.id) : (root.modelData.title || root.modelData.id)
    }
}
