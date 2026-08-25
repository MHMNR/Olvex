
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

    readonly property var outputDevicesList: {
        const list = [];
        const sinks = Audio.detailedSinks && Audio.detailedSinks.length > 0 ? Audio.detailedSinks : [];

        if (sinks.length > 0) {
            for (const s of sinks) {
                const sinkName = s.name || "";
                const isDefaultSink = Audio.sink ? (Audio.sink.name === sinkName || sinkName.includes(Audio.sink.name) || Audio.sink.name.includes(sinkName)) : false;
                const activePort = s.active_port || "";
                const ports = s.ports || [];

                if (ports.length > 1) {
                    for (const p of ports) {
                        const portName = p.name || "";
                        const portDesc = p.description || portName;
                        let displayName = portDesc;
                        let icon = "speaker";

                        const pLower = portName.toLowerCase();
                        const dLower = portDesc.toLowerCase();

                        if (pLower.includes("speaker") || dLower.includes("speaker")) {
                            displayName = qsTr("Built-in Speaker");
                            icon = "speaker";
                        } else if (pLower.includes("headphone") || dLower.includes("headphone")) {
                            displayName = qsTr("Headphones / Wired Speaker");
                            icon = "headphones";
                        } else if (pLower.includes("hdmi") || dLower.includes("hdmi") || pLower.includes("displayport")) {
                            displayName = qsTr("HDMI / DisplayPort Audio");
                            icon = "tv";
                        } else if (pLower.includes("lineout") || dLower.includes("line")) {
                            displayName = qsTr("Line Out");
                            icon = "speaker";
                        }

                        const isActive = isDefaultSink && (activePort === portName);
                        list.push({
                            id: sinkName + ":" + portName,
                            name: displayName,
                            description: s.description || sinkName,
                            icon: icon,
                            active: isActive,
                            sinkName: sinkName,
                            portName: portName,
                            available: p.availability !== "not available"
                        });
                    }
                } else {
                    let icon = "speaker";
                    const sLower = (s.description || sinkName).toLowerCase();
                    if (sLower.includes("bluez") || sLower.includes("bluetooth"))
                        icon = "bluetooth_audio";
                    else if (sLower.includes("headphone") || sLower.includes("headset") || sLower.includes("buds"))
                        icon = "headphones";
                    else if (sLower.includes("hdmi") || sLower.includes("tv"))
                        icon = "tv";
                    else if (sLower.includes("usb"))
                        icon = "usb";

                    list.push({
                        id: sinkName,
                        name: s.description || sinkName,
                        description: sLower.includes("bluez") ? qsTr("Bluetooth Audio") : (sLower.includes("usb") ? qsTr("USB Audio") : qsTr("Audio Output")),
                        icon: icon,
                        active: isDefaultSink,
                        sinkName: sinkName,
                        portName: "",
                        available: true
                    });
                }
            }
        }

        // Fallback to Pipewire sinks if pactl query is still loading
        if (list.length === 0 && Audio.sinks.length > 0) {
            for (const s of Audio.sinks) {
                list.push({
                    id: s.id || s.name,
                    name: s.description || s.name || qsTr("Output"),
                    description: qsTr("Audio Output"),
                    icon: root.deviceIcon(s),
                    active: Audio.sink && Audio.sink.id === s.id,
                    sinkName: s.name,
                    portName: "",
                    available: true,
                    node: s
                });
            }
        }

        return list;
    }

    opacity: 0
    y: 10
    Component.onCompleted: {
        cascadeIn.start();
        Audio.refreshDetailedDevices();
    }
    
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
                model: root.outputDevicesList

                delegate: DeviceRow {
                    required property var modelData

                    name: modelData.name
                    status: modelData.active ? qsTr("Active") : (modelData.description || qsTr("Available"))
                    icon: modelData.icon
                    active: modelData.active
                    onClicked: {
                        if (modelData.node)
                            Audio.setAudioSink(modelData.node);
                        else
                            Audio.setAudioOutputPort(modelData.sinkName, modelData.portName);
                    }
                }
            }
        }
    }
}
