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

    property string activeSection: "output"
    signal sectionSelected(string section)

    readonly property var sections: [
        { id: "output", label: qsTr("Output Devices"), icon: "volume_up" },
        { id: "input", label: qsTr("Input Devices"), icon: "mic" },
        { id: "apps", label: qsTr("App Streams"), icon: "equalizer" },
        { id: "behavior", label: qsTr("Sound Behavior"), icon: "tune" }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.small
        spacing: Tokens.spacing.extraSmall

        StyledText {
            text: qsTr("Sound & Audio")
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
