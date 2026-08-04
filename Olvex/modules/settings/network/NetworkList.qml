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

    property string activeSection: "wifi"
    signal sectionSelected(string section)

    readonly property var sections: [
        { id: "wifi", label: qsTr("Wi-Fi"), icon: "wifi" },
        { id: "bluetooth", label: qsTr("Bluetooth"), icon: "bluetooth" }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.small
        spacing: Tokens.spacing.small

        StyledText {
            text: qsTr("Network Settings")
            font.weight: Font.DemiBold
            color: Colours.palette.m3onSurface
            textPointSize: Tokens.font.size.normal
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.padding.small
        }

        Repeater {
            model: root.sections

            delegate: Item {
                id: delegateRoot

                required property var modelData

                readonly property bool isActive: root.activeSection === delegateRoot.modelData.id

                Layout.fillWidth: true
                implicitHeight: 44

                scale: stateLayer.pressed ? 0.96 : 1.0
                Behavior on scale {
                    SpringAnimation { spring: 4.2; damping: 0.70 }
                }

                StyledRect {
                    anchors.fill: parent
                    radius: height / 2
                    color: delegateRoot.isActive ? Colours.palette.m3primary : (stateLayer.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.08) : "transparent")

                    Behavior on color {
                        CAnim {}
                    }
                }

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
                        color: delegateRoot.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        font.weight: delegateRoot.isActive ? Font.Medium : Font.Normal
                        textPointSize: Tokens.font.size.normal
                        Layout.fillWidth: true

                        Behavior on color {
                            CAnim {}
                        }
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

        Item { Layout.fillHeight: true }
    }
}
