
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.settings

Item {
    id: root

    required property PopoutState popouts

    readonly property var activeMonitor: Brightness.getMonitor("active") ?? (Brightness.monitors.length > 0 ? Brightness.monitors[0] : null)
    readonly property bool hasBacklight: Boolean(activeMonitor && !isNaN(activeMonitor.brightness) && activeMonitor.brightness >= 0)

    implicitWidth: layout.implicitWidth + Tokens.padding.normal * 2
    implicitHeight: layout.implicitHeight + Tokens.padding.normal * 2

    ButtonGroup {
        id: sinks
    }

    ButtonGroup {
        id: sources
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.normal

        StyledText {
            text: qsTr("Output device")
            font.weight: 500
        }

        Repeater {
            model: Audio.sinks

            StyledRadioButton {
                id: control

                required property PwNode modelData

                ButtonGroup.group: sinks
                checked: Audio.sink?.id === modelData.id
                onClicked: Audio.setAudioSink(modelData)
                text: modelData.description
            }
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.smaller
            text: qsTr("Input device")
            font.weight: 500
        }

        Repeater {
            model: Audio.sources

            StyledRadioButton {
                required property PwNode modelData

                ButtonGroup.group: sources
                checked: Audio.source?.id === modelData.id
                onClicked: Audio.setAudioSource(modelData)
                text: modelData.description
            }
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.smaller
            Layout.bottomMargin: -Tokens.spacing.small / 2
            text: qsTr("Volume (%1)").arg(Audio.muted ? qsTr("Muted") : `${Math.round(Audio.volume * 100)}%`)
            font.weight: 500
        }

        CustomMouseArea {
            Layout.fillWidth: true
            implicitHeight: Tokens.padding.normal * 3

            onWheel: event => {
                if (event.angleDelta.y > 0)
                    Audio.incrementVolume();
                else if (event.angleDelta.y < 0)
                    Audio.decrementVolume();
            }

            StyledSlider {
                anchors.left: parent.left
                anchors.right: parent.right
                implicitHeight: parent.implicitHeight

                value: Audio.volume
                onMoved: Audio.setVolume(value)

                Behavior on value {
                    enabled: !pressed
                    Anim {}
                }
            }
        }

        StyledText {
            visible: root.hasBacklight
            Layout.topMargin: Tokens.spacing.smaller
            Layout.bottomMargin: -Tokens.spacing.small / 2
            text: qsTr("Brightness (%1)").arg(`${Math.round((root.activeMonitor?.brightness ?? 0) * 100)}%`)
            font.weight: 500
        }

        CustomMouseArea {
            visible: root.hasBacklight
            Layout.fillWidth: true
            implicitHeight: Tokens.padding.normal * 3

            onWheel: event => {
                if (!root.activeMonitor) return;
                if (event.angleDelta.y > 0)
                    root.activeMonitor.setBrightness(root.activeMonitor.brightness + 0.05);
                else if (event.angleDelta.y < 0)
                    root.activeMonitor.setBrightness(root.activeMonitor.brightness - 0.05);
            }

            StyledSlider {
                anchors.left: parent.left
                anchors.right: parent.right
                implicitHeight: parent.implicitHeight

                value: root.activeMonitor?.brightness ?? 0
                onMoved: {
                    if (root.activeMonitor)
                        root.activeMonitor.setBrightness(value);
                }

                Behavior on value {
                    enabled: !pressed
                    Anim {}
                }
            }
        }

        IconTextButton {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.normal
            inactiveColour: Colours.palette.m3primaryContainer
            inactiveOnColour: Colours.palette.m3onPrimaryContainer
            verticalPadding: Tokens.padding.small
            text: qsTr("Open settings")
            icon: "settings"

            onClicked: {
                root.popouts.hasCurrent = false;
                WindowFactory.create(null, {
                    active: "sound"
                });
            }
        }
    }
}
