
import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../../components/controls"
import "../../../components/containers"
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.services

Item {
    id: root

    property string activeSection: "clock"
    signal sectionSelected(string section)

    readonly property var sections: [
        { id: "display", label: qsTr("Displays"), icon: "desktop_windows" },
        { id: "clock", label: qsTr("Clock & Date"), icon: "schedule" },
        { id: "keybinds", label: qsTr("Keybindings"), icon: "keyboard" },
        { id: "media", label: qsTr("Media Controls"), icon: "play_circle" },
        { id: "advanced", label: qsTr("Advanced"), icon: "build" }
    ]

    
    property Item hoveredItem: null

    Timer {
        id: clearHoverTimer
        interval: 75
        onTriggered: root.hoveredItem = null
    }

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

    // Sliding hover highlight marker
    StyledRect {
        id: hoverHighlightRect
        z: 0
        visible: opacity > 0.001
        opacity: (root.hoveredItem !== null && !root.hoveredItem.isActive) ? (root.hoveredItem.isPressed ? 0.12 : 0.08) : 0
        color: Colours.palette.m3onSurface
        radius: height / 2

        x: root.hoveredItem ? root.hoveredItem.mapToItem(root, 0, 0).x : x
        y: root.hoveredItem ? root.hoveredItem.mapToItem(root, 0, 0).y : y
        width: root.hoveredItem ? root.hoveredItem.width : width
        height: root.hoveredItem ? root.hoveredItem.height : height

        Behavior on x {
            enabled: hoverHighlightRect.opacity > 0
            SpringAnimation {
                spring: 7.0
                damping: 0.8
                mass: 1.0
                epsilon: 0.005
            }
        }
        Behavior on y {
            enabled: hoverHighlightRect.opacity > 0
            SpringAnimation {
                spring: 7.0
                damping: 0.8
                mass: 1.0
                epsilon: 0.005
            }
        }
        Behavior on width {
            enabled: hoverHighlightRect.opacity > 0
            SpringAnimation {
                spring: 7.0
                damping: 0.8
                mass: 1.0
                epsilon: 0.005
            }
        }
        Behavior on height {
            enabled: hoverHighlightRect.opacity > 0
            SpringAnimation {
                spring: 7.0
                damping: 0.8
                mass: 1.0
                epsilon: 0.005
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: 150 }
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
                Layout.fillWidth: true
                implicitHeight: 40

                required property var modelData

                readonly property bool isActive: root.activeSection === delegateRoot.modelData.id
                readonly property bool isPressed: segMa.pressed

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

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.large
                    anchors.rightMargin: Tokens.padding.large
                    spacing: Tokens.spacing.normal

                    MaterialIcon {
                        text: delegateRoot.modelData.icon
                        color: delegateRoot.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                        iconPointSize: Tokens.font.size.normal
                        Behavior on color { CAnim {} }
                    }

                    StyledText {
                        text: delegateRoot.modelData.label
                        color: delegateRoot.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                        font.weight: delegateRoot.isActive ? Font.Medium : Font.Normal
                        textPointSize: Tokens.font.size.normal
                        Layout.fillWidth: true
                        Behavior on color { CAnim {} }
                    }
                }

                MouseArea {
                    id: segMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        clearHoverTimer.stop();
                        root.hoveredItem = delegateRoot;
                    }
                    onExited: {
                        clearHoverTimer.restart();
                    }
                    onClicked: root.sectionSelected(delegateRoot.modelData.id)
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
