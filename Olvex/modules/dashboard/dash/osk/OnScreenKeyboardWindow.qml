import QtQuick
import Quickshell
import Quickshell.Wayland
import Olvex.Config
import qs.components
import qs.utils

PanelWindow {
    id: root
    
    required property ShellScreen oskScreen
    required property var visibilities
    readonly property real uiScale: UiScale.forScreen(screen)
    readonly property Item scaledContentRoot: osk
    
    readonly property bool isDocked: visibilities ? visibilities.isOskDocked : false
    readonly property bool isDragging: osk && osk.isDragging
    
    // Keep visible while osk is transitioning off screen
    visible: (visibilities && visibilities.osk) || (osk && osk.y < osk.offScreenY)
    screen: oskScreen
    color: "transparent"
    
    // Stable window height to prevent coordinate jitter
    implicitHeight: screen.height
    implicitWidth: screen.width
    
    mask: Region {
        x: root.isDragging ? 0 : osk.x
        y: root.isDragging ? 0 : Math.round(osk.y - (osk.showingSettings ? 450 * root.uiScale : 0))
        width: root.isDragging ? screen.width : Math.round(osk.width * root.uiScale)
        height: root.isDragging ? screen.height : Math.round((osk.height + (osk.showingSettings ? 450 : 0)) * root.uiScale)
    }

    anchors.top: false
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    
    WlrLayershell.margins.bottom: 0
    WlrLayershell.margins.left: 0
    
    // Smooth exclusive zone for docked mode
    readonly property bool exclusiveZoneEnabled: osk ? osk.exclusiveZone : false
    exclusiveZone: exclusiveZoneEnabled && isDocked && (visibilities && visibilities.osk) && (osk.y <= osk.dockedY + 1) ? Math.round((osk ? osk.renderedHeight : 350 * root.uiScale) + 6 * root.uiScale) : 0
    
    WlrLayershell.namespace: "quickshell:osk"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    
    property real floatingX: (screen.width - (osk ? osk.renderedWidth : 800 * root.uiScale)) / 2
    property real floatingY: screen.height - (osk ? osk.renderedHeight : 350 * root.uiScale) - Math.round(40 * root.uiScale)
    property real startX: 0
    property real startY: 0
    
    Connections {
        target: osk
        function onIsDraggingChanged() {
            if (osk.isDragging) {
                root.startX = root.floatingX;
                root.startY = root.floatingY;
            }
        }
    }

    OnScreenKeyboard {
        id: osk
        visibilities: root.visibilities
        transformOrigin: Item.TopLeft
        scale: root.uiScale
        
        layer.enabled: osk.showingSettings
        layer.smooth: true

        readonly property real safeImplicitHeight: implicitHeight > 100 ? implicitHeight : 350
        readonly property real safeImplicitWidth: implicitWidth > 200 ? implicitWidth : 800
        readonly property real renderedWidth: (isDocked ? root.width : safeImplicitWidth * root.uiScale)
        readonly property real renderedHeight: safeImplicitHeight * root.uiScale
        
        readonly property real offScreenY: screen.height + 20
        readonly property real dockedY: screen.height - renderedHeight
        readonly property real dockedX: 0
        
        x: isDocked ? dockedX : floatingX
        y: (visibilities && visibilities.osk) ? (isDocked ? dockedY : floatingY) : offScreenY
        width: isDocked ? UiScale.virtualWidth(root.width, root.uiScale) : safeImplicitWidth
        
        Behavior on x { enabled: !root.isDragging; Anim { type: Anim.DefaultSpatial } }
        Behavior on y { enabled: !root.isDragging; Anim { type: Anim.DefaultSpatial } }
        Behavior on width { Anim { type: Anim.DefaultSpatial } }
        
        onHideRequested: {
            if (visibilities) {
                visibilities.osk = false;
            }
        }
        
        onDragged: (dx, dy) => {
            if (!isDocked) {
                root.floatingX = Math.max(0, Math.min(screen.width - osk.renderedWidth, root.startX + dx));
                root.floatingY = Math.max(0, Math.min(screen.height - osk.renderedHeight, root.startY + dy));
            }
        }
    }
}
