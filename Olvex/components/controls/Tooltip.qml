import QtQuick
import QtQuick.Controls
import Olvex.Config
import qs.components
import qs.components.effects
import qs.services

Popup {
    id: root

    required property Item target
    required property string text
    property int delay: 500
    property int timeout: 0

    property bool tooltipVisible: false
    property Timer showTimer: Timer {
        interval: root.delay
        onTriggered: root.tooltipVisible = true
    }
    property Timer hideTimer: Timer {
        interval: root.timeout
        onTriggered: root.tooltipVisible = false
    }

    function updatePosition() {
        if (!target || !parent)
            return;

        // Wait for tooltipRect to have its size calculated
        Qt.callLater(() => {
            if (!target || !parent || !tooltipRect)
                return;

            // Get target position in parent's coordinate system
            const targetPos = target.mapToItem(parent, 0, 0);
            const targetCenterX = targetPos.x + target.width / 2;

            // Get tooltip size (use width/height if available, otherwise implicit)
            const tooltipWidth = tooltipRect.width > 0 ? tooltipRect.width : tooltipRect.implicitWidth;
            const tooltipHeight = tooltipRect.height > 0 ? tooltipRect.height : tooltipRect.implicitHeight;

            // Center tooltip horizontally on target
            let newX = targetCenterX - tooltipWidth / 2;

            // Position tooltip above target
            let newY = targetPos.y - tooltipHeight - GlobalConfig.appearance.spacing.small;

            // Keep within bounds
            const padding = GlobalConfig.appearance.padding.normal;
            if (newX < padding) {
                newX = padding;
            } else if (newX + tooltipWidth > (parent.width - padding)) {
                newX = parent.width - tooltipWidth - padding;
            }

            // Update popup position
            x = newX;
            y = newY;
        });
    }

    readonly property Item overlayParent: {
        let win = root.target ? root.target.Window.window : root.Window.window;
        if (win) {
            if (win.interactionWrapper)
                return win.interactionWrapper;
            if (win.contentItem)
                return win.contentItem;
            return win;
        }
        let p = root.target || root;
        while (p && p.parent)
            p = p.parent;
        return p;
    }

    // Popup properties - doesn't affect layout
    parent: overlayParent

    visible: tooltipVisible
    modal: false
    closePolicy: Popup.NoAutoClose
    padding: 0
    margins: 0
    background: Item {}

    // Update position when target moves or tooltip becomes visible
    onTooltipVisibleChanged: {
        if (tooltipVisible) {
            Qt.callLater(updatePosition);
        }
    }
    Component.onCompleted: {
        if (tooltipVisible) {
            updatePosition();
        }
    }

    enter: Transition {
        Anim {
            property: "opacity"
            from: 0
            to: 1
            type: Anim.FastSpatial
        }
    }

    exit: Transition {
        Anim {
            property: "opacity"
            from: 1
            to: 0
            type: Anim.FastSpatial
        }
    }

    contentItem: StyledRect {
        id: tooltipRect

        implicitWidth: tooltipText.implicitWidth + GlobalConfig.appearance.padding.normal * 2
        implicitHeight: tooltipText.implicitHeight + GlobalConfig.appearance.padding.smaller * 2

        color: Colours.palette.m3surfaceContainerHighest
        radius: GlobalConfig.appearance.rounding.small
        antialiasing: true
        border.width: 0

        // Add elevation for depth
        Elevation {
            anchors.fill: parent
            radius: parent.radius
            z: -1
            level: 3
        }

        StyledText {
            id: tooltipText

            anchors.centerIn: parent

            text: root.text
            color: Colours.palette.m3onSurface
            textPointSize: GlobalConfig.appearance.font.size.small
        }
    }

    Connections {
        function onXChanged() {
            if (root.tooltipVisible)
                root.updatePosition();
        }
        function onYChanged() {
            if (root.tooltipVisible)
                root.updatePosition();
        }
        function onWidthChanged() {
            if (root.tooltipVisible)
                root.updatePosition();
        }
        function onHeightChanged() {
            if (root.tooltipVisible)
                root.updatePosition();
        }

        target: root.target
    }

    // Monitor hover state
    Connections {
        function onHoveredChanged() {
            if (target.hovered) {
                showTimer.start();
                if (timeout > 0) {
                    hideTimer.stop();
                    hideTimer.start();
                }
            } else {
                showTimer.stop();
                hideTimer.stop();
                tooltipVisible = false;
            }
        }

        target: root.target
    }
}
