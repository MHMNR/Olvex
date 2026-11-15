import QtQuick
import QtQuick.Layouts
import Quickshell
import Olvex.Config
import qs.components
import qs.services

ColumnLayout {
    id: root

    anchors.fill: parent
    anchors.margins: 14
    spacing: 8

    readonly property real totalWeight: rebootBtn.weight + shutdownBtn.weight + sleepBtn.weight + logoutBtn.weight

    function execute(cmd) {
        if (Array.isArray(cmd) && cmd.length > 0) {
            Quickshell.execDetached(cmd);
        } else if (typeof cmd === "string" && cmd.length > 0) {
            Quickshell.execDetached(["sh", "-c", cmd]);
        } else if (cmd) {
            Quickshell.execDetached(cmd);
        }
    }

    // ── Signature M3 Header Pill ─────────────────────────────────────────────
    StyledRect {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        radius: Tokens.rounding.small
        color: Colours.tileFill

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 3
                Layout.fillHeight: true
                Layout.topMargin: 7
                Layout.bottomMargin: 7
                radius: 1.5
                color: Colours.palette.m3tertiary
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: qsTr("Power Session")
                color: Colours.palette.m3onSurface
                textPointSize: Tokens.font.size.normal
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                MaterialIcon {
                    text: "lock"
                    color: Colours.palette.m3tertiary
                    iconPointSize: 12
                }

                StyledText {
                    text: qsTr("LOCKED")
                    color: Colours.palette.m3onSurfaceVariant
                    font.family: Tokens.font.family.mono
                    textPointSize: 8
                    font.weight: Font.Bold
                }
            }
        }
    }

    // ── Main Powermenu-Style Accordion Row ───────────────────────────────────
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Row {
            id: mainRow
            anchors.fill: parent
            spacing: 8

            SessionColumn {
                id: rebootBtn
                width: ((mainRow.width - 3 * mainRow.spacing) / root.totalWeight) * weight
                icon: Config.powermenu.icons.reboot || "refresh"
                label: qsTr("Reboot")
                command: Config.powermenu.commands.reboot || ["systemctl", "reboot"]
                hue: "Secondary"
            }

            SessionColumn {
                id: shutdownBtn
                width: ((mainRow.width - 3 * mainRow.spacing) / root.totalWeight) * weight
                icon: Config.powermenu.icons.shutdown || "power_settings_new"
                label: qsTr("Off")
                command: Config.powermenu.commands.shutdown || ["systemctl", "poweroff"]
                hue: "Error"
            }

            SessionColumn {
                id: sleepBtn
                width: ((mainRow.width - 3 * mainRow.spacing) / root.totalWeight) * weight
                icon: Config.powermenu.icons.suspend || Config.powermenu.icons.hibernate || "bedtime"
                label: qsTr("Sleep")
                command: Config.powermenu.commands.suspend || Config.powermenu.commands.hibernate || ["systemctl", "suspend"]
                hue: "Primary"
            }

            SessionColumn {
                id: logoutBtn
                width: ((mainRow.width - 3 * mainRow.spacing) / root.totalWeight) * weight
                icon: Config.powermenu.icons.logout || "logout"
                label: qsTr("Logout")
                command: Config.powermenu.commands.logout || ["loginctl", "terminate-user", ""]
                hue: "Tertiary"
            }
        }
    }

    component SessionColumn: Item {
        id: col

        required property string icon
        required property string label
        required property var command
        required property string hue

        readonly property bool isHovered: mouseArea.containsMouse
        property real weight: isHovered ? 1.65 : 1.0

        Behavior on weight {
            NumberAnimation {
                duration: 360
                easing.type: Easing.OutCubic
            }
        }

        property real targetGlowX: width / 2
        property real targetGlowY: height / 2
        property real glowX: targetGlowX
        property real glowY: targetGlowY

        Behavior on glowX { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        Behavior on glowY { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

        height: mainRow.height

        readonly property color accentColor: Colours.palette[`m3${col.hue.toLowerCase()}`] || Colours.palette.m3primary
        readonly property color onAccentColor: Colours.palette[`m3on${col.hue}`] || Colours.palette.m3onPrimary

        StyledClippingRect {
            id: cardSurface
            anchors.fill: parent
            radius: col.isHovered ? Tokens.rounding.normal : Tokens.rounding.small
            color: col.isHovered
                ? Qt.alpha(col.accentColor, Colours.light ? 0.20 : 0.25)
                : Colours.tileFill
            scale: mouseArea.pressed ? 0.95 : 1.0

            Behavior on radius { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
            Behavior on scale  { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            // Dynamic Cursor Radial Glow Spotlight Shader (same shader as main powermenu)
            ShaderEffect {
                id: cursorGlowShader
                anchors.fill: parent
                opacity: col.isHovered ? 1.0 : 0.0
                visible: opacity > 0.005

                Behavior on opacity {
                    NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
                }

                property color uAccentColor: col.accentColor
                property vector2d uLightPos: Qt.vector2d(col.glowX, col.glowY)
                property vector2d uSize: Qt.vector2d(cardSurface.width, cardSurface.height)
                property real uRadius: cardSurface.radius

                fragmentShader: Quickshell.shellPath("assets/shaders/powermenu_glow.frag.qsb")
            }

            // Foreground Icon + Expanding Label
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: col.icon
                    color: col.isHovered ? col.accentColor : Colours.palette.m3onSurface
                    iconPointSize: col.isHovered ? 20 : 18

                    Behavior on color { CAnim {} }
                    Behavior on iconPointSize { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: col.label
                    color: col.isHovered ? col.accentColor : Colours.palette.m3onSurface
                    textPointSize: Tokens.font.size.smaller - 1
                    font.weight: Font.Bold
                    font.letterSpacing: col.isHovered ? 1.2 : 0.2
                    opacity: col.isHovered ? 1.0 : (Colours.light ? 0.88 : 0.78)

                    Behavior on color { CAnim {} }
                    Behavior on font.letterSpacing { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPositionChanged: mouse => {
                col.targetGlowX = mouse.x;
                col.targetGlowY = mouse.y;
            }
            onEntered: {
                col.targetGlowX = mouseArea.mouseX;
                col.targetGlowY = mouseArea.mouseY;
            }
            onExited: {
                col.targetGlowX = col.width / 2;
                col.targetGlowY = col.height / 2;
            }
            onClicked: root.execute(col.command)
        }
    }
}
