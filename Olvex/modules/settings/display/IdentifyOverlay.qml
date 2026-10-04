import "."
import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Olvex.Config
import qs.services

Scope {
    id: root

    readonly property int rExLarge: (Tokens.rounding && typeof Tokens.rounding.extraLarge !== "undefined") ? Tokens.rounding.extraLarge : 24
    readonly property int rFull: (Tokens.rounding && typeof Tokens.rounding.full !== "undefined") ? Tokens.rounding.full : 999
    readonly property int fExLarge: (Tokens.font && typeof Tokens.font.size.extraLarge !== "undefined") ? Tokens.font.size.extraLarge : 20
    readonly property int fLarge: (Tokens.font && typeof Tokens.font.size.large !== "undefined") ? Tokens.font.size.large : 16
    readonly property int fSmall: (Tokens.font && typeof Tokens.font.size.small !== "undefined") ? Tokens.font.size.small : 12

    Variants {
        model: Quickshell.screens

        StyledWindow {
            id: win
            required property ShellScreen modelData

            screen: modelData
            name: "display-identifier-" + modelData.name
            visible: DisplayManager.identifyActive

            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"

            StyledRect {
                anchors.centerIn: parent
                implicitWidth: 260
                implicitHeight: 200
                radius: root.rExLarge
                color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.95)
                border.width: 3
                border.color: Colours.palette.m3primary

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    // Screen index / number
                    StyledRect {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 80
                        implicitHeight: 80
                        radius: root.rFull
                        color: Colours.palette.m3primary

                        StyledText {
                            anchors.centerIn: parent
                            text: {
                                const idx = DisplayManager.monitors.findIndex(m => m.name === win.modelData.name);
                                return String(idx >= 0 ? idx + 1 : 1);
                            }
                            font.weight: Font.Bold
                            textPointSize: root.fExLarge * 1.5
                            color: Colours.palette.m3onPrimary
                        }
                    }

                    // Connector Name
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: win.modelData.name
                        font.weight: Font.Bold
                        textPointSize: root.fLarge
                        color: Colours.palette.m3onSurface
                    }

                    // Resolution
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: `${win.modelData.width} × ${win.modelData.height}`
                        textPointSize: root.fSmall
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }
    }
}
