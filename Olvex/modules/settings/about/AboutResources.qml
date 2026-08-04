
import ".."
import "../chrome"
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.components.controls
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
            title: qsTr("Repository")
            description: qsTr("Source code and releases on GitHub")
            clickable: true
            divider: true
            MaterialIcon {
                text: "open_in_new"
                color: Colours.palette.m3onSurfaceVariant
                iconPointSize: Tokens.font.size.large
            }
            onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/olvex-dots/shell"])
        }
        
        SettingRow {
            title: qsTr("Open config folder")
            description: qsTr("shell.json and shell-tokens.json")
            clickable: true
            divider: false
            MaterialIcon {
                text: "folder_open"
                color: Colours.palette.m3onSurfaceVariant
                iconPointSize: Tokens.font.size.large
            }
            onClicked: Quickshell.execDetached(["xdg-open", Paths.config])
        }
    }
}
