import Quickshell
import Quickshell.Wayland
import Olvex.Config

// qmllint disable uncreatable-type
PanelWindow {
    id: win
    // qmllint enable uncreatable-type
    required property string name

    WlrLayershell.namespace: `olvex-${name}`
    color: "transparent"

    Config.screen: (win.screen && win.screen.name) ? win.screen.name : ""
    Tokens.screen: (win.screen && win.screen.name) ? win.screen.name : ""

    contentItem.Config.screen: (win.screen && win.screen.name) ? win.screen.name : ""
    contentItem.Tokens.screen: (win.screen && win.screen.name) ? win.screen.name : ""
}
