
import QtQuick
import Quickshell
import qs.modules.bar as Bar

Region {
    id: root

    required property Bar.BarWrapper bar
    required property Panels panels
    required property var win
    required property var morph

    readonly property real borderThickness: win.safeBorder.thickness
    readonly property real clampedThickness: win.safeBorder.clampedThickness
    readonly property bool borderFloating: win.safeBorder.floating

    readonly property real topEdgeTrigger: 4
    readonly property real bottomEdgeTrigger: 4
    readonly property real rightEdgeTrigger: 3

    readonly property real topInset: Math.max(topEdgeTrigger, clampedThickness)
    readonly property real bottomInset: Math.max(bottomEdgeTrigger, clampedThickness)
    readonly property real rightInset: Math.max(rightEdgeTrigger, clampedThickness)

    x: bar.clampedWidth + win.dragMaskPadding
    y: topInset + win.dragMaskPadding
    width: Math.max(0, win.width - bar.clampedWidth - rightInset - win.dragMaskPadding * 2)
    height: Math.max(0, win.height - topInset - bottomInset - win.dragMaskPadding * 2)
    intersection: Intersection.Xor

    // Top-right hot corner for dragging open QS panel (independent of border thickness)
    Region {
        readonly property real zoneSize: 56
        x: root.win.width - zoneSize
        y: 0
        width: zoneSize
        height: zoneSize
        intersection: Intersection.Subtract
    }

    R {
        panel: root.panels.dashboard
        y: 0
        customHeight: (1 - root.panels.dashboard.offsetScale) > 0 ? (panel.height * (1 - root.panels.dashboard.offsetScale) + root.borderThickness) : 0
    }

    R {
        panel: root.panels.launcher
        y: root.win.height - height
        customHeight: (1 - root.panels.launcher.offsetScale) > 0 ? (panel.height * (1 - root.panels.launcher.offsetScale) + root.borderThickness) : 0
    }

    R {
        panel: root.panels.wallpaperSelector
        y: root.win.height - height
        customHeight: (1 - root.panels.wallpaperSelector.offsetScale) > 0 ? (panel.height * (1 - root.panels.wallpaperSelector.offsetScale) + root.borderThickness) : 0
    }

    R {
        id: sessionRegion

        panel: root.panels.powermenuWrapper
        x: root.win.width - width
        customWidth: (1 - root.panels.powermenu.offsetScale) > 0 ? (panel.width * (1 - root.panels.powermenu.offsetScale) + root.borderThickness) : 0
    }

    R {
        panel: root.panels.flyoutsWrapper
        x: root.win.width - width
        customWidth: (1 - root.panels.flyouts.offsetScale) > 0 ? (panel.width * (1 - root.panels.flyouts.offsetScale) + root.borderThickness + sessionRegion.width) : 0
    }

    R {
        panel: root.panels.notifications
        y: 0
        customHeight: panel.height > 0 ? (panel.height + root.borderThickness) : 0
    }

    R {
        // QS / qspanel panel slides in from the right
        panel: root.panels.qspanel
        x: root.win.width - width
        customWidth: (1 - root.panels.qspanel.offsetScale) > 0
            ? (panel.width * (1 - root.panels.qspanel.offsetScale) + root.borderThickness)
            : 0
        customHeight: panel.height > 0 ? (panel.height + root.borderThickness) : 0
    }

    R {
        panel: root.panels.bottomPanel
        y: root.win.height - height
        customHeight: root.panels.bottomPanelVisible ? panel.height : 0
    }

    R {
        panel: root.panels.popoutsWrapper
        customWidth: (1 - root.panels.popoutsWrapper.offsetScale) > 0 ? (panel.width * (1 - root.panels.popoutsWrapper.offsetScale)) : 0
    }

    R {
        panel: root.panels.toasts
        customWidth: root.panels.toasts.implicitHeight > 0 ? root.panels.toasts.width : 0
        customHeight: root.panels.toasts.implicitHeight > 0 ? root.panels.toasts.height : 0
    }

    component R: Region {
        required property Item panel
        property real customWidth: panel.width
        property real customHeight: panel.height

        readonly property int gap: root.borderFloating ? 5 : 0
        readonly property real extra: root.borderThickness + gap + 15

        x: panel.x + root.bar.implicitWidth + gap - extra
        y: panel.y + root.borderThickness + gap - extra
        width: customWidth > 0 && customHeight > 0 ? (customWidth + extra * 2) : 0
        height: customWidth > 0 && customHeight > 0 ? (customHeight + extra * 2) : 0
        intersection: Intersection.Subtract
    }
}
