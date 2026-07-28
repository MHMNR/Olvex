pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Olvex.Config
import qs.components.containers
import qs.modules.bar as Bar

Scope {
    id: root

    required property ShellScreen screen
    required property Bar.BarWrapper bar

    ExclusionZone {
        anchors.left: true
        anchors.top: true
        anchors.bottom: true
        exclusiveZone: root.bar.exclusiveZone
        implicitWidth: exclusiveZone
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
            const enabled = contentItem.Config.bar.bottomPanel?.enabled ?? true;
            const mode    = contentItem.Config.bar.bottomPanel?.visibilityMode ?? "always";
            if (enabled && mode === "always")
                return 80;
            return contentItem?.Config?.border?.thickness ?? 0;
        }
        implicitHeight: exclusiveZone
    }

    component ExclusionZone: StyledWindow {
        screen: root.screen
        name: "border-exclusion"
        exclusiveZone: contentItem?.Config?.border?.thickness ?? 0
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1
    }
}
