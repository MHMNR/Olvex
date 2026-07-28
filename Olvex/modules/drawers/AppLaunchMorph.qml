import QtQuick
import Quickshell.Widgets
import Olvex.Config
import qs.components
import qs.components.effects
import qs.services

// Flying icon overlay: animates an app icon from the launcher to its pinned dock slot.
// Placed inside ContentWindow at high z-index above panels.
Item {
    id: root

    // References wired by ContentWindow
    property DrawerVisibilities visibilities
    property Item bottomPanel       // panels.bottomPanel
    property Item pinnedLayout      // panels.bottomPanel > layout (the pinned apps container)

    readonly property string pinnedAppsSource: root.visibilities.pinnedApps || []

    // The flying icon card
    readonly property alias flyingIcon: flyingCard

    function findPinnedSlotIndex(appId: string): int {
        const apps = root.pinnedAppsSource;
        for (let i = 0; i < apps.length; i++) {
            if (apps[i] === appId) return i;
        }
        return -1;
    }

    // Called from Panels.triggerAppMorph or GridAppItem
    // srcRect: {x, y, w, h} in ContentWindow coordinate space
    function trigger(appId: string, iconSource: string, srcRect: var): bool {
        const slotIndex = findPinnedSlotIndex(appId);
        if (slotIndex < 0) return false;

        // The bottom panel must be visible to compute destination
        if (!root.bottomPanel.visible && !root.visibilities.bottomPanel) return false;

        // Find the pinned slot delegate — each is a Repeater child of layout
        const layoutChildren = root.pinnedLayout.children;
        let targetSlot = null;
        for (let i = 0; i < layoutChildren.length; i++) {
            const child = layoutChildren[i];
            if (child.appId === appId && child.index === slotIndex) {
                targetSlot = child;
                break;
            }
        }
        if (!targetSlot) return false;

        // Find iconBg inside the slot delegate
        let iconBg = null;
        for (let c = 0; c < targetSlot.children.length; c++) {
            if (targetSlot.children[c].objectName === "iconBg") {
                iconBg = targetSlot.children[c];
                break;
            }
            // Fallback: find by id pattern — the Rectangle with width:44 height:44 radius:10
            if (targetSlot.children[c].width === 44 && targetSlot.children[c].height === 44 && targetSlot.children[c].radius === 10) {
                iconBg = targetSlot.children[c];
                break;
            }
        }
        if (!iconBg) return false;

        // Compute destination rect in ContentWindow coordinates
        const destRect = iconBg.mapToItem(root, 0, 0);
        _appId = appId;
        _iconSource = iconSource;
        _slotIndex = slotIndex;
        _srcX = srcRect.x;
        _srcY = srcRect.y;
        _srcW = srcRect.w;
        _srcH = srcRect.h;
        _dstX = destRect.x;
        _dstY = destRect.y;
        _dstW = 44;
        _dstH = 44;

        // Position at source, start flight
        flyingCard.x = _srcX + _srcW / 2 - _dstW / 2;
        flyingCard.y = _srcY + _srcH / 2 - _dstH / 2;
        flyingCard.scale = _srcW / _dstW;
        flyingCard.opacity = 1;
        flyingCard.visible = true;

        flightAnim.start();
        return true;
    }

    // Internal state
    property string _appId: ""
    property string _iconSource: ""
    property int _slotIndex: -1
    property real _srcX: 0
    property real _srcY: 0
    property real _srcW: 0
    property real _srcH: 0
    property real _dstX: 0
    property real _dstY: 0
    property real _dstW: 44
    property real _dstH: 44

    z: 2000  // Above panels (z:0-10), below focus-grab dismiss

    visible: flyingCard.visible

    // The flying icon card — matches pinned dock icon styling
    Rectangle {
        id: flyingCard

        width: 44
        height: 44
        radius: 10

        visible: false
        opacity: 0
        smooth: true
        antialiasing: true

        color: Colours.layer(Colours.palette.m3surfaceVariant, 0.5)
        border.color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
        border.width: 1

        // Elevation shadow for the flying card
        layer.enabled: true
        layer.effect: Elevation {
            level: 3
            radius: 10
        }

        IconImage {
            asynchronous: true
            source: root._iconSource
            anchors.fill: parent
            anchors.margins: 6
            smooth: true
        }
    }

    // Flight animation: src → dst with M3 expressive easing
    ParallelAnimation {
        id: flightAnim

        NumberAnimation {
            target: flyingCard
            property: "x"
            from: root._srcX + root._srcW / 2 - root._dstW / 2
            to: root._dstX
            duration: Tokens.anim.durations.expressiveDefaultSpatial
            easing: Tokens.anim.emphasizedDecel
        }

        NumberAnimation {
            target: flyingCard
            property: "y"
            from: root._srcY + root._srcH / 2 - root._dstH / 2
            to: root._dstY
            duration: Tokens.anim.durations.expressiveDefaultSpatial
            easing: Tokens.anim.emphasizedDecel
        }

        NumberAnimation {
            target: flyingCard
            property: "scale"
            from: root._srcW / Math.max(1, root._dstW)
            to: 1.0
            duration: Tokens.anim.durations.expressiveDefaultSpatial
            easing: Tokens.anim.emphasizedDecel
        }

        // Slight fade-out near the end so landingAnim takeover is seamless
        SequentialAnimation {
            PauseAnimation {
                duration: Math.max(0, Tokens.anim.durations.expressiveDefaultSpatial - 80)
            }
            NumberAnimation {
                target: flyingCard
                property: "opacity"
                from: 1
                to: 0
                duration: 80
                easing.type: Easing.InQuad
            }
        }

        onFinished: {
            // Trigger landingAnim on the pinned slot
            root.visibilities.pinnedAppsLandingAppId = root._appId;

            flyingCard.visible = false;
            flyingCard.opacity = 0;
            root._appId = "";
        }
    }
}
