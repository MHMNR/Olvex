import QtQuick
import Quickshell
import Quickshell.Wayland
import Olvex.Config

PanelWindow {
    id: root
    
    required property ShellScreen oskScreen
    required property var visibilities
    
    readonly property bool isDocked: visibilities.isOskDocked
    readonly property bool isDragging: osk && osk.isDragging
    
    visible: true
    screen: oskScreen
    color: "transparent"
    
    // Stable window height to prevent coordinate jitter
    implicitHeight: screen.height
    implicitWidth: screen.width
    
    mask: Region {
        x: 0
        y: root.isDragging ? 0 : (osk.y - (osk.showingSettings ? 450 : 0))
        width: screen.width
        height: root.isDragging ? screen.height : (osk.height + (osk.showingSettings ? 450 : 0))
    }

    anchors.top: true // Restore full-screen anchoring for coordinate stability
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    
    WlrLayershell.margins.bottom: 0
    WlrLayershell.margins.left: 0

    // Master animation source for Dock/Float
    property real dockProgress: 0.0
    Binding on dockProgress { value: isDocked ? 1.0 : 0.0 }
    Behavior on dockProgress { 
        enabled: !root.isDragging && entranceProgress > 0.9
        NumberAnimation { 
            duration: Tokens.anim.durations.expressiveDefaultSpatial
            easing.type: Easing.OutQuart
        } 
    }

    // Entrance/Exit animation source (Slide ONLY)
    property real entranceProgress: 0.0
    Binding on entranceProgress { value: visibilities.osk ? 1.0 : 0.0 }
    Behavior on entranceProgress { 
        NumberAnimation { 
            duration: Tokens.anim.durations.expressiveDefaultSpatial + 100
            easing.type: Easing.OutExpo
        } 
    }
    
    // THE STABILITY FIX: Use a fixed exclusive zone for docked mode
    exclusiveZone: isDocked && visibilities.osk ? Math.round((osk ? osk.implicitHeight : 350) + 6) : 0
    
    WlrLayershell.namespace: "quickshell:osk"
    WlrLayershell.layer: isDocked && visibilities.osk ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    
    property real floatingX: Math.round((screen.width - (osk ? osk.implicitWidth : 800)) / 2)
    property real floatingY: Math.round(screen.height - (osk ? osk.implicitHeight : 350) - 40)
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
        
        layer.enabled: osk.showingSettings
        layer.smooth: true
        
        readonly property real offScreenY: Math.round(screen.height + 160)
        readonly property real dockedY: Math.round(screen.height - implicitHeight - 3)
        readonly property real dockedX: 3
        
        x: Math.round(dockedX + (floatingX - dockedX) * (1.0 - dockProgress))
        
        readonly property real currentActiveY: dockedY + (floatingY - dockedY) * (1.0 - dockProgress)
        y: Math.round(offScreenY + (currentActiveY - offScreenY) * root.entranceProgress)
        
        width: implicitWidth + (parent.width - 6 - implicitWidth) * dockProgress
        
        onHideRequested: visibilities.osk = false
        
        onDragged: (dx, dy) => {
            if (!isDocked) {
                root.floatingX = Math.max(0, Math.min(screen.width - implicitWidth, root.startX + dx));
                root.floatingY = Math.max(0, Math.min(screen.height - implicitHeight, root.startY + dy));
            }
        }
    }
}
