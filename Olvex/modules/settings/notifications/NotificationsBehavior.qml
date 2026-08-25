
import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config

Item {
    id: root
    
    property Session session
    
    opacity: 0
    y: 10
    Component.onCompleted: cascadeIn.start()
    
    ParallelAnimation {
        id: cascadeIn
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens?.anim?.durations?.slow ?? 400; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens?.anim?.durations?.slow ?? 400; easing.type: Easing.OutCubic }
    }

    implicitHeight: (col ? col.implicitHeight : 0) + Tokens.padding.large * 2
    
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
            title: qsTr("Auto-expire")
            description: qsTr("Dismiss notifications automatically after a timeout")
            divider: true
            StyledSwitch {
                checked: GlobalConfig.notifs.expire
                onToggled: {
                    GlobalConfig.notifs.expire = checked;
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Default timeout (seconds)")
            description: qsTr("How long a notification stays before expiring")
            divider: true
            CustomSpinBox {
                value: Math.round((GlobalConfig.notifs.defaultExpireTimeout || 5000) / 1000)
                min: 1
                max: 30
                step: 1
                onValueModified: v => {
                    GlobalConfig.notifs.defaultExpireTimeout = v * 1000;
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Show in fullscreen")
            description: qsTr("Allow popups over fullscreen apps")
            divider: true
            StyledSwitch {
                checked: (GlobalConfig.notifs.fullscreen || "on") === "on"
                onToggled: {
                    GlobalConfig.notifs.fullscreen = checked ? "on" : "off";
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Open expanded")
            description: qsTr("Show the full notification body immediately")
            divider: true
            StyledSwitch {
                checked: Config.notifs.openExpanded ?? false
                onToggled: {
                    GlobalConfig.notifs.openExpanded = checked;
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Group preview count")
            description: qsTr("Notifications shown before a group collapses")
            divider: false
            CustomSpinBox {
                value: Config.notifs.groupPreviewNum ?? 3
                min: 1
                max: 8
                step: 1
                onValueModified: v => {
                    GlobalConfig.notifs.groupPreviewNum = v;
                    GlobalConfig.save();
                }
            }
        }
    }
}
