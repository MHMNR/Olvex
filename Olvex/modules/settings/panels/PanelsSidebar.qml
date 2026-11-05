
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
            title: qsTr("Sidebar & Notification Center")
            description: qsTr("Flyout sidebar reveal triggers and swipe distances")
            icon: "dock_to_left"
            accentColor: Colours.palette.m3secondary

            SettingRow {
                title: qsTr("Enable sidebar")
                description: qsTr("Allow opening the lateral notification and control sidebar")
                StyledSwitch {
                    checked: (Config.notificationcenter.enabled !== undefined) ? Config.notificationcenter.enabled : true
                    onToggled: {
                        GlobalConfig.notificationcenter.enabled = checked;
                        GlobalConfig.save();
                    }
                }
            }
            
            SettingRow {
                title: qsTr("Drag threshold (px)")
                description: qsTr("Screen edge drag distance required to trigger opening the sidebar")
                CustomSpinBox {
                    value: Config.notificationcenter.dragThreshold || 80
                    min: 5
                    max: 100
                    step: 5
                    onValueModified: v => {
                        GlobalConfig.notificationcenter.dragThreshold = v;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }
}