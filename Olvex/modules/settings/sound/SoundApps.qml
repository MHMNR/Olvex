
import ".."
import "../chrome"
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
        spacing: Tokens.spacing.large

        Column {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: Audio.streams

                delegate: SettingRow {
                    required property var modelData
                    required property int index

                    title: Audio.getStreamName(modelData)
                    description: qsTr("Application output level")
                    icon: "apps"
                    divider: index < Audio.streams.length - 1
                    
                    StyledSlider {
                        width: 200
                        from: 0
                        to: Math.max(1, GlobalConfig.services.maxVolume || 1)
                        value: Audio.getStreamVolume(modelData)
                        onMoved: Audio.setStreamVolume(modelData, value)
                    }
                }
            }

            SettingRow {
                visible: Audio.streams.length === 0
                title: qsTr("No active apps")
                description: qsTr("App streams appear here while playing audio")
                divider: false
                icon: "info"
            }
        }
    }
}
