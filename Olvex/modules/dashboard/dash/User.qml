import QtQuick
import QtQuick.Layouts
import qs.components
import qs.components.effects
import qs.components.filedialog
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    required property DrawerVisibilities visibilities
    required property FileDialog facePicker
    readonly property color accentColor: Colours.palette.m3primary
    readonly property color textColor: "#fff4fb"

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 16

        // Avatar
        StyledClippingRect {
            Layout.preferredWidth: 54
            Layout.preferredHeight: 54
            radius: 16
            color: Qt.rgba(0.95, 0.63, 0.86, 0.16)
            border.color: Qt.alpha(root.accentColor, 0.24)
            border.width: 1

            CachingImage {
                id: pfp
                anchors.fill: parent
                path: `${Paths.home}/.face`
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: pfp.status !== Image.Ready
                text: "person"
                color: root.textColor
                fill: 1
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.visibilities.launcher = false;
                    root.facePicker.open();
                }
            }
        }

        // Pill Layout & Uptime
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 10

            RowLayout {
                Layout.alignment: Qt.AlignLeft
                Layout.fillWidth: true
                spacing: 8

                Pill {
                    text: SysInfo.osPrettyName || SysInfo.osName
                    pillColor: Colours.palette.m3primary
                }

                Pill {
                    text: SysInfo.wm
                    pillColor: Colours.palette.m3secondary
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignLeft
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: `Uptime: ${SysInfo.uptime}`
                color: Qt.alpha("#ffffff", 0.9)
                font.weight: 600
            }
        }
    }

    component Pill: Rectangle {
        id: pill
        required property string text
        required property color pillColor

        implicitWidth: pillText.implicitWidth + 20
        implicitHeight: 24
        radius: 12
        color: pill.pillColor
        
        Text {
            id: pillText
            anchors.centerIn: parent
            text: pill.text
            color: "#1a1a1a" // Dark text for readability on bright background
            font.pixelSize: 11
            font.weight: Font.Bold
        }
    }
}
