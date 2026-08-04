import ".."
import "../components"
import QtQuick
import QtQuick.Layouts
import M3Shapes
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    property string activeSection: "clock"
    signal sectionSelected(string section)

    readonly property var sections: [
        { id: "clock", label: qsTr("Clock & Date"), icon: "schedule" },
        { id: "apps", label: qsTr("Default Apps"), icon: "apps" },
        { id: "media", label: qsTr("Media Controls"), icon: "play_circle" },
        { id: "advanced", label: qsTr("Advanced"), icon: "build" }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.small
        spacing: Tokens.spacing.extraSmall

        StyledText {
            text: qsTr("System Settings")
            font.weight: Font.DemiBold
            color: Colours.palette.m3onSurface
            textPointSize: Tokens.font.size.normal
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.padding.extraSmall
        }

        Repeater {
            model: root.sections

            delegate: Item {
                id: delegateRoot
                Layout.fillWidth: true
                implicitHeight: 40

                required property var modelData

                readonly property bool isActive: root.activeSection === delegateRoot.modelData.id

                scale: stateLayer.pressed ? 0.96 : 1.0
                Behavior on scale { SpringAnimation { spring: 4.2; damping: 0.70 } }

                StyledRect {
                    anchors.fill: parent
                    radius: height / 2
                    color: delegateRoot.isActive ? Colours.palette.m3primaryContainer : (stateLayer.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.08) : "transparent")

                    Behavior on color { CAnim {} }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.normal
                    anchors.rightMargin: Tokens.padding.normal
                    spacing: Tokens.spacing.normal

                    MaterialIcon {
                        text: delegateRoot.modelData.icon
                        color: delegateRoot.isActive ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                        iconPointSize: Tokens.font.size.normal
                        Behavior on color { CAnim {} }
                    }

                    StyledText {
                        text: delegateRoot.modelData.label
                        color: delegateRoot.isActive ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                        font.weight: delegateRoot.isActive ? Font.Medium : Font.Normal
                        textPointSize: Tokens.font.size.normal
                        Layout.fillWidth: true
                        Behavior on color { CAnim {} }
                    }
                }

                StateLayer {
                    id: stateLayer
                    anchors.fill: parent
                    radius: parent.height / 2
                    color: Colours.palette.m3onPrimaryContainer
                    onClicked: root.sectionSelected(delegateRoot.modelData.id)
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
