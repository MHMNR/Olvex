import QtQuick
import QtQuick.Layouts
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
    Keys.onEscapePressed: root.visibilities.powermenu = false
    Component.onCompleted: root.forceActiveFocus()

    function execute(cmd) {
        root.visibilities.powermenu = false;
        Quickshell.execDetached(cmd);
    }

    // Dismiss when clicking anywhere outside
    MouseArea {
        anchors.fill: parent
        onClicked: root.visibilities.powermenu = false
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.visibilities.powermenu = false;
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_P || event.key === Qt.Key_1) {
            root.execute(shutdownBtn.command);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_R || event.key === Qt.Key_2) {
            root.execute(rebootBtn.command);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_S || event.key === Qt.Key_3) {
            root.execute(hibernateBtn.command);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_L || event.key === Qt.Key_4) {
            root.execute(logoutBtn.command);
            event.accepted = true;
            return;
        }
    }

    // Main Signature Accordion Canvas
    Row {
        id: mainRow
        anchors.fill: parent
        anchors.topMargin: 36
        anchors.bottomMargin: 36
        anchors.leftMargin: 36
        anchors.rightMargin: 36

        SessionColumn {
            id: shutdownBtn
            width: (mainRow.width / root.totalWeight) * weight
            icon: Config.powermenu.icons.shutdown || "power_settings_new"
            keyLetter: "P"
            restOfLabel: "OWER OFF"
            command: Config.powermenu.commands.shutdown || ["systemctl", "poweroff"]
            hue: "Error"
            KeyNavigation.right: rebootBtn
        }

        SessionColumn {
            id: rebootBtn
            width: (mainRow.width / root.totalWeight) * weight
            icon: Config.powermenu.icons.reboot || "restart_alt"
            keyLetter: "R"
            restOfLabel: "EBOOT"
            command: Config.powermenu.commands.reboot || ["systemctl", "reboot"]
            hue: "Secondary"
            KeyNavigation.left: shutdownBtn
            KeyNavigation.right: hibernateBtn
        }

        SessionColumn {
            id: hibernateBtn
            width: (mainRow.width / root.totalWeight) * weight
            icon: Config.powermenu.icons.suspend || Config.powermenu.icons.hibernate || "bedtime"
            keyLetter: "S"
            restOfLabel: "LEEP"
            command: Config.powermenu.commands.suspend || Config.powermenu.commands.hibernate || ["systemctl", "suspend"]
            hue: "Primary"
            KeyNavigation.left: rebootBtn
            KeyNavigation.right: logoutBtn
        }

        SessionColumn {
            id: logoutBtn
            width: (mainRow.width / root.totalWeight) * weight
            icon: Config.powermenu.icons.logout || "logout"
            keyLetter: "L"
            restOfLabel: "OGOUT"
            command: Config.powermenu.commands.logout || ["loginctl", "terminate-user", ""]
            hue: "Tertiary"
            KeyNavigation.left: hibernateBtn
        }
    }

    component SessionColumn: Item {
        id: col

        required property string icon
        required property var command
        required property string hue
        required property string keyLetter
        required property string restOfLabel
        readonly property string label: keyLetter + restOfLabel

        property bool isHovered: mouseArea.containsMouse || col.activeFocus
        property real weight: isHovered ? 1.6 : 1.0

        Behavior on weight {
            NumberAnimation {
                duration: 360
                easing.type: Easing.OutCubic
            }
        }

        height: mainRow.height
        clip: true

        readonly property color accentColor: Colours.palette[`m3${col.hue.toLowerCase()}`] || Colours.palette.m3primary
        readonly property color onAccentColor: Colours.palette[`m3on${col.hue}`] || Colours.palette.m3onPrimary

        // Frosted M3 Container Backing (Clean margins, no harsh borders)
        StyledRect {
            id: cardSurface
            anchors.fill: parent
            anchors.margins: 10
            radius: Tokens.rounding.large
            color: col.isHovered
                ? Qt.alpha(col.accentColor, Colours.light ? 0.16 : 0.22)
                : Qt.alpha(Colours.palette.m3surfaceContainer, Colours.light ? 0.80 : 0.45)

            Behavior on color { CAnim {} }

            // Radial Mesh Glow on Hover (GPU texture cached for zero-overhead opacity fade)
            Shape {
                anchors.centerIn: parent
                width: 900
                height: 900
                layer.enabled: true
                layer.smooth: true
                opacity: col.isHovered ? 1.0 : 0.0

                ShapePath {
                    strokeWidth: 0
                    fillGradient: RadialGradient {
                        centerX: 450; centerY: 450
                        centerRadius: 450
                        focalX: 450; focalY: 450
                        GradientStop { position: 0.0; color: Qt.alpha(col.accentColor, Colours.light ? 0.35 : 0.45) }
                        GradientStop { position: 0.65; color: Qt.alpha(col.accentColor, 0.08) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    startX: 0; startY: 0
                    PathLine { x: 900; y: 0 }
                    PathLine { x: 900; y: 900 }
                    PathLine { x: 0; y: 900 }
                    PathLine { x: 0; y: 0 }
                }

                Behavior on opacity {
                    NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
                }
            }

            // Massive Atmospheric Icon (GPU matrix-transformed scale, no font re-rasterization)
            MaterialIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenterOffset: col.isHovered ? 60 : 0
                anchors.verticalCenterOffset: col.isHovered ? -50 : -80

                text: col.icon
                color: col.accentColor
                iconPointSize: 190
                scale: col.isHovered ? 1.15 : 1.0
                opacity: col.isHovered
                    ? (Colours.light ? 0.40 : 0.30)
                    : (Colours.light ? 0.20 : 0.10)

                Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
                Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
                Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
            }

            // Vertical Signature Display Typography with Keyboard Shortcut Keycap
            Item {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 70
                anchors.horizontalCenter: parent.horizontalCenter
                width: verticalRow.height
                height: verticalRow.width

                Row {
                    id: verticalRow
                    anchors.centerIn: parent
                    rotation: -90
                    spacing: col.isHovered ? 16 : 14
                    height: 52
                    scale: col.isHovered ? 1.05 : 1.0

                    Behavior on spacing { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

                    // Material 3 Keyboard Button Icon (Clean, borderless, tonal M3 container)
                    StyledRect {
                        id: keycap
                        anchors.verticalCenter: parent.verticalCenter
                        width: 48
                        height: 48
                        radius: col.isHovered ? Tokens.rounding.medium : Tokens.rounding.small
                        scale: mouseArea.pressed ? 0.90 : 1.0

                        color: col.isHovered
                            ? col.accentColor
                            : Qt.alpha(Colours.palette.m3surfaceContainerHighest, Colours.light ? 0.90 : 0.70)

                        Behavior on radius { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                        StyledText {
                            anchors.centerIn: parent
                            text: col.keyLetter
                            color: col.isHovered
                                ? col.onAccentColor
                                : Colours.palette.m3onSurface
                            font.family: Tokens.font.family.sans
                            textPixelSize: 24
                            font.weight: Font.Black

                            Behavior on color { CAnim {} }
                        }
                    }

                    // Remainder of Label
                    StyledText {
                        id: restOfLabelText
                        anchors.verticalCenter: parent.verticalCenter

                        text: col.restOfLabel
                        color: col.isHovered
                            ? col.accentColor
                            : Colours.palette.m3onSurface
                        font.family: Tokens.font.family.sans
                        textPixelSize: 44
                        font.weight: Font.Bold
                        font.letterSpacing: 4
                        opacity: col.isHovered ? 1.0 : (Colours.light ? 0.85 : 0.60)

                        Behavior on color { CAnim {} }
                        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }

        // Full Column Click & Interaction Target
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.execute(col.command)
        }

        Keys.onReturnPressed: root.execute(col.command)
        Keys.onEnterPressed: root.execute(col.command)
        Keys.onPressed: event => {
            if (!Config.powermenu.vimKeybinds) return;
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
    }
}
