pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Olvex.Config
import qs.services
import qs.modules.clipboard as Clipboard
import "../dashboard/dash/osk"

Variants {
    model: Screens.screens

    Scope {
        id: scope

        required property ShellScreen modelData

        Exclusions {
            screen: scope.modelData
            bar: content.bar
        }

        ContentWindow {
            id: content

            screen: scope.modelData
        }

        Loader {
            id: oskLoader

            readonly property bool shouldBeActive: content.visibilities.osk
            active: shouldBeActive || teardownGrace.running
            asynchronous: true

            Timer {
                id: teardownGrace
                interval: Tokens.anim.durations.expressiveDefaultSpatial + 150
            }

            onShouldBeActiveChanged: {
                if (shouldBeActive)
                    teardownGrace.stop();
                else
                    teardownGrace.restart();
            }

            onItemChanged: {
                content.oskWindow = item ?? null;
            }

            sourceComponent: OnScreenKeyboardWindow {
                oskScreen: scope.modelData
                visibilities: content.visibilities
            }
        }

        Clipboard.ClipboardFloating {
            id: clipboardFloatingWin
        }
    }
}
