import QtQuick
import QtQuick.Layouts
import Quickshell
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
        Layout.topMargin: Tokens?.padding?.large ?? 16

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Power Session")
            color: Colours.palette.m3outline
            font.family: Tokens?.font?.family?.mono ?? "monospace"
            font.weight: 500
        }

    }

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens?.padding?.large ?? 16
        spacing: 0

        Item { Layout.fillWidth: true }
        
        RowLayout {
            spacing: Tokens?.spacing?.normal ?? 8
            Repeater {
                model: [
                    { icon: Config.powermenu.icons.reboot || "refresh",                               label: qsTr("REBOOT"), cmd: Config.powermenu.commands.reboot || ["systemctl", "reboot"],   hue: "Secondary" },
                    { icon: Config.powermenu.icons.shutdown || "power_settings_new",                 label: qsTr("OFF"),    cmd: Config.powermenu.commands.shutdown || ["systemctl", "poweroff"], hue: "Error"     },
                    { icon: Config.powermenu.icons.suspend || Config.powermenu.icons.hibernate || "bedtime", label: qsTr("SLEEP"),  cmd: Config.powermenu.commands.suspend || ["systemctl", "suspend"],  hue: "Tertiary"  },
                    { icon: Config.powermenu.icons.logout || "logout",                               label: qsTr("LOGOUT"), cmd: Config.powermenu.commands.logout || ["loginctl", "terminate-user", ""], hue: "Primary" }
                ]

                delegate: SessionButton {
                    icon:    modelData.icon
                    label:   modelData.label
                    command: modelData.cmd
                    hue:     modelData.hue
                }
            }
        }

        Item { Layout.fillWidth: true }
    }

    component SessionButton: ColumnLayout {
        id: btn

        property string icon
        property string label
        property var command
        property string hue: "Primary"

        Layout.fillWidth: true
        spacing: Tokens?.spacing?.smaller ?? 4

        Item {
            id: container
            Layout.alignment: Qt.AlignHCenter
            
            implicitWidth:  measureIcon.implicitWidth  + (Tokens?.padding?.large ?? 16) * 2
            implicitHeight: measureIcon.implicitHeight + (Tokens?.padding?.normal ?? 8) * 2

            MaterialIcon {
                id: measureIcon
                text: btn.icon
                iconPointSize: Tokens?.font?.size?.large ?? 16
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
                        if (Array.isArray(btn.command)) {
                            Quickshell.execDetached(btn.command);
                        } else if (typeof btn.command === "string") {
                            Qt.callLater(() => {
                                const proc = Qt.createQmlObject(
                                    `import Quickshell.Io; Process { command: ["sh", "-c", "${btn.command}"]; running: true }`,
                                    btn, "proc"
                                );
                            });
                        } else {
                            Quickshell.execDetached(btn.command);
                        }
                    }
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: btn.icon
                // m3on colors use camelCase (e.g., m3onPrimary)
                color: btnState.containsMouse ? Colours.palette[`m3on${btn.hue}`] : Colours.palette.m3onSurfaceVariant
                
                // Animate font size directly instead of scaling to prevent pixelation (faita jaoa)
                iconPointSize: (Tokens?.font?.size?.large ?? 16) * (btnState.pressed ? 0.9 : btnState.containsMouse ? 1.15 : 1)

                Behavior on iconPointSize { Anim { type: Anim.FastSpatial } }
                Behavior on color { CAnim {} }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: btn.label
            color: Colours.palette.m3outline
            font.family: Tokens?.font?.family?.mono ?? "monospace"
            textPointSize: Tokens?.font?.size?.smaller ?? 11
        }
    }
}
