import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property real nonAnimWidth
    required property DashboardState dashState
    required property var tabs

    implicitHeight: 80

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 20

        Repeater {
            model: root.tabs

            delegate: Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                readonly property bool isCurrent: root.dashState.currentTab === index

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.iconName
                        color: isCurrent ? Colours.palette.m3primary : Qt.alpha("#ffffff", 0.6)
                        font.pointSize: 22
                        fill: isCurrent ? 1 : 0
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.text
                        color: isCurrent ? "#ffffff" : Qt.alpha("#ffffff", 0.4)
                        font.pointSize: 12
                        font.weight: isCurrent ? 600 : 400
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }

                // Selection Indicator (Glow line)
                StyledRect {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: isCurrent ? 40 : 0
                    height: 3
                    radius: 2
                    color: Colours.palette.m3primary
                    visible: isCurrent
                    
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.dashState.currentTab = index
                }
            }
        }
    }

    // Bottom Separator
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Qt.alpha("#ffffff", 0.1)
    }
}
