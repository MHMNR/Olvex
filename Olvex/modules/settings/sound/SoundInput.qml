
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
    
    readonly property var inputDevicesList: {
        const list = [];
        const sources = Audio.detailedSources && Audio.detailedSources.length > 0 ? Audio.detailedSources : [];

        if (sources.length > 0) {
            for (const s of sources) {
                const sourceName = s.name || "";
                if (sourceName.endsWith(".monitor"))
                    continue;

                const isDefaultSource = Audio.source ? (Audio.source.name === sourceName || sourceName.includes(Audio.source.name) || Audio.source.name.includes(sourceName)) : false;
                const activePort = s.active_port || "";
                const ports = s.ports || [];

                if (ports.length > 1) {
                    for (const p of ports) {
                        const portName = p.name || "";
                        const portDesc = p.description || portName;
                        let displayName = portDesc;
                        let icon = "mic";

                        const pLower = portName.toLowerCase();
                        const dLower = portDesc.toLowerCase();

                        if (pLower.includes("internal") || dLower.includes("internal") || (pLower.includes("mic") && !pLower.includes("headset"))) {
                            displayName = qsTr("Built-in Microphone");
                            icon = "mic";
                        } else if (pLower.includes("headset") || dLower.includes("headset") || pLower.includes("headphone")) {
                            displayName = qsTr("Headset / Wired Microphone");
                            icon = "headset_mic";
                        }

                        const isActive = isDefaultSource && (activePort === portName);
                        list.push({
                            id: sourceName + ":" + portName,
                            name: displayName,
                            description: s.description || sourceName,
                            icon: icon,
                            active: isActive,
                            sourceName: sourceName,
                            portName: portName,
                            available: p.availability !== "not available"
                        });
                    }
                } else {
                    let icon = "mic";
                    const sLower = (s.description || sourceName).toLowerCase();
                    if (sLower.includes("webcam") || sLower.includes("uvc") || sLower.includes("camera"))
                        icon = "videocam";
                    else if (sLower.includes("bluez") || sLower.includes("bluetooth"))
                        icon = "bluetooth_audio";
                    else if (sLower.includes("headset"))
                        icon = "headset_mic";

                    list.push({
                        id: sourceName,
                        name: s.description || sourceName,
                        description: sLower.includes("webcam") ? qsTr("Webcam Microphone") : (sLower.includes("usb") ? qsTr("USB Audio Input") : qsTr("Audio Input")),
                        icon: icon,
                        active: isDefaultSource,
                        sourceName: sourceName,
                        portName: "",
                        available: true
                    });
                }
            }
        }

        // Fallback to Pipewire sources if pactl json is empty or loading
        if (list.length === 0 && Audio.sources.length > 0) {
            for (const s of Audio.sources) {
                list.push({
                    id: s.id || s.name,
                    name: s.description || s.name || qsTr("Input"),
                    description: qsTr("Audio Input"),
                    icon: "mic",
                    active: Audio.source && Audio.source.id === s.id,
                    sourceName: s.name,
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
            title: qsTr("Microphone")
            description: qsTr("Master input level and mute")
            icon: "mic"
            divider: true
            
            Row {
                spacing: Tokens.spacing.normal
                StyledSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: !Audio.sourceMuted
                    onToggled: {
                        if (Audio.source?.audio)
                            Audio.source.audio.muted = !checked;
                    }
                }
                StyledSlider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 200
                    from: 0
                    to: Math.max(1, GlobalConfig.services.maxVolume || 1)
                    value: Audio.sourceVolume
                    onMoved: Audio.setSourceVolume(value)
                }
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: root.inputDevicesList

                delegate: DeviceRow {
                    required property var modelData

                    name: modelData.name
                    status: modelData.active ? qsTr("Active") : (modelData.description || qsTr("Available"))
                    icon: modelData.icon
                    active: modelData.active
                    onClicked: {
                        if (modelData.node)
                            Audio.setAudioSource(modelData.node);
                        else
                            Audio.setAudioInputPort(modelData.sourceName, modelData.portName);
                    }
                }
            }
        }
    }
}
