
import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.services

Item {
    id: root
    
    property Session session
    
    opacity: 0
    y: 10
    Component.onCompleted: cascadeIn.start()
    
    ParallelAnimation {
        id: cascadeIn
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens.anim.durations.large; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens.anim.durations.large; easing.type: Easing.OutCubic }
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
        spacing: Tokens.spacing.large

        Section {
            Layout.fillWidth: true
            title: qsTr("Expiration & Display")
            description: qsTr("Auto-dismissal timers and fullscreen popup visibility")
            icon: "timer"
            accentColor: Colours.palette.m3secondary

            SettingRow {
                title: qsTr("Auto-expire")
                description: qsTr("Dismiss notifications automatically after a timeout")
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
                description: qsTr("How long a notification stays visible before expiring")
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
                description: qsTr("Allow notification popups to appear over fullscreen apps")
                StyledSwitch {
                    checked: (GlobalConfig.notifs.fullscreen || "on") === "on"
                    onToggled: {
                        GlobalConfig.notifs.fullscreen = checked ? "on" : "off";
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            Layout.fillWidth: true
            title: qsTr("Notification Grouping")
            description: qsTr("Stacking rules for multiple alerts from the same application")
            icon: "view_agenda"
            accentColor: Colours.palette.m3secondary

            SettingRow {
                title: qsTr("Group preview count")
                description: qsTr("Notifications shown before a group collapses")
                CustomSpinBox {
                    value: Config.notifs.groupPreviewNum || 3
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
}