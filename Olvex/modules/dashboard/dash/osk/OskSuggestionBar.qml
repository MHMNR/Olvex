import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import Olvex.Config

Item {
    id: root

    property var engine: null  // OskWordEngine instance
    signal suggestionAccepted(string suffix)

    implicitHeight: (engine && engine.suggestions ? engine.suggestions.length : 0) > 0 ? 40 : 0
    implicitWidth: 400

    Behavior on implicitHeight {
        NumberAnimation { duration: 180; easing.type: Easing.OutQuart }
    }

    clip: true

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 8

        Repeater {
            model: engine ? engine.suggestions : []

            delegate: Rectangle {
                id: pill
                required property string modelData
                required property int index

                Layout.fillWidth: true
                height: 30
                radius: 15
                color: pillArea.pressed
                    ? Colours.palette.m3primary
                    : Qt.alpha(Colours.palette.m3onSurface, 0.08)

                Behavior on color { ColorAnimation { duration: 80 } }

                // Separator between pills
                Rectangle {
                    visible: pill.index < 2
                    anchors.right: parent.right
                    anchors.rightMargin: -4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 18
                    color: Qt.alpha(Colours.palette.m3onSurface, 0.12)
                }

                StyledText {
                    anchors.centerIn: parent
                    text: pill.modelData
                    font.pixelSize: 14
                    color: pillArea.pressed
                        ? Colours.palette.m3onPrimary
                        : Colours.palette.m3onSurface
                    Behavior on color { ColorAnimation { duration: 80 } }
                }

                MouseArea {
                    id: pillArea
                    anchors.fill: parent
                    onClicked: root.suggestionAccepted(pill.modelData)
                }
            }
        }
    }
}
