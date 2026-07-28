pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
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

        OnScreenKeyboardWindow {
            id: oskWin
            oskScreen: scope.modelData
            visibilities: content.visibilities
            Component.onCompleted: content.oskWindow = oskWin
        }

        Clipboard.ClipboardFloating {
            id: clipboardFloatingWin
        }
    }
}
