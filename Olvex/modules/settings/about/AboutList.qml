
import ".."
import "../components"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.controls

Item {
    id: root

    property string activeSection: "hero"
    signal sectionSelected(string section)

    readonly property var sections: [
        { id: "hero", label: qsTr("About Olvex"), icon: "info" },
        { id: "system", label: qsTr("System Info"), icon: "monitor_heart" },
        { id: "resources", label: qsTr("Resources"), icon: "link" }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.normal
        spacing: Tokens.spacing.small

        StyledText {
            text: qsTr("About Settings")
            font.pointSize: Tokens.font.size.large
            font.weight: 700
            font.letterSpacing: -0.25
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.padding.normal
        }

        Repeater {
            model: root.sections

            delegate: Item {
                id: delegateRoot
                Layout.fillWidth: true
                implicitHeight: 48
                
                required property var modelData
                
                readonly property bool isActive: root.activeSection === delegateRoot.modelData.id

                scale: stateLayer.pressed ? 0.96 : 1.0
                Behavior on scale { SpringAnimation { spring: 5.0; damping: 0.65 } }

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height * 0.6
                    width: 4
                    radius: width / 2
                    color: Colours.palette.m3tertiary
                    opacity: delegateRoot.isActive ? 1.0 : 0.0
                    
                    Behavior on opacity { CAnim { duration: Tokens.anim.durations.normal } }
                    Behavior on height { SpringAnimation { spring: 5.0; damping: 0.7 } }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.normal + 8
                    anchors.rightMargin: Tokens.padding.normal
                    spacing: Tokens.spacing.normal

                    MaterialIcon {
                        text: delegateRoot.modelData.icon
                        color: delegateRoot.isActive ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
                        Behavior on color { CAnim { duration: Tokens.anim.durations.normal } }
                    }

                    StyledText {
                        text: delegateRoot.modelData.label
                        color: delegateRoot.isActive ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                        font.weight: delegateRoot.isActive ? 600 : 400
                        Layout.fillWidth: true
                        Behavior on color { CAnim { duration: Tokens.anim.durations.normal } }
                    }
                }

                StateLayer {
                    id: stateLayer
                    radius: Tokens.rounding.normal
                    color: delegateRoot.isActive ? Colours.palette.m3tertiaryContainer : Colours.palette.m3onSurfaceVariant
                    onClicked: root.sectionSelected(delegateRoot.modelData.id)
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
