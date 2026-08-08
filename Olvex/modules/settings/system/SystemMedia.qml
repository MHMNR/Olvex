
import ".."
import "../chrome"
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
    property var idxOf
    
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
            title: qsTr("Default player")
            description: qsTr("Preferred source when several are playing")
            divider: true
            OptionPicker {
                id: playerPicker
                model: ["Spotify", "mpv", "firefox", "vlc", "auto"]
                currentIndex: root.idxOf(playerPicker.model, GlobalConfig.services.defaultPlayer || "Spotify")
                onSelected: i => {
                    GlobalConfig.services.defaultPlayer = playerPicker.model[i];
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Show lyrics")
            description: qsTr("Display synced lyrics when available")
            divider: false
            StyledSwitch {
                checked: GlobalConfig.services.showLyrics ?? true
                onToggled: {
                    GlobalConfig.services.showLyrics = checked;
                    GlobalConfig.save();
                }
            }
        }
    }
}
