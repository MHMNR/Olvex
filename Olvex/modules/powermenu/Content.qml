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

    readonly property bool isPowermenuOpen: root.visibilities.powermenu && (Config.powermenu.enabled ?? true)
    readonly property var m3SpatialSpring: [0.22, 1.18, 0.45, 1.00, 1.0, 1.0]
    readonly property var m3ExitAccel: [0.35, 0.0, 0.85, 0.15, 1.0, 1.0]

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
            columnIndex: 0
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
            columnIndex: 1
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
            columnIndex: 2
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
            columnIndex: 3
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

        required property int columnIndex
        required property string icon
        required property var command
        required property string hue
        required property string keyLetter
        required property string restOfLabel
        readonly property string label: keyLetter + restOfLabel

        property real cardEntryProgress: 0.0

        states: [
            State {
                name: "opened"
                when: root.isPowermenuOpen
                PropertyChanges {
                    target: col
                    cardEntryProgress: 1.0
                }
            }
        ]

        transitions: [
            Transition {
                to: "opened"
                SequentialAnimation {
                    PauseAnimation { duration: col.columnIndex * 55 }
                    NumberAnimation {
                        target: col
                        property: "cardEntryProgress"
                        duration: 520
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.m3SpatialSpring
                    }
                }
            },
            Transition {
                from: "opened"
                SequentialAnimation {
                    PauseAnimation { duration: (3 - col.columnIndex) * 25 }
                    NumberAnimation {
                        target: col
                        property: "cardEntryProgress"
                        duration: 240
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.m3ExitAccel
                    }
                }
            }
        ]

        property bool isHovered: mouseArea.containsMouse || col.activeFocus
        property real weight: isHovered ? 1.6 : 1.0

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
        clip: false

        readonly property color accentColor: Colours.palette[`m3${col.hue.toLowerCase()}`] || Colours.palette.m3primary
        readonly property color onAccentColor: Colours.palette[`m3on${col.hue}`] || Colours.palette.m3onPrimary

        // Frosted M3 Container Backing (Polished translucent surface elevation)
        StyledRect {
            id: cardSurface
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.topMargin: 10 + (1.0 - col.cardEntryProgress) * 160
            anchors.bottomMargin: 10 - (1.0 - col.cardEntryProgress) * 160
            radius: Tokens.rounding.large
            clip: true

            opacity: Math.max(0.0, Math.min(1.0, col.cardEntryProgress * 1.25))
            scale: 0.88 + 0.12 * col.cardEntryProgress
            transformOrigin: Item.Center

            color: col.isHovered
                ? Qt.alpha(col.accentColor, Colours.light ? 0.20 : 0.25)
                : Qt.alpha(Colours.palette.m3surfaceContainerHigh, Colours.light ? 0.55 : 0.35)

            border.width: 1
            border.color: col.isHovered
                ? Qt.alpha(col.accentColor, 0.40)
                : Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.30 : 0.15)

            Behavior on border.color { CAnim {} }

            // Dynamic Cursor Radial Glow Spotlight Shader (C2-continuous smootherstep with TPDF dither)
            ShaderEffect {
                id: cursorGlowShader
                anchors.fill: parent
                opacity: col.isHovered ? 1.0 : 0.0
                visible: opacity > 0.005

                Behavior on opacity {
                    NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
                }

                property color uAccentColor: col.accentColor
                property vector2d uLightPos: Qt.vector2d(col.glowX - cardSurface.x, col.glowY - cardSurface.y)
                property vector2d uSize: Qt.vector2d(cardSurface.width, cardSurface.height)
                property real uRadius: cardSurface.radius

                fragmentShader: Quickshell.shellPath("assets/shaders/powermenu_glow.frag.qsb")
            }

            // Massive Atmospheric Icon (Sharp vector rendering with true point size scaling)
            MaterialIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenterOffset: col.isHovered ? 60 : 0
                anchors.verticalCenterOffset: 0

                text: col.icon
                color: col.isHovered ? col.accentColor : Colours.palette.m3onSurfaceVariant
                renderType: Text.CurveRendering
                smooth: true
                iconPointSize: col.isHovered ? 218 : 190
                scale: 0.72 + 0.28 * col.cardEntryProgress
                transformOrigin: Item.Center
                opacity: col.isHovered
                    ? (Colours.light ? 0.50 : 0.40)
                    : (Colours.light ? 0.25 : 0.15)

                Behavior on color { CAnim {} }
                Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                Behavior on iconPointSize { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
                Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
                Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
            }

            // Vertical Signature Display Typography with Keyboard Shortcut Keycap
            Item {
                id: typographyContainer
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: col.isHovered ? 0 : Math.round(col.height * 0.5 - 70 - verticalRow.width * 0.5)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: col.isHovered ? -170 : 0
                width: 52
                height: verticalRow.width
                opacity: Math.max(0.0, Math.min(1.0, (col.cardEntryProgress - 0.15) / 0.85))
                scale: 0.90 + 0.10 * col.cardEntryProgress
                transformOrigin: Item.Center

                Behavior on anchors.verticalCenterOffset {
                    NumberAnimation { duration: 360; easing.type: Easing.OutCubic }
                }
                Behavior on anchors.horizontalCenterOffset {
                    NumberAnimation { duration: 360; easing.type: Easing.OutCubic }
                }

                Row {
                    id: verticalRow
                    anchors.centerIn: parent
                    rotation: -90
                    spacing: col.isHovered ? 20 : 12
                    height: 52

                    Behavior on spacing { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }

                    // Material 3 Keyboard Button Icon (Clean, borderless, tonal M3 container)
                    StyledRect {
                        id: keycap
                        anchors.verticalCenter: parent.verticalCenter
                        width: 48
                        height: 48
                        radius: col.isHovered ? Tokens.rounding.medium : Tokens.rounding.small

                        color: col.isHovered
                            ? col.accentColor
                            : Qt.alpha(Colours.palette.m3surfaceContainerHighest, Colours.light ? 0.90 : 0.70)

                        Behavior on radius { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }

                        StyledText {
                            anchors.centerIn: parent
                            text: col.keyLetter
                            color: col.isHovered
                                ? col.onAccentColor
                                : Colours.palette.m3onSurface
                            font.family: Tokens.font.family.sans
                            renderType: Text.CurveRendering
                            smooth: true
                            textPixelSize: col.isHovered ? 26 : 24
                            font.weight: Font.Black

                            Behavior on textPixelSize { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
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
                        renderType: Text.CurveRendering
                        smooth: true
                        textPixelSize: col.isHovered ? 46 : 44
                        font.weight: Font.Bold
                        font.letterSpacing: col.isHovered ? 14 : 2
                        opacity: col.isHovered ? 1.0 : (Colours.light ? 0.85 : 0.60)

                        Behavior on textPixelSize { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
                        Behavior on color { CAnim {} }
                        Behavior on font.letterSpacing { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }

        // Full Column Click & Interaction Target with Cursor Tracking
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: root.isPowermenuOpen && col.cardEntryProgress > 0.65
            enabled: root.isPowermenuOpen && col.cardEntryProgress > 0.25
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
