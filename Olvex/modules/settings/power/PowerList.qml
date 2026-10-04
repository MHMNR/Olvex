

import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Olvex.Config
import qs.services

Item {
    id: root

    property string activeSection: "battery"
    signal sectionSelected(string section)

    readonly property bool hasBattery: UPower.displayDevice && UPower.displayDevice.isPresent
    property bool hasLidSwitch: false

    Process {
        command: ["sh", "-c", "test -d /proc/acpi/button/lid || grep -qi 'lid' /proc/bus/input/devices 2>/dev/null"]
        running: true
        onExited: exitCode => {
            root.hasLidSwitch = (exitCode === 0);
        }
    }

    readonly property var sections: [
        { id: "battery", label: root.hasBattery ? qsTr("Battery & Power") : qsTr("Power & Performance"), icon: root.hasBattery ? "battery_charging_full" : "bolt" },
        { id: "idle", label: qsTr("Idle & Sleep"), icon: "bedtime" },
        { id: "behavior", label: root.hasLidSwitch ? qsTr("Lid & Buttons") : qsTr("Hardware Buttons"), icon: "power_settings_new" }
    ]

    
    StyledRect {
        id: highlightRect
        x: colLayout.x + Tokens.padding.small
        width: colLayout.width - (Tokens.padding.small * 2)
        height: 40
        radius: height / 2
        color: Colours.palette.m3primary
        
        Behavior on y {
            Anim { type: Anim.FastSpatial }
        }
    }

    ColumnLayout {
        id: colLayout
        anchors.fill: parent
        anchors.margins: Tokens.padding.small
        spacing: Tokens.spacing.extraSmall

        Repeater {
            model: root.sections

            delegate: Item {
                id: delegateRoot

                required property var modelData

                readonly property bool isActive: root.activeSection === delegateRoot.modelData.id

                onIsActiveChanged: {
                    if (isActive) {
                        highlightRect.y = Qt.binding(() => colLayout.y + delegateRoot.y);
                    }
                }
                Component.onCompleted: {
                    if (isActive) {
                        highlightRect.y = Qt.binding(() => colLayout.y + delegateRoot.y);
                    }
                }


                Layout.fillWidth: true
                implicitHeight: 40

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.large
                    anchors.rightMargin: Tokens.padding.large
                    spacing: Tokens.spacing.normal

                    MaterialIcon {
                        text: delegateRoot.modelData.icon
                        color: delegateRoot.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                        iconPointSize: Tokens.font.size.normal

                        Behavior on color {
                            CAnim {}
                        }
                    }

                    StyledText {
                        text: delegateRoot.modelData.label
                        color: delegateRoot.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                        font.weight: delegateRoot.isActive ? Font.Medium : Font.Normal
                        textPointSize: Tokens.font.size.normal
                        Layout.fillWidth: true

                        Behavior on color {
                            CAnim {}
                        }
                    }
                }
                StyledRect {
                    anchors.fill: parent
                    radius: height / 2
                    color: Colours.palette.m3onSurface
                    opacity: segMa.pressed ? 0.1 : (segMa.containsMouse && !delegateRoot.isActive ? 0.08 : 0)

                    Behavior on opacity {
                        Anim { type: Anim.FastEffects }
                    }
                }

                MouseArea {
                    id: segMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.sectionSelected(delegateRoot.modelData.id)
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
