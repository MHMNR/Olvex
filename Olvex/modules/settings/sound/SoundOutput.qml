
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
    
    function deviceIcon(node): string {
        if (!node)
            return "speaker";
        const n = (node.description || node.name || "").toLowerCase();
        if (n.includes("headphone") || n.includes("headset"))
            return "headphones";
        if (n.includes("hdmi") || n.includes("display"))
            return "tv";
        if (n.includes("bluez") || n.includes("bluetooth"))
            return "bluetooth_audio";
        if (n.includes("mic"))
            return "mic";
        return "speaker";
    }

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

        SettingRow {
            Layout.fillWidth: true
            title: qsTr("Volume")
            description: qsTr("Master output level and mute")
            icon: "volume_up"
            divider: true
            
            Row {
                spacing: Tokens.spacing.normal
                StyledSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: !Audio.muted
                    onToggled: {
                        if (Audio.sink?.audio)
                            Audio.sink.audio.muted = !checked;
                    }
                }
                StyledSlider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 200
                    from: 0
                    to: Math.max(1, GlobalConfig.services.maxVolume || 1)
                    value: Audio.volume
                    onMoved: Audio.setVolume(value)
                }
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: Audio.sinks

                delegate: DeviceRow {
                    required property var modelData

                    name: modelData.description || modelData.name || qsTr("Output")
                    icon: root.deviceIcon(modelData)
                    active: Audio.sink && Audio.sink.id === modelData.id
                    status: active ? qsTr("Active") : qsTr("Available")
                    onClicked: Audio.setAudioSink(modelData)
                }
            }
        }
    }
}
