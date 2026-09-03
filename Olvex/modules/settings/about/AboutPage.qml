pragma ComponentBehavior: Bound

import ".."
import "../ui"
import "../../../components"
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Olvex.Config
import qs.services
import qs.utils

Item {
    id: root

    property Session session
    signal back

    // Helper calculations for memory (RAM)
    readonly property real memUsedGB: SystemUsage.memTotal > 0 ? (SystemUsage.memUsed / 1048576.0) : 6.4
    readonly property real memTotalGB: SystemUsage.memTotal > 0 ? (SystemUsage.memTotal / 1048576.0) : 15.0
    readonly property int memPercInt: Math.round((SystemUsage.memTotal > 0 ? SystemUsage.memPerc : 0.42) * 100)

    // Helper calculations for main storage (Root /)
    readonly property var rootDisk: {
        if (!SystemUsage.disks || SystemUsage.disks.length === 0)
            return null;
        const found = SystemUsage.disks.find(d => d.hasRoot || d.mount === "/");
        return found || SystemUsage.disks[0];
    }
    readonly property real storageUsedGB: rootDisk ? (rootDisk.used / 1048576.0) : 88.4
    readonly property real storageTotalGB: rootDisk ? (rootDisk.total / 1048576.0) : 111.7
    readonly property int storagePercInt: rootDisk ? Math.round(rootDisk.perc * 100) : 79

    SettingsPage {
        anchors.fill: parent
        title: qsTr("About Olvex")
        subtitle: qsTr("System specifications, framework, and maintainer details")
        icon: "computer"
        accent: Colours.palette.m3primary
        onBack: root.back()
        hostMode: false // Standard scrollable page

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 16 // M3 Standard Container Margin (16px)

            // =========================================================================
            // TOP ROW: SYSTEM CARD (FULL WIDTH - COMPACT HEIGHT)
            // =========================================================================
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: sysCol.implicitHeight + 40 // 20px top + 20px bottom
                radius: 20 // M3Shapes.large
                color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
                border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.15)
                border.width: 1

                ColumnLayout {
                    id: sysCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 20
                    spacing: 14

                    // 1. Header Category Chip: SYSTEM
                    RowLayout {
                        spacing: 8

                        MaterialIcon {
                            text: "desktop_windows"
                            color: Colours.palette.m3primary
                            iconPointSize: 15
                        }

                        StyledText {
                            text: qsTr("SYSTEM")
                            color: Colours.palette.m3primary
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.8
                            textPointSize: Tokens.font.size.smaller
                        }
                    }

                    // 2. Hero Section: Animated Logo BEFORE Title (Symmetrical Spacing)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 6
                        spacing: 16

                        // Animated Olvex Logo Container
                        Item {
                            id: logoContainer
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 78
                            Layout.alignment: Qt.AlignVCenter

                            property real breath: 0
                            property real introProgress: 0
                            property real hoverProgress: logoMouse.containsMouse ? 1.0 : 0.0
                            property real pressProgress: logoMouse.pressed ? 1.0 : 0.0
                            property real pulseScale: 1.0
                            property real pulseRotation: 0

                            scale: (1.0 - logoContainer.pressProgress * 0.06) * logoContainer.pulseScale

                            Behavior on hoverProgress {
                                NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                            }

                            Behavior on pressProgress {
                                NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
                            }

                            Component.onCompleted: introAnim.start()

                            NumberAnimation {
                                id: introAnim
                                target: logoContainer
                                property: "introProgress"
                                from: 0
                                to: 1
                                duration: 900
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.2
                            }

                            SequentialAnimation {
                                running: root.visible
                                loops: Animation.Infinite
                                NumberAnimation { target: logoContainer; property: "breath"; from: -1; to: 1; duration: 2500; easing.type: Easing.InOutSine }
                                NumberAnimation { target: logoContainer; property: "breath"; from: 1; to: -1; duration: 2500; easing.type: Easing.InOutSine }
                            }

                            // Subtle & Smooth Click Bounce Animation (Autonomous playback regardless of cursor movement)
                            SequentialAnimation {
                                id: clickPulse
                                alwaysRunToEnd: true
                                ParallelAnimation {
                                    NumberAnimation { target: logoContainer; property: "pulseScale"; from: 0.94; to: 1.08; duration: 160; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: logoContainer; property: "pulseRotation"; from: -4; to: 4; duration: 160; easing.type: Easing.OutQuad }
                                }
                                ParallelAnimation {
                                    NumberAnimation { target: logoContainer; property: "pulseScale"; from: 1.08; to: 0.98; duration: 200; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: logoContainer; property: "pulseRotation"; from: 4; to: -1; duration: 200; easing.type: Easing.OutQuad }
                                }
                                ParallelAnimation {
                                    NumberAnimation { target: logoContainer; property: "pulseScale"; from: 0.98; to: 1.0; duration: 160; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: logoContainer; property: "pulseRotation"; from: -1; to: 0; duration: 160; easing.type: Easing.OutQuad }
                                }
                            }

                            // Left Beam (Indigo)
                            Shape {
                                width: 120
                                height: 120
                                anchors.centerIn: parent
                                opacity: logoContainer.introProgress
                                preferredRendererType: Shape.CurveRenderer
                                layer.enabled: true
                                layer.samples: 4
                                layer.smooth: true

                                anchors.horizontalCenterOffset: ((1.0 - logoContainer.introProgress) * -45) + (logoContainer.hoverProgress * -14) + (logoContainer.pressProgress * 6)
                                anchors.verticalCenterOffset: ((1.0 - logoContainer.introProgress) * -61) + (logoContainer.hoverProgress * -8) + (logoContainer.pressProgress * 4) + (logoContainer.breath * -4)

                                ShapePath {
                                    strokeColor: "#675FFF"
                                    strokeWidth: 14
                                    capStyle: ShapePath.RoundCap
                                    joinStyle: ShapePath.RoundJoin
                                    fillColor: "transparent"

                                    startX: 29
                                    startY: 95

                                    PathLine { x: 51.5; y: 48 }
                                }
                            }

                            // Right Beam (Coral)
                            Shape {
                                width: 120
                                height: 120
                                anchors.centerIn: parent
                                opacity: logoContainer.introProgress
                                preferredRendererType: Shape.CurveRenderer
                                layer.enabled: true
                                layer.samples: 4
                                layer.smooth: true

                                anchors.horizontalCenterOffset: ((1.0 - logoContainer.introProgress) * 45) + (logoContainer.hoverProgress * 14) + (logoContainer.pressProgress * -6)
                                anchors.verticalCenterOffset: ((1.0 - logoContainer.introProgress) * -61) + (logoContainer.hoverProgress * -8) + (logoContainer.pressProgress * 4) + (logoContainer.breath * 4)

                                ShapePath {
                                    strokeColor: "#FF8A5B"
                                    strokeWidth: 14
                                    capStyle: ShapePath.RoundCap
                                    joinStyle: ShapePath.RoundJoin
                                    fillColor: "transparent"

                                    startX: 91
                                    startY: 95

                                    PathLine { x: 68.5; y: 48 }
                                }
                            }

                            // Wave Line
                            Shape {
                                width: 120
                                height: 120
                                anchors.centerIn: parent
                                opacity: logoContainer.introProgress
                                rotation: logoContainer.pulseRotation
                                preferredRendererType: Shape.CurveRenderer
                                layer.enabled: true
                                layer.samples: 4
                                layer.smooth: true

                                anchors.verticalCenterOffset: ((1.0 - logoContainer.introProgress) * 39) + (logoContainer.hoverProgress * 14) + (logoContainer.pressProgress * -4) + (Math.sin(logoContainer.breath * Math.PI) * 4)

                                ShapePath {
                                    strokeColor: Colours.palette.m3onSurface
                                    strokeWidth: 4
                                    capStyle: ShapePath.RoundCap
                                    joinStyle: ShapePath.RoundJoin
                                    fillColor: "transparent"

                                    startX: 20
                                    startY: 103

                                    PathCubic { control1X: 35; control1Y: 96; control2X: 45; control2Y: 110; x: 60; y: 103 }
                                    PathCubic { control1X: 75; control1Y: 96; control2X: 85; control2Y: 110; x: 100; y: 103 }
                                }
                            }

                            MouseArea {
                                id: logoMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: clickPulse.restart()
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 4

                            StyledText {
                                text: "Olvex Shell"
                                font.weight: Font.Bold
                                font.letterSpacing: -0.3
                                color: Colours.palette.m3onSurface
                                textPointSize: 22
                            }

                            RowLayout {
                                spacing: 8

                                StyledRect {
                                    implicitWidth: verText.implicitWidth + 14
                                    implicitHeight: 22
                                    radius: Tokens.rounding.full
                                    color: Qt.alpha(Colours.palette.m3primary, 0.12)

                                    StyledText {
                                        id: verText
                                        anchors.centerIn: parent
                                        text: Version.versionString
                                        color: Colours.palette.m3primary
                                        font.family: Tokens.font.family.mono
                                        font.weight: Font.Bold
                                        textPointSize: Tokens.font.size.smaller
                                    }
                                }

                                Loader {
                                    active: Boolean(Version.commit)
                                    visible: active
                                    sourceComponent: StyledRect {
                                        implicitWidth: commitText.implicitWidth + 12
                                        implicitHeight: 22
                                        radius: Tokens.rounding.full
                                        color: Qt.alpha(Colours.palette.m3secondary, 0.12)

                                        StyledText {
                                            id: commitText
                                            anchors.centerIn: parent
                                            text: Version.commit
                                            color: Colours.palette.m3secondary
                                            font.family: Tokens.font.family.mono
                                            font.weight: Font.Medium
                                            textPointSize: Tokens.font.size.smaller
                                        }
                                    }
                                }

                                StyledText {
                                    text: Version.channel + (Version.branch ? (" (" + Version.branch + ")") : "")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.weight: Font.Normal
                                    font.letterSpacing: 0.1
                                    textPointSize: Tokens.font.size.small
                                }
                            }
                        }
                    }

                    // Horizontal Line Accent
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Qt.alpha(Colours.palette.m3outlineVariant, 0.15)
                    }

                    // 3. 3-Column Clean Unboxed OS Spec Grid (Compact Height)
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        columnSpacing: 24
                        rowSpacing: 14

                        // Item 1: KERNEL
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            RowLayout {
                                spacing: 6
                                MaterialIcon {
                                    text: "tune"
                                    color: Colours.palette.m3primary
                                    iconPointSize: 13
                                }
                                StyledText {
                                    text: qsTr("KERNEL")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 0.8
                                    textPointSize: Tokens.font.size.smaller
                                }
                            }

                            StyledText {
                                text: SysInfo.kernel || "Linux"
                                color: Colours.palette.m3onSurface
                                font.weight: Font.Medium
                                font.letterSpacing: -0.1
                                textPointSize: Tokens.font.size.normal
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Item 2: SYSTEM HOST
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            RowLayout {
                                spacing: 6
                                MaterialIcon {
                                    text: "badge"
                                    color: Colours.palette.m3primary
                                    iconPointSize: 13
                                }
                                StyledText {
                                    text: qsTr("SYSTEM HOST")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 0.8
                                    textPointSize: Tokens.font.size.smaller
                                }
                            }

                            StyledText {
                                text: (SysInfo.user || "user") + "@" + (SysInfo.osPrettyName || "linux")
                                color: Colours.palette.m3onSurface
                                font.weight: Font.Medium
                                font.letterSpacing: -0.1
                                textPointSize: Tokens.font.size.normal
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Item 3: UPTIME
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            RowLayout {
                                spacing: 6
                                MaterialIcon {
                                    text: "schedule"
                                    color: Colours.palette.m3primary
                                    iconPointSize: 13
                                }
                                StyledText {
                                    text: qsTr("UPTIME")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 0.8
                                    textPointSize: Tokens.font.size.smaller
                                }
                            }

                            StyledText {
                                text: SysInfo.uptime || "2 days, 14 hours"
                                color: Colours.palette.m3onSurface
                                font.weight: Font.Medium
                                font.letterSpacing: -0.1
                                textPointSize: Tokens.font.size.normal
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Item 4: SHELL ENVIRONMENT
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            RowLayout {
                                spacing: 6
                                MaterialIcon {
                                    text: "terminal"
                                    color: Colours.palette.m3primary
                                    iconPointSize: 13
                                }
                                StyledText {
                                    text: qsTr("SHELL ENVIRONMENT")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 0.8
                                    textPointSize: Tokens.font.size.smaller
                                }
                            }

                            StyledText {
                                text: (SysInfo.shell || "fish").toUpperCase() + " · Quickshell"
                                color: Colours.palette.m3onSurface
                                font.weight: Font.Medium
                                font.letterSpacing: -0.1
                                textPointSize: Tokens.font.size.normal
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Item 5: WINDOW MANAGER
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            RowLayout {
                                spacing: 6
                                MaterialIcon {
                                    text: "aspect_ratio"
                                    color: Colours.palette.m3primary
                                    iconPointSize: 13
                                }
                                StyledText {
                                    text: qsTr("WINDOW MANAGER")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 0.8
                                    textPointSize: Tokens.font.size.smaller
                                }
                            }

                            StyledText {
                                text: (SysInfo.wm || "Hyprland") + " · Wayland"
                                color: Colours.palette.m3onSurface
                                font.weight: Font.Medium
                                font.letterSpacing: -0.1
                                textPointSize: Tokens.font.size.normal
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Item 6: FRAMEWORK & TARGET
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            RowLayout {
                                spacing: 6
                                MaterialIcon {
                                    text: "widgets"
                                    color: Colours.palette.m3primary
                                    iconPointSize: 13
                                }
                                StyledText {
                                    text: qsTr("FRAMEWORK & TARGET")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 0.8
                                    textPointSize: Tokens.font.size.smaller
                                }
                            }

                            StyledText {
                                text: "Qt 6.7 · QML · Hyprland IPC"
                                color: Colours.palette.m3onSurface
                                font.weight: Font.Medium
                                font.letterSpacing: -0.1
                                textPointSize: Tokens.font.size.normal
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            // =========================================================================
            // BOTTOM ROW: 2 CARDS SIDE-BY-SIDE (SPECIFICATIONS & MAINTAINER)
            // =========================================================================
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                // --- CARD 1: SPECIFICATIONS ---
                StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    implicitHeight: Math.max(hwCol.implicitHeight, maintCol.implicitHeight) + 40
                    radius: 20 // M3Shapes.large
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
                    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.15)
                    border.width: 1

                    ColumnLayout {
                        id: hwCol
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 20
                        spacing: 16

                        // Header
                        RowLayout {
                            spacing: 8

                            MaterialIcon {
                                text: "memory"
                                color: Colours.palette.m3primary
                                iconPointSize: 16
                            }

                            StyledText {
                                text: qsTr("SPECIFICATIONS")
                                color: Colours.palette.m3primary
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.8
                                textPointSize: Tokens.font.size.smaller
                            }
                        }

                        // CPU Item
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            RowLayout {
                                spacing: 6
                                MaterialIcon {
                                    text: "developer_board"
                                    color: Colours.palette.m3primary
                                    iconPointSize: 13
                                }
                                StyledText {
                                    text: qsTr("CPU")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 0.8
                                    textPointSize: Tokens.font.size.smaller
                                }
                            }

                            StyledText {
                                text: SystemUsage.cpuName ? SystemUsage.cpuName : "AMD Ryzen Processor"
                                color: Colours.palette.m3onSurface
                                font.weight: Font.Medium
                                font.letterSpacing: -0.1
                                textPointSize: Tokens.font.size.normal
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // GPU Item
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            RowLayout {
                                spacing: 6
                                MaterialIcon {
                                    text: "videogame_asset"
                                    color: Colours.palette.m3primary
                                    iconPointSize: 13
                                }
                                StyledText {
                                    text: qsTr("GPU")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 0.8
                                    textPointSize: Tokens.font.size.smaller
                                }
                            }

                            StyledText {
                                text: (SystemUsage.gpuName && SystemUsage.gpuName !== "GPU")
                                      ? SystemUsage.gpuName
                                      : "AMD Radeon / NVIDIA Graphics"
                                color: Colours.palette.m3onSurface
                                font.weight: Font.Medium
                                font.letterSpacing: -0.1
                                textPointSize: Tokens.font.size.normal
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // RAM Item + Progress Bar
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true

                                RowLayout {
                                    spacing: 6
                                    MaterialIcon {
                                        text: "memory"
                                        color: Colours.palette.m3primary
                                        iconPointSize: 13
                                    }
                                    StyledText {
                                        text: qsTr("RAM")
                                        color: Colours.palette.m3onSurfaceVariant
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 0.8
                                        textPointSize: Tokens.font.size.smaller
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                RowLayout {
                                    spacing: 8

                                    StyledText {
                                        text: root.memUsedGB.toFixed(1) + " / " + root.memTotalGB.toFixed(1) + " GB"
                                        color: Colours.palette.m3onSurfaceVariant
                                        font.family: Tokens.font.family.mono
                                        font.weight: Font.Medium
                                        textPointSize: Tokens.font.size.smaller
                                    }

                                    StyledRect {
                                        implicitWidth: ramBadge.implicitWidth + 12
                                        implicitHeight: 20
                                        radius: Tokens.rounding.full
                                        color: Qt.alpha(Colours.palette.m3primary, 0.14)

                                        StyledText {
                                            id: ramBadge
                                            anchors.centerIn: parent
                                            text: root.memPercInt + "%"
                                            color: Colours.palette.m3primary
                                            font.family: Tokens.font.family.mono
                                            font.weight: Font.Bold
                                            textPointSize: Tokens.font.size.smaller
                                        }
                                    }
                                }
                            }

                            // RAM Usage Progress Bar
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 6
                                radius: 3
                                color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.65)

                                Rectangle {
                                    height: parent.height
                                    width: parent.width * Math.min(1.0, Math.max(0.05, (root.memPercInt / 100.0)))
                                    radius: 3
                                    color: Colours.palette.m3primary

                                    Behavior on width {
                                        NumberAnimation { duration: 400; easing.type: Easing.OutQuad }
                                    }
                                }
                            }
                        }

                        // STORAGE Item (Root /) + Progress Bar
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true

                                RowLayout {
                                    spacing: 6
                                    MaterialIcon {
                                        text: "storage"
                                        color: Colours.palette.m3primary
                                        iconPointSize: 13
                                    }
                                    StyledText {
                                        text: qsTr("STORAGE (Root /)")
                                        color: Colours.palette.m3onSurfaceVariant
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 0.8
                                        textPointSize: Tokens.font.size.smaller
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                RowLayout {
                                    spacing: 8

                                    StyledText {
                                        text: root.storageUsedGB.toFixed(1) + " / " + root.storageTotalGB.toFixed(1) + " GB"
                                        color: Colours.palette.m3onSurfaceVariant
                                        font.family: Tokens.font.family.mono
                                        font.weight: Font.Medium
                                        textPointSize: Tokens.font.size.smaller
                                    }

                                    StyledRect {
                                        implicitWidth: storeBadge.implicitWidth + 12
                                        implicitHeight: 20
                                        radius: Tokens.rounding.full
                                        color: Qt.alpha(Colours.palette.m3secondary, 0.14)

                                        StyledText {
                                            id: storeBadge
                                            anchors.centerIn: parent
                                            text: root.storagePercInt + "%"
                                            color: Colours.palette.m3secondary
                                            font.family: Tokens.font.family.mono
                                            font.weight: Font.Bold
                                            textPointSize: Tokens.font.size.smaller
                                        }
                                    }
                                }
                            }

                            // Storage Usage Progress Bar
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 6
                                radius: 3
                                color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.65)

                                Rectangle {
                                    height: parent.height
                                    width: parent.width * Math.min(1.0, Math.max(0.05, (root.storagePercInt / 100.0)))
                                    radius: 3
                                    color: Colours.palette.m3secondary

                                    Behavior on width {
                                        NumberAnimation { duration: 400; easing.type: Easing.OutQuad }
                                    }
                                }
                            }
                        }
                    }
                }

                // --- CARD 2: MAINTAINER ---
                StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    implicitHeight: Math.max(hwCol.implicitHeight, maintCol.implicitHeight) + 40
                    radius: 20 // M3Shapes.large
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
                    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.15)
                    border.width: 1

                    ColumnLayout {
                        id: maintCol
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 20
                        spacing: 16

                        // Header
                        RowLayout {
                            spacing: 8

                            MaterialIcon {
                                text: "verified_user"
                                color: Colours.palette.m3primary
                                iconPointSize: 16
                            }

                            StyledText {
                                text: qsTr("MAINTAINER")
                                color: Colours.palette.m3primary
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.8
                                textPointSize: Tokens.font.size.smaller
                            }
                        }

                        // Profile Row
                        RowLayout {
                            spacing: 12

                            StyledRect {
                                id: profileAvatar
                                Layout.preferredWidth: 44
                                Layout.preferredHeight: 44
                                radius: Tokens.rounding.full
                                color: profileArea.containsMouse ? Qt.alpha(Colours.palette.m3primary, 0.25) : Qt.alpha(Colours.palette.m3primary, 0.15)
                                border.color: Qt.alpha(Colours.palette.m3primary, 0.35)
                                border.width: 1.5
                                clip: true

                                Behavior on color { CAnim {} }

                                // Circle Mask Source
                                Item {
                                    id: avatarMask
                                    width: 44
                                    height: 44
                                    visible: false
                                    layer.enabled: true

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: width / 2
                                        color: "black"
                                    }
                                }

                                // Fallback Letter "M" when offline / loading
                                StyledText {
                                    anchors.centerIn: parent
                                    text: "M"
                                    color: Colours.palette.m3primary
                                    font.weight: Font.Bold
                                    textPointSize: Tokens.font.size.large
                                    visible: avatarImg.status !== Image.Ready
                                }

                                // GitHub Profile Picture with GPU Circle Mask
                                Image {
                                    id: avatarImg
                                    anchors.fill: parent
                                    source: "https://github.com/MHMNR.png"
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true
                                    mipmap: true

                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskSource: avatarMask
                                    }
                                }

                                MouseArea {
                                    id: profileArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/MHMNR"])
                                }
                            }

                            ColumnLayout {
                                spacing: 2

                                RowLayout {
                                    spacing: 6

                                    StyledText {
                                        id: creatorText
                                        text: "Muhimenur"
                                        color: creatorArea.containsMouse ? Colours.palette.m3primary : Colours.palette.m3onSurface
                                        font.weight: Font.Bold
                                        font.letterSpacing: -0.1
                                        textPointSize: Tokens.font.size.normal

                                        Behavior on color { CAnim {} }

                                        MouseArea {
                                            id: creatorArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/MHMNR"])
                                        }
                                    }

                                    StyledText {
                                        text: "(@MHMNR)"
                                        color: Colours.palette.m3primary
                                        font.family: Tokens.font.family.mono
                                        font.weight: Font.Medium
                                        textPointSize: Tokens.font.size.smaller
                                    }
                                }

                                StyledText {
                                    text: qsTr("Creator & Lead Architect")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.weight: Font.Normal
                                    font.letterSpacing: 0.1
                                    textPointSize: Tokens.font.size.smaller
                                }
                            }
                        }

                        // Contact Links List
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // GitHub Link
                            StyledRect {
                                id: repoCard
                                Layout.fillWidth: true
                                implicitHeight: repoRow.implicitHeight + 14
                                radius: 12 // M3Shapes.medium
                                color: repoArea.containsMouse ? Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.6) : Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.25)
                                border.color: repoArea.containsMouse ? Qt.alpha(Colours.palette.m3primary, 0.35) : "transparent"
                                border.width: 1

                                Behavior on color { CAnim {} }
                                Behavior on border.color { CAnim {} }

                                RowLayout {
                                    id: repoRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: 12
                                    spacing: 12

                                    MaterialIcon {
                                        text: "code"
                                        color: Colours.palette.m3primary
                                        iconPointSize: 16
                                    }

                                    ColumnLayout {
                                        spacing: 1
                                        StyledText {
                                            text: qsTr("Repository")
                                            color: Colours.palette.m3onSurface
                                            font.weight: Font.DemiBold
                                            textPointSize: Tokens.font.size.small
                                        }
                                        StyledText {
                                            text: "github.com/MHMNR/Olvex"
                                            color: Colours.palette.m3primary
                                            font.family: Tokens.font.family.mono
                                            font.weight: Font.Medium
                                            textPointSize: (Tokens.font.size.smaller) - 1
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    MaterialIcon {
                                        text: "open_in_new"
                                        color: Colours.palette.m3onSurfaceVariant
                                        iconPointSize: 14
                                    }
                                }

                                MouseArea {
                                    id: repoArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/MHMNR/Olvex"])
                                }
                            }

                            // Config Folder Link
                            StyledRect {
                                id: cfgCard
                                Layout.fillWidth: true
                                implicitHeight: cfgRow.implicitHeight + 14
                                radius: 12 // M3Shapes.medium
                                color: cfgArea.containsMouse ? Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.6) : Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.25)
                                border.color: cfgArea.containsMouse ? Qt.alpha(Colours.palette.m3tertiary, 0.35) : "transparent"
                                border.width: 1

                                Behavior on color { CAnim {} }
                                Behavior on border.color { CAnim {} }

                                RowLayout {
                                    id: cfgRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: 12
                                    spacing: 12

                                    MaterialIcon {
                                        text: "folder_open"
                                        color: Colours.palette.m3tertiary
                                        iconPointSize: 16
                                    }

                                    ColumnLayout {
                                        spacing: 1
                                        StyledText {
                                            text: qsTr("Config Directory")
                                            color: Colours.palette.m3onSurface
                                            font.weight: Font.DemiBold
                                            textPointSize: Tokens.font.size.small
                                        }
                                        StyledText {
                                            text: "~/.config/olvex"
                                            color: Colours.palette.m3tertiary
                                            font.family: Tokens.font.family.mono
                                            font.weight: Font.Medium
                                            textPointSize: (Tokens.font.size.smaller) - 1
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    MaterialIcon {
                                        text: "chevron_right"
                                        color: Colours.palette.m3onSurfaceVariant
                                        iconPointSize: 14
                                    }
                                }

                                MouseArea {
                                    id: cfgArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["xdg-open", Paths.config])
                                }
                            }

                            // Report Issue Link
                            StyledRect {
                                id: issueCard
                                Layout.fillWidth: true
                                implicitHeight: issueRow.implicitHeight + 14
                                radius: 12 // M3Shapes.medium
                                color: issueArea.containsMouse ? Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.6) : Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.25)
                                border.color: issueArea.containsMouse ? Qt.alpha(Colours.palette.m3error, 0.35) : "transparent"
                                border.width: 1

                                Behavior on color { CAnim {} }
                                Behavior on border.color { CAnim {} }

                                RowLayout {
                                    id: issueRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: 12
                                    spacing: 12

                                    MaterialIcon {
                                        text: "bug_report"
                                        color: Colours.palette.m3error
                                        iconPointSize: 16
                                    }

                                    ColumnLayout {
                                        spacing: 1
                                        StyledText {
                                            text: qsTr("Report Issue")
                                            color: Colours.palette.m3onSurface
                                            font.weight: Font.DemiBold
                                            textPointSize: Tokens.font.size.small
                                        }
                                        StyledText {
                                            text: "github.com/MHMNR/Olvex/issues"
                                            color: Colours.palette.m3error
                                            font.family: Tokens.font.family.mono
                                            font.weight: Font.Medium
                                            textPointSize: (Tokens.font.size.smaller) - 1
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    MaterialIcon {
                                        text: "open_in_new"
                                        color: Colours.palette.m3onSurfaceVariant
                                        iconPointSize: 14
                                    }
                                }

                                MouseArea {
                                    id: issueArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/MHMNR/Olvex/issues"])
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: 24 // Bottom pad
        }
    }
}
