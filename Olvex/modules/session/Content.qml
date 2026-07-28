pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Olvex.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property DrawerVisibilities visibilities

    property real totalWeight: shutdownBtn.weight + rebootBtn.weight + hibernateBtn.weight + logoutBtn.weight

    focus: true
    Keys.onEscapePressed: root.visibilities.session = false
    Component.onCompleted: root.forceActiveFocus()

    // Background handled by system blur / ContentWindow scrim
    MouseArea {
        anchors.fill: parent
        onClicked: root.visibilities.session = false
    }

    // Main Content Canvas
    Row {
        id: mainRow
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 40
        anchors.bottomMargin: 40

        SessionColumn {
            id: shutdownBtn
            width: (mainRow.width / root.totalWeight) * weight
            icon: Config.session.icons.shutdown
            label: "POWER OFF"
            command: Config.session.commands.shutdown
            hue: "Error"
            KeyNavigation.right: rebootBtn
        }

        SessionColumn {
            id: rebootBtn
            width: (mainRow.width / root.totalWeight) * weight
            icon: Config.session.icons.reboot
            label: "REBOOT"
            command: Config.session.commands.reboot
            hue: "Secondary"
            KeyNavigation.left: shutdownBtn
            KeyNavigation.right: hibernateBtn
        }

        SessionColumn {
            id: hibernateBtn
            width: (mainRow.width / root.totalWeight) * weight
            icon: Config.session.icons.hibernate
            label: "SLEEP"
            command: Config.session.commands.hibernate
            hue: "Primary"
            KeyNavigation.left: rebootBtn
            KeyNavigation.right: logoutBtn
        }

        SessionColumn {
            id: logoutBtn
            width: (mainRow.width / root.totalWeight) * weight
            icon: Config.session.icons.logout
            label: "LOGOUT"
            command: Config.session.commands.logout
            hue: "Tertiary"
            borderVisible: false
            KeyNavigation.left: hibernateBtn
        }
    }

    component SessionColumn: Item {
        id: col

        required property string icon
        required property list<string> command
        required property string label
        required property string hue
        property bool borderVisible: true
        
        property bool isHovered: mouseArea.containsMouse || col.activeFocus
        property real weight: isHovered ? 1.5 : 1.0
        
        Behavior on weight {
            NumberAnimation { duration: 700; easing.type: Easing.OutQuad } // Tailwind duration-700 ease-out
        }

        height: mainRow.height
        clip: true

        // Separator Line (border-r border-white/5)
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: Qt.rgba(1, 1, 1, 0.05)
            visible: col.borderVisible
        }

        // Radial Mesh Glow
        Shape {
            anchors.centerIn: parent
            width: 800
            height: 800
            opacity: col.isHovered ? 1 : 0
            
            ShapePath {
                strokeWidth: 0
                fillGradient: RadialGradient {
                    centerX: 400; centerY: 400
                    centerRadius: 400
                    focalX: 400; focalY: 400
                    GradientStop { position: 0.0; color: Qt.alpha(Colours.palette[`m3${col.hue.toLowerCase()}`], 0.4) }
                    GradientStop { position: 0.7; color: "transparent" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                startX: 0; startY: 0
                PathLine { x: 800; y: 0 }
                PathLine { x: 800; y: 800 }
                PathLine { x: 0; y: 800 }
                PathLine { x: 0; y: 0 }
            }

            Behavior on opacity {
                NumberAnimation { duration: 700; easing.type: Easing.OutQuad } // Tailwind duration-700
            }
        }

        // Massive Icon
        MaterialIcon {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: col.isHovered ? 120 : 0
            anchors.verticalCenterOffset: col.isHovered ? 120 : 0
            text: col.icon
            color: Colours.palette[`m3${col.hue.toLowerCase()}`]
            iconPointSize: col.isHovered ? 198 : 180
            opacity: col.isHovered ? 0.2 : 0.05

            // transition: all 0.5s cubic-bezier(0.25, 0.8, 0.25, 1);
            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
            Behavior on iconPointSize { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
            Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
            Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        }

        // Vertical Text Container
        Item {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 80 // pb-section-gap
            anchors.horizontalCenter: parent.horizontalCenter
            width: verticalText.height
            height: verticalText.width

            StyledText {
                id: verticalText
                anchors.centerIn: parent
                rotation: -90
                
                text: col.label
                color: Colours.palette[`m3${col.hue.toLowerCase()}`]
                font.family: Tokens.font.family.display
                textPixelSize: 57 // display-lg
                font.weight: 700
                font.letterSpacing: col.isHovered ? 15 : 0
                opacity: col.isHovered ? 1.0 : 0.5
                
                // transition: all 0.5s cubic-bezier(0.25, 0.8, 0.25, 1);
                Behavior on font.letterSpacing { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
            }
        }

        // Keyboard / Click Interactions
        Keys.onEnterPressed: Quickshell.execDetached(col.command)
        Keys.onReturnPressed: Quickshell.execDetached(col.command)
        Keys.onEscapePressed: root.visibilities.session = false
        
        Keys.onPressed: event => {
            if (!Config.session.vimKeybinds) return;
            if (event.modifiers & Qt.ControlModifier) {
                if ((event.key === Qt.Key_L || event.key === Qt.Key_N) && KeyNavigation.right) {
                    KeyNavigation.right.focus = true;
                    event.accepted = true;
                } else if ((event.key === Qt.Key_H || event.key === Qt.Key_P) && KeyNavigation.left) {
                    KeyNavigation.left.focus = true;
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Tab && KeyNavigation.right) {
                KeyNavigation.right.focus = true;
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                if (KeyNavigation.left) {
                    KeyNavigation.left.focus = true;
                    event.accepted = true;
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.left: parent.left
            anchors.right: parent.right
            y: (root.height * 0.28) - 40
            height: root.height * 0.54
            hoverEnabled: true
            onClicked: Quickshell.execDetached(col.command)
        }
    }
}
