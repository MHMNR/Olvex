
import ".."
import "../chrome"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.controls

Item {
    id: root
    
    property var session
    
    opacity: 0
    y: 10
    Component.onCompleted: cascadeIn.start()
    
    ParallelAnimation {
        id: cascadeIn
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens.anim.durations.long; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens.anim.durations.long; easing.type: Easing.OutCubic }
    }

    implicitHeight: col.implicitHeight + Tokens.padding.large * 2
    
    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Tokens.padding.large
        anchors.rightMargin: Tokens.padding.large
        anchors.topMargin: Tokens.padding.large
        spacing: 0

        SettingRow {
            title: qsTr("Enable session menu")
            description: qsTr("Allow opening the power menu")
            divider: true
            StyledSwitch {
                checked: Config.powermenu.enabled ?? true
                onToggled: {
                    GlobalConfig.powermenu.enabled = checked;
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Vim keybinds")
            description: qsTr("Navigate the menu with h/j/k/l")
            divider: false
            StyledSwitch {
                checked: Config.powermenu.vimKeybinds ?? false
                onToggled: {
                    GlobalConfig.powermenu.vimKeybinds = checked;
                    GlobalConfig.save();
                }
            }
        }
    }
}
