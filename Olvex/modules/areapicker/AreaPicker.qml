
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components.containers
import qs.components.misc
import qs.services

Scope {
    LazyLoader {
        id: root

        property bool freeze
        property bool closing
        property bool clipboardOnly

        onActiveChanged: {
            Visibilities.areaPickerActive = active;
        }
        onClosingChanged: {
            if (closing)
                Visibilities.areaPickerActive = false;
        }

        Variants {
            model: Screens.screens

            StyledWindow {
                id: win

                required property ShellScreen modelData

                screen: modelData
                name: "area-picker"
                WlrLayershell.exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: root.closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
                mask: root.closing ? empty : null

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                Region {
                    id: empty
                }

                Picker {
                    loader: root
                    screen: win.modelData
                }
            }
        }
    }

    IpcHandler {
        function open(): void {
            Visibilities.areaPickerActive = true;
            root.freeze = false;
            root.closing = false;
            root.clipboardOnly = false;
            root.activeAsync = true;
        }

        function openFreeze(): void {
            Visibilities.areaPickerActive = true;
            root.freeze = true;
            root.closing = false;
            root.clipboardOnly = false;
            root.activeAsync = true;
        }

        function openClip(): void {
            Visibilities.areaPickerActive = true;
            root.freeze = false;
            root.closing = false;
            root.clipboardOnly = true;
            root.activeAsync = true;
        }

        function openFreezeClip(): void {
            Visibilities.areaPickerActive = true;
            root.freeze = true;
            root.closing = false;
            root.clipboardOnly = true;
            root.activeAsync = true;
        }

        target: "picker"
    }

    CustomShortcut {
        name: "screenshot"
        description: "Open screenshot tool"
        onPressed: {
            Visibilities.areaPickerActive = true;
            root.freeze = false;
            root.closing = false;
            root.clipboardOnly = false;
            root.activeAsync = true;
        }
    }

    CustomShortcut {
        name: "screenshotFreeze"
        description: "Open screenshot tool (freeze mode)"
        onPressed: {
            Visibilities.areaPickerActive = true;
            root.freeze = true;
            root.closing = false;
            root.clipboardOnly = false;
            root.activeAsync = true;
        }
    }

    CustomShortcut {
        name: "screenshotClip"
        description: "Open screenshot tool (clipboard)"
        onPressed: {
            Visibilities.areaPickerActive = true;
            root.freeze = false;
            root.closing = false;
            root.clipboardOnly = true;
            root.activeAsync = true;
        }
    }

    CustomShortcut {
        name: "screenshotFreezeClip"
        description: "Open screenshot tool (freeze mode, clipboard)"
        onPressed: {
            Visibilities.areaPickerActive = true;
            root.freeze = true;
            root.closing = false;
            root.clipboardOnly = true;
            root.activeAsync = true;
        }
    }
}
