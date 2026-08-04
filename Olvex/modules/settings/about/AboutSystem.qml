
import ".."
import "../chrome"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

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
            title: qsTr("Distribution")
            description: qsTr("Operating system in use")
            divider: true
            StyledText {
                text: SysInfo.osPrettyName || SysInfo.osName || qsTr("Linux")
                color: Colours.palette.m3tertiary
                font.weight: Font.Normal
                font.letterSpacing: 0.05
                textPointSize: Tokens.font.size.normal
            }
        }
        
        SettingRow {
            title: qsTr("Compositor")
            description: qsTr("Wayland compositor")
            divider: true
            StyledText {
                text: SysInfo.wm || "Hyprland"
                color: Colours.palette.m3tertiary
                font.weight: Font.Normal
                font.letterSpacing: 0.05
                textPointSize: Tokens.font.size.normal
            }
        }
        
        SettingRow {
            title: qsTr("Uptime")
            description: qsTr("Time since last boot")
            divider: true
            StyledText {
                text: SysInfo.uptime || qsTr("—")
                color: Colours.palette.m3tertiary
                font.weight: Font.Normal
                font.letterSpacing: 0.05
                textPointSize: Tokens.font.size.normal
            }
        }
        
        SettingRow {
            title: qsTr("Shell framework")
            description: qsTr("What Olvex is built on")
            divider: false
            StyledText {
                text: "Quickshell · Qt 6"
                color: Colours.palette.m3tertiary
                font.weight: Font.Normal
                font.letterSpacing: 0.05
                textPointSize: Tokens.font.size.normal
            }
        }
    }
}
