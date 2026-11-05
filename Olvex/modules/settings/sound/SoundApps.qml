
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

        Section {
            Layout.fillWidth: true
            title: qsTr("Application Streams")
            description: qsTr("Per-application volume controls and stream balance")
            icon: "equalizer"
            accentColor: Colours.palette.m3secondary

            Repeater {
                model: Audio.streams

                delegate: SettingRow {
                    id: appRow
                    required property var modelData
                    required property int index

                    title: Audio.getStreamName(modelData)
                    description: qsTr("Volume: %1%").arg(Math.round(Audio.getStreamVolume(modelData) * 100))

                    StyledSlider {
                        width: 200
                        from: 0
                        to: Math.max(1, GlobalConfig.services.maxVolume || 1)
                        value: Audio.getStreamVolume(modelData)
                        valueAsPercent: true
                        onMoved: Audio.setStreamVolume(modelData, value)
                    }
                }
            }

            SettingRow {
                visible: Audio.streams.length === 0
                title: qsTr("No active audio streams")
                description: qsTr("Applications playing sound will appear here automatically")
            }
        }
    }
}