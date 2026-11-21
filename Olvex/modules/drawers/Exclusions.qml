
import QtQuick
import Quickshell
import Olvex.Config
import qs.components.containers
import qs.modules.bar as Bar
import qs.utils
import "../setup"

Scope {
    id: root

    required property ShellScreen screen
    required property Bar.BarWrapper bar
    readonly property real uiScale: UiScale.forScreen(root.screen)

    ExclusionZone {
        anchors.left: true
        anchors.top: true
        anchors.bottom: true
        exclusiveZone: SetupFactory.active ? 0 : Math.round(root.bar.exclusiveZone * root.uiScale)
        implicitWidth: exclusiveZone
    }

    ExclusionZone {
        id: topZone
        anchors.top: true
        anchors.left: true
        anchors.right: true
        exclusiveZone: (SetupFactory.active ? 0 : Math.round(((contentItem && contentItem.Config && contentItem.Config.border) ? contentItem.Config.border.thickness : 0) * root.uiScale))
        implicitHeight: exclusiveZone
        visible: exclusiveZone > 0
    }

    ExclusionZone {
        id: rightZone
        anchors.right: true
        anchors.top: true
        anchors.bottom: true
        exclusiveZone: (SetupFactory.active ? 0 : Math.round(((contentItem && contentItem.Config && contentItem.Config.border) ? contentItem.Config.border.thickness : 0) * root.uiScale))
        implicitWidth: exclusiveZone
        visible: exclusiveZone > 0
    }

    ExclusionZone {
        id: bottomZone
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        // Read Config directly (singleton accessible via contentItem.Config).
        // Cross-window bindings to ContentWindow properties are unreliable because
        // ExclusionZone is a separate Wayland PanelWindow.
        exclusiveZone: {
            if (SetupFactory.active)
                return 0;
            const sec = (contentItem && contentItem.Config && contentItem.Config.bar) ? contentItem.Config.bar.secondaryPanel : null;
            const enabled = sec ? sec.enabled : true;
            const mode = sec ? sec.visibilityMode : "always";
            if (enabled && mode === "always")
                return Math.round(80 * root.uiScale);
            return Math.round(((contentItem && contentItem.Config && contentItem.Config.border) ? contentItem.Config.border.thickness : 0) * root.uiScale);
        }
        implicitHeight: exclusiveZone
    }

    component ExclusionZone: StyledWindow {
        screen: root.screen
        name: "border-exclusion"
        exclusiveZone: (SetupFactory.active ? 0 : Math.round(((contentItem && contentItem.Config && contentItem.Config.border) ? contentItem.Config.border.thickness : 0) * root.uiScale))
        visible: exclusiveZone > 0
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1
    }
}
