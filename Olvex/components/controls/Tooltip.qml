import QtQuick
import QtQuick.Controls
import Olvex.Config
import qs.components
import qs.components.effects
import qs.services

Popup {
    id: root

    enum Side {
        Top,
        Bottom,
        Left,
        Right
    }

    required property Item target
    required property string text
    property int delay: 500
    property int timeout: 0
    property int side: Tooltip.Top

    property bool tooltipVisible: false
    property bool slidingActive: false
    property Timer showTimer: Timer {
        interval: root.delay
        onTriggered: root.tooltipVisible = true
    }
    property Timer hideTimer: Timer {
        interval: root.timeout
        onTriggered: root.tooltipVisible = false
    }

    readonly property real targetWidth: tooltipText.implicitWidth + GlobalConfig.appearance.padding.normal * 2
    readonly property real targetHeight: tooltipText.implicitHeight + GlobalConfig.appearance.padding.smaller * 2

    width: targetWidth
    height: targetHeight

    function updatePosition(immediate) {
        if (!target || !parent || !tooltipRect)
            return;

        // Get target position in parent's coordinate system
        const targetPos = target.mapToItem(parent, 0, 0);
        const targetCenterX = targetPos.x + target.width / 2;
        const targetCenterY = targetPos.y + target.height / 2;

        // Use target size so destination position is centered for the morphed geometry
        const tooltipWidth = root.targetWidth;
        const tooltipHeight = root.targetHeight;
        const spacing = 5;

        let newX = 0;
        let newY = 0;

        if (root.side === Tooltip.Right) {
            let barRight = 0;
            let anc = root.target;
            while (anc) {
                if (anc.isOlvexBar) {
                    barRight = anc.mapToItem(parent, anc.width, 0).x;
                    break;
                }
                anc = anc.parent;
            }
            newX = Math.max(targetPos.x + target.width, barRight) + spacing;
            newY = targetCenterY - tooltipHeight / 2;
        } else if (root.side === Tooltip.Left) {
            newX = targetPos.x - tooltipWidth - spacing;
            newY = targetCenterY - tooltipHeight / 2;
        } else if (root.side === Tooltip.Bottom) {
            newX = targetCenterX - tooltipWidth / 2;
            newY = targetPos.y + target.height + spacing;
        } else {
            // Tooltip.Top (default)
            newX = targetCenterX - tooltipWidth / 2;
            newY = targetPos.y - tooltipHeight - spacing;
        }

        // Keep within bounds
        const padding = (GlobalConfig.appearance && GlobalConfig.appearance.padding) ? GlobalConfig.appearance.padding.normal : 12;
        if (newX < padding) {
            newX = padding;
        } else if (parent.width > 0 && newX + tooltipWidth > (parent.width - padding)) {
            newX = Math.max(padding, parent.width - tooltipWidth - padding);
        }

        if (newY < padding) {
            newY = padding;
        } else if (parent.height > 0 && newY + tooltipHeight > (parent.height - padding)) {
            newY = Math.max(padding, parent.height - tooltipHeight - padding);
        }

        if (immediate) {
            slidingActive = false;
        }
        x = newX;
        y = newY;
    }

    Behavior on x {
        enabled: root.visible && root.slidingActive
        SpringAnimation {
            spring: 7.5
            damping: 0.78
            mass: 1.0
            epsilon: 0.005
        }
    }

    Behavior on y {
        enabled: root.visible && root.slidingActive
        SpringAnimation {
            spring: 7.5
            damping: 0.78
            mass: 1.0
            epsilon: 0.005
        }
    }

    Behavior on width {
        enabled: root.visible && root.slidingActive
        SpringAnimation {
            spring: 7.5
            damping: 0.78
            mass: 1.0
            epsilon: 0.005
        }
    }

    Behavior on height {
        enabled: root.visible && root.slidingActive
        SpringAnimation {
            spring: 7.5
            damping: 0.78
            mass: 1.0
            epsilon: 0.005
        }
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
            updatePosition(true);
            Qt.callLater(() => {
                if (root.tooltipVisible) {
                    root.slidingActive = true;
                }
            });
        } else {
            slidingActive = false;
        }
    }

    onTargetChanged: {
        if (tooltipVisible && target) {
            updatePosition(false);
        }
    }

    onTextChanged: {
        if (tooltipVisible) {
            Qt.callLater(() => {
                if (root.tooltipVisible) {
                    root.updatePosition(false);
                }
            });
        }
    }

    Component.onCompleted: {
        if (tooltipVisible) {
            updatePosition(true);
            Qt.callLater(() => {
                if (root.tooltipVisible) {
                    root.slidingActive = true;
                }
            });
        }
    }

    enter: Transition {
        ParallelAnimation {
            Anim {
                property: "opacity"
                from: 0
                to: 1
                type: Anim.FastSpatial
            }
            Anim {
                target: tooltipRect
                property: "scale"
                from: 0.86
                to: 1.0
                type: Anim.ExpressiveFastSpatial
            }
        }
    }

    exit: Transition {
        ParallelAnimation {
            Anim {
                property: "opacity"
                from: 1
                to: 0
                type: Anim.FastSpatial
            }
            Anim {
                target: tooltipRect
                property: "scale"
                from: 1.0
                to: 0.9
                type: Anim.FastSpatial
            }
        }
    }

    contentItem: StyledRect {
        id: tooltipRect

        anchors.fill: parent
        transformOrigin: root.side === Tooltip.Right ? Item.Left : (root.side === Tooltip.Left ? Item.Right : (root.side === Tooltip.Bottom ? Item.Top : Item.Bottom))
        color: Colours.tileSurface
        radius: GlobalConfig.appearance.rounding.small
        antialiasing: true
        border.width: 0
        clip: true

        StyledText {
            id: tooltipText

            anchors.centerIn: parent

            text: root.text
            color: Colours.palette.m3onSurface
            textPointSize: GlobalConfig.appearance.font.size.small
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Connections {
        function onXChanged() {
            if (root.tooltipVisible)
                root.updatePosition(false);
        }
        function onYChanged() {
            if (root.tooltipVisible)
                root.updatePosition(false);
        }
        function onWidthChanged() {
            if (root.tooltipVisible)
                root.updatePosition(false);
        }
        function onHeightChanged() {
            if (root.tooltipVisible)
                root.updatePosition(false);
        }

        target: root.target
    }

    // Monitor hover state
    Connections {
        ignoreUnknownSignals: true
        function onHoveredChanged() {
            if (target && "hovered" in target)
                root.handleHover(target.hovered);
        }
        function onContainsMouseChanged() {
            if (target && "containsMouse" in target)
                root.handleHover(target.containsMouse);
        }

        target: root.target
    }

    function handleHover(isHovering) {
        if (isHovering) {
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
}
