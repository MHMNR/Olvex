
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
            title: qsTr("Enable launcher")
            description: qsTr("Allow opening the app launcher")
            divider: true
            StyledSwitch {
                checked: Config.launcher.enabled ?? true
                onToggled: {
                    GlobalConfig.launcher.enabled = checked;
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Show on hover")
            description: qsTr("Open when hovering its edge")
            divider: true
            StyledSwitch {
                checked: Config.launcher.showOnHover ?? false
                onToggled: {
                    GlobalConfig.launcher.showOnHover = checked;
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Vim keybinds")
            description: qsTr("Navigate results with h/j/k/l")
            divider: true
            StyledSwitch {
                checked: GlobalConfig.launcher.vimKeybinds ?? false
                onToggled: {
                    GlobalConfig.launcher.vimKeybinds = checked;
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Enable dangerous actions")
            description: qsTr("Allow shutdown / reboot from search")
            divider: true
            StyledSwitch {
                checked: GlobalConfig.launcher.enableDangerousActions ?? true
                onToggled: {
                    GlobalConfig.launcher.enableDangerousActions = checked;
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Max results")
            description: qsTr("Number of results shown at once")
            divider: true
            CustomSpinBox {
                value: Config.launcher.maxShown ?? 8
                min: 3
                max: 20
                step: 1
                onValueModified: v => {
                    GlobalConfig.launcher.maxShown = v;
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Action prefix")
            description: qsTr("Character that triggers action search")
            divider: true
            StyledTextField {
                width: 90
                text: GlobalConfig.launcher.actionPrefix || ">"
                onEditingFinished: {
                    GlobalConfig.launcher.actionPrefix = text;
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Special prefix")
            description: qsTr("Character that triggers special commands")
            divider: false
            StyledTextField {
                width: 90
                text: GlobalConfig.launcher.specialPrefix || "@"
                onEditingFinished: {
                    GlobalConfig.launcher.specialPrefix = text;
                    GlobalConfig.save();
                }
            }
        }
    }
}
