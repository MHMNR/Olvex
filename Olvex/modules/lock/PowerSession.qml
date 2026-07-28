import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.services

ColumnLayout {
    id: root

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 12
    spacing: 25

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.padding.large

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Power Session")
            color: Colours.palette.m3outline
            font.family: Tokens.font.family.mono
            font.weight: 500
        }

    }

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.padding.large
        spacing: 0

        Item { Layout.fillWidth: true }
        
        RowLayout {
            spacing: Tokens.spacing.normal
            Repeater {
                model: [
                    { icon: "refresh",             label: "REBOOT", cmd: "systemctl reboot",   hue: "Secondary" },
                    { icon: "power_settings_new",  label: "OFF",    cmd: "systemctl poweroff", hue: "Error"     },
                    { icon: "bedtime",             label: "SLEEP",  cmd: "systemctl suspend",  hue: "Tertiary"  },
                    { icon: "logout",              label: "EXIT",   cmd: "hyprctl dispatch exit", hue: "Primary" }
                ]

                delegate: SessionButton {
                    icon:  modelData.icon
                    label: modelData.label
                    cmd:   modelData.cmd
                    hue:   modelData.hue
                }
            }
        }

        Item { Layout.fillWidth: true }
    }

    component SessionButton: ColumnLayout {
        id: btn

        property string icon
        property string label
        property string cmd
        property string hue: "Primary"

        Layout.fillWidth: true
        spacing: Tokens.spacing.smaller

        Item {
            id: container
            Layout.alignment: Qt.AlignHCenter
            
            implicitWidth:  measureIcon.implicitWidth  + Tokens.padding.large * 2
            implicitHeight: measureIcon.implicitHeight + Tokens.padding.normal * 2

            MaterialIcon {
                id: measureIcon
                text: btn.icon
                font.pointSize: Tokens.font.size.large
                visible: false
            }

            StyledRect {
                anchors.centerIn: parent
                
                width:  container.implicitWidth  * (btnState.pressed ? 0.9 : btnState.containsMouse ? 1.15 : 1)
                height: container.implicitHeight * (btnState.pressed ? 0.9 : btnState.containsMouse ? 1.15 : 1)

                // m3 palette uses lowercase for the base color (e.g., m3primary, not m3Primary)
                color: btnState.containsMouse ? Qt.lighter(Colours.palette[`m3${btn.hue.toLowerCase()}`], 1.2) : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
                radius: height / 2

                Behavior on width  { Anim { type: Anim.FastSpatial } }
                Behavior on height { Anim { type: Anim.FastSpatial } }
                Behavior on color  { CAnim {} }

                StateLayer {
                    id: btnState
                    hoverEnabled: true
                    // Prevent the state layer from muddying the bright background on hover
                    color: containsMouse ? "transparent" : (Colours.palette[`m3on${btn.hue}`] ?? Colours.palette.m3onSurface)
                    onClicked: {
                        // fire-and-forget via shell process
                        Qt.callLater(() => {
                            const proc = Qt.createQmlObject(
                                `import Quickshell.Io; Process { command: ["sh", "-c", "${btn.cmd}"]; running: true }`,
                                btn, "proc"
                            );
                        });
                    }
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: btn.icon
                // m3on colors use camelCase (e.g., m3onPrimary)
                color: btnState.containsMouse ? Colours.palette[`m3on${btn.hue}`] : Colours.palette.m3onSurfaceVariant
                
                // Animate font size directly instead of scaling to prevent pixelation (faita jaoa)
                font.pointSize: Tokens.font.size.large * (btnState.pressed ? 0.9 : btnState.containsMouse ? 1.15 : 1)

                Behavior on font.pointSize { Anim { type: Anim.FastSpatial } }
                Behavior on color { CAnim {} }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: btn.label
            color: Colours.palette.m3outline
            font.family: Tokens.font.family.mono
            font.pointSize: Tokens.font.size.smaller
        }
    }
}
