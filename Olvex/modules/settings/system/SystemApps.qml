
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
    property var appJoin
    property var appSplit
    
    opacity: 0
    y: 10
    Component.onCompleted: cascadeIn.start()
    
    ParallelAnimation {
        id: cascadeIn
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens.anim.durations.slow; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: Tokens.anim.durations.slow; easing.type: Easing.OutCubic }
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
            title: qsTr("Terminal")
            description: qsTr("Command used to open a terminal")
            icon: "terminal"
            divider: true
            StyledTextField {
                width: 240
                text: root.appJoin(GlobalConfig.general.apps.terminal)
                onEditingFinished: {
                    GlobalConfig.general.apps.terminal = root.appSplit(text);
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Audio mixer")
            description: qsTr("App opened from the volume controls")
            icon: "tune"
            divider: true
            StyledTextField {
                width: 240
                text: root.appJoin(GlobalConfig.general.apps.audio)
                onEditingFinished: {
                    GlobalConfig.general.apps.audio = root.appSplit(text);
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Media player")
            description: qsTr("App used for playback actions")
            icon: "movie"
            divider: true
            StyledTextField {
                width: 240
                text: root.appJoin(GlobalConfig.general.apps.playback)
                onEditingFinished: {
                    GlobalConfig.general.apps.playback = root.appSplit(text);
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("File manager")
            description: qsTr("App opened to browse files")
            icon: "folder"
            divider: false
            StyledTextField {
                width: 240
                text: root.appJoin(GlobalConfig.general.apps.explorer)
                onEditingFinished: {
                    GlobalConfig.general.apps.explorer = root.appSplit(text);
                    GlobalConfig.save();
                }
            }
        }
    }
}
