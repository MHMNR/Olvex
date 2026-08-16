
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

            active: content.visibilities.osk
            asynchronous: true

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
