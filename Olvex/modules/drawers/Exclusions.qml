
import QtQuick
import Quickshell
import Olvex.Config
import qs.components.containers
import qs.modules.bar as Bar
import "../setup"

Scope {
    id: root

    required property ShellScreen screen
    required property Bar.BarWrapper bar

    ExclusionZone {
        anchors.left: true
        anchors.top: true
        anchors.bottom: true
        exclusiveZone: SetupFactory.active ? 0 : root.bar.exclusiveZone
        implicitWidth: exclusiveZone
    }

    ExclusionZone {
        id: topZone
        anchors.top: true
        anchors.left: true
        anchors.right: true
        exclusiveZone: (SetupFactory.active ? 0 : ((contentItem && contentItem.Config && contentItem.Config.border) ? contentItem.Config.border.thickness : 0))
        implicitHeight: exclusiveZone
        visible: exclusiveZone > 0
    }

    ExclusionZone {
        id: rightZone
        anchors.right: true
        anchors.top: true
        anchors.bottom: true
        exclusiveZone: (SetupFactory.active ? 0 : ((contentItem && contentItem.Config && contentItem.Config.border) ? contentItem.Config.border.thickness : 0))
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
                return 80;
            return (contentItem && contentItem.Config && contentItem.Config.border) ? contentItem.Config.border.thickness : 0;
        }
        implicitHeight: exclusiveZone
    }

    component ExclusionZone: StyledWindow {
        screen: root.screen
        name: "border-exclusion"
        exclusiveZone: (SetupFactory.active ? 0 : ((contentItem && contentItem.Config && contentItem.Config.border) ? contentItem.Config.border.thickness : 0))
        visible: exclusiveZone > 0
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1
    }
}
