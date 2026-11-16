
import ".."
import "../ui"
import "../../../components"
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import M3Shapes
import Quickshell
import Quickshell.Io
import Olvex.Config
import qs.services
import qs.utils

Item {
    id: root

    property Session session
    property string activeSection: ""
    signal back

    property bool updateChecking: false
    property bool updateAvailable: false
    property string updateOldHash: ""
    property string updateNewHash: ""

    Process {
        id: updateCheckProc
        command: ["olvex", "update", "--check"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.updateChecking = false;
                if (!text) return;
                // Strip ANSI escape codes (e.g. \u001b[1;33m) output by the CLI
                const clean = text.replace(/\u001b\[[0-9;]*[a-zA-Z]/g, "").trim();
                const match = clean.match(/Update available:\s*([a-f0-9]+)\s*->\s*([a-f0-9]+)/i);
                if (match) {
                    root.updateAvailable = true;
                    root.updateOldHash = match[1];
                    root.updateNewHash = match[2];
                } else if (clean.includes("already up to date")) {
                    root.updateAvailable = false;
                }
            }
        }
        onExited: {
            root.updateChecking = false;
        }
    }

    Component.onCompleted: {
        root.updateChecking = true;
        updateCheckProc.running = true;
    }

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
            spacing: 18 // M3 Standard Bento Container Spacing

            // =========================================================================
            // TOP ROW: SYSTEM CARD (FULL WIDTH - COMPACT HEIGHT)
            // =========================================================================
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: sysCol.implicitHeight + 44
                radius: 20 // M3Shapes.large
                color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
                border.color: "transparent"
                border.width: 0
                clip: true

                ColumnLayout {
                    id: sysCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 22
                    spacing: 16

                    // 1. Header Category: System
                    RowLayout {
                        spacing: 10

                        MaterialShape {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 32
                            implicitHeight: 32
                            implicitSize: 32
                            shape: MaterialShape.Cookie12Sided
                            color: Colours.palette.m3primary

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "desktop_windows"
                                color: Colours.palette.m3onPrimary
                                iconPointSize: 15
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        StyledText {
                            text: qsTr("System")
                            color: Colours.palette.m3onSurface
                            font.weight: Font.DemiBold
                            textPointSize: 15
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
                                    implicitWidth: verText.implicitWidth + 20
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
                                        implicitWidth: commitText.implicitWidth + 18
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

                                StyledRect {
                                    implicitWidth: channelText.implicitWidth + 18
                                    implicitHeight: 22
                                    radius: Tokens.rounding.full
                                    color: Qt.alpha(Colours.palette.m3onSurface, 0.08)

                                    StyledText {
                                        id: channelText
                                        anchors.centerIn: parent
                                        text: Version.channel + (Version.branch ? (" (" + Version.branch + ")") : "")
                                        color: Colours.palette.m3onSurfaceVariant
                                        font.family: Tokens.font.family.mono
                                        font.weight: Font.Medium
                                        textPointSize: Tokens.font.size.smaller
                                    }
                                }

                                // Status badge (Up to date or checking)
                                StyledRect {
                                    visible: !root.updateAvailable
                                    implicitWidth: statusRow.implicitWidth + 18
                                    implicitHeight: 22
                                    radius: Tokens.rounding.full
                                    color: root.updateChecking ? Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.08) : Qt.alpha(Colours.palette.m3primary, 0.08)

                                    RowLayout {
                                        id: statusRow
                                        anchors.centerIn: parent
                                        spacing: 5

                                        MaterialIcon {
                                            text: root.updateChecking ? "sync" : "check_circle"
                                            color: root.updateChecking ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3primary
                                            iconPointSize: 12
                                        }

                                        StyledText {
                                            text: root.updateChecking ? qsTr("Checking...") : qsTr("Up to date")
                                            color: root.updateChecking ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3primary
                                            font.weight: Font.Medium
                                            textPointSize: (Tokens.font.size.smaller) - 1
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Update Available Banner (Displays only when an update is available)
                    StyledRect {
                        id: updateBanner
                        visible: root.updateAvailable
                        Layout.fillWidth: true
                        implicitHeight: updateRow.implicitHeight + 20
                        radius: 14
                        color: Qt.alpha(Colours.palette.m3primary, 0.12)
                        border.color: Qt.alpha(Colours.palette.m3primary, 0.35)
                        border.width: 1

                        RowLayout {
                            id: updateRow
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            StyledRect {
                                implicitWidth: 36
                                implicitHeight: 36
                                radius: Tokens.rounding.full
                                color: Qt.alpha(Colours.palette.m3primary, 0.2)

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "upgrade"
                                    color: Colours.palette.m3primary
                                    iconPointSize: 18
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    text: qsTr("Update Available") + (root.updateNewHash ? " · " + root.updateNewHash : "")
                                    color: Colours.palette.m3primary
                                    font.weight: Font.Bold
                                    textPointSize: Tokens.font.size.normal
                                }

                                StyledText {
                                    text: qsTr("Run 'olvex update' in your terminal to install the latest version.")
                                    color: Colours.palette.m3onSurface
                                    font.weight: Font.Normal
                                    textPointSize: Tokens.font.size.smaller
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }

                            // Click to copy command button
                            StyledRect {
                                id: copyBtn
                                implicitWidth: copyRow.implicitWidth + 18
                                implicitHeight: 32
                                radius: Tokens.rounding.full
                                color: copyMouse.pressed ? Qt.alpha(Colours.palette.m3primary, 0.35)
                                     : copyMouse.containsMouse ? Qt.alpha(Colours.palette.m3primary, 0.25)
                                     : Qt.alpha(Colours.palette.m3primary, 0.15)
                                border.color: Qt.alpha(Colours.palette.m3primary, 0.3)
                                border.width: 1

                                Behavior on color { CAnim {} }

                                RowLayout {
                                    id: copyRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    StyledText {
                                        text: "olvex update"
                                        color: Colours.palette.m3primary
                                        font.family: Tokens.font.family.mono
                                        font.weight: Font.Bold
                                        textPointSize: (Tokens.font.size.smaller) - 1
                                    }

                                    MaterialIcon {
                                        text: "content_copy"
                                        color: Colours.palette.m3primary
                                        iconPointSize: 13
                                    }
                                }

                                MouseArea {
                                    id: copyMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Quickshell.execDetached(["wl-copy", "olvex update"]);
                                        Toaster.toast(qsTr("Copied 'olvex update' to clipboard"), "", "content_copy");
                                    }
                                }
                            }
                        }
                    }

                    // 3. 3-Column Clean Unboxed OS Spec Grid (Compact Height)
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        columns: 3
                        columnSpacing: 24
                        rowSpacing: 16

                        // Item 1: OPERATING SYSTEM
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            StyledText {
                                text: qsTr("OPERATING SYSTEM")
                                color: Colours.palette.m3onSurfaceVariant
                                font.weight: Font.Medium
                                font.letterSpacing: 0.8
                                font.pixelSize: 11
                            }

                            StyledText {
                                text: SysInfo.osDisplay || "Arch Linux (x86_64)"
                                color: Colours.palette.m3onSurface
                                font.weight: Font.Medium
                                font.letterSpacing: -0.1
                                textPointSize: Tokens.font.size.normal
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Item 2: KERNEL
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            StyledText {
                                text: qsTr("KERNEL")
                                color: Colours.palette.m3onSurfaceVariant
                                font.weight: Font.Medium
                                font.letterSpacing: 0.8
                                font.pixelSize: 11
                            }

                            StyledText {
                                text: SysInfo.kernelFormatted || (SysInfo.kernel ? ("Linux " + SysInfo.kernel) : "Linux")
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

                            StyledText {
                                text: qsTr("UPTIME")
                                color: Colours.palette.m3onSurfaceVariant
                                font.weight: Font.Medium
                                font.letterSpacing: 0.8
                                font.pixelSize: 11
                            }

                            StyledText {
                                text: SysInfo.uptime || "0m"
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

                            StyledText {
                                text: qsTr("SHELL ENVIRONMENT")
                                color: Colours.palette.m3onSurfaceVariant
                                font.weight: Font.Medium
                                font.letterSpacing: 0.8
                                font.pixelSize: 11
                            }

                            StyledText {
                                text: SysInfo.shell + " · Quickshell"
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

                            StyledText {
                                text: qsTr("WINDOW MANAGER")
                                color: Colours.palette.m3onSurfaceVariant
                                font.weight: Font.Medium
                                font.letterSpacing: 0.8
                                font.pixelSize: 11
                            }

                            StyledText {
                                text: SysInfo.wmDisplay || "Hyprland · Wayland"
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

                            StyledText {
                                text: qsTr("FRAMEWORK & TARGET")
                                color: Colours.palette.m3onSurfaceVariant
                                font.weight: Font.Medium
                                font.letterSpacing: 0.8
                                font.pixelSize: 11
                            }

                            StyledText {
                                text: SysInfo.frameworkDisplay || ("Qt " + (typeof Qt !== "undefined" && Qt.version ? Qt.version : "6.9") + " · QML · Hyprland IPC")
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
                spacing: 18

                // --- CARD 1: SPECIFICATIONS ---
                StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    implicitHeight: Math.max(hwCol.implicitHeight, maintCol.implicitHeight) + 44
                    radius: 20 // M3Shapes.large
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
                    border.color: "transparent"
                    border.width: 0

                    ColumnLayout {
                        id: hwCol
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 22
                        spacing: 18

                        // Header: Specifications
                        RowLayout {
                            spacing: 10

                            MaterialShape {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 32
                                implicitHeight: 32
                                implicitSize: 32
                                shape: MaterialShape.Sunny
                                color: Colours.palette.m3primary

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "memory"
                                    color: Colours.palette.m3onPrimary
                                    iconPointSize: 15
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            StyledText {
                                text: qsTr("Specifications")
                                color: Colours.palette.m3onSurface
                                font.weight: Font.DemiBold
                                textPointSize: 15
                            }
                        }

                        // CPU Item
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            StyledText {
                                text: qsTr("CPU")
                                color: Colours.palette.m3onSurfaceVariant
                                font.weight: Font.Medium
                                font.letterSpacing: 0.8
                                font.pixelSize: 11
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

                            StyledText {
                                text: qsTr("GPU")
                                color: Colours.palette.m3onSurfaceVariant
                                font.weight: Font.Medium
                                font.letterSpacing: 0.8
                                font.pixelSize: 11
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

                                StyledText {
                                    text: qsTr("RAM")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.weight: Font.Medium
                                    font.letterSpacing: 0.8
                                    font.pixelSize: 11
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
                                        implicitWidth: ramBadge.implicitWidth + 18
                                        implicitHeight: 22
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

                            // RAM Usage Progress Bar (Full Width with Contrasting Track)
                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: 6
                                radius: Tokens.rounding.full
                                color: Qt.alpha(Colours.palette.m3onSurface, 0.10)
                                clip: true

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: Math.round(parent.width * Math.min(1.0, Math.max(0.04, (root.memPercInt / 100.0))))
                                    radius: parent.radius
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

                                StyledText {
                                    text: qsTr("STORAGE (Root /)")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.weight: Font.Medium
                                    font.letterSpacing: 0.8
                                    font.pixelSize: 11
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
                                        implicitWidth: storeBadge.implicitWidth + 18
                                        implicitHeight: 22
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

                            // Storage Usage Progress Bar (Full Width with Contrasting Track)
                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: 6
                                radius: Tokens.rounding.full
                                color: Qt.alpha(Colours.palette.m3onSurface, 0.10)
                                clip: true

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: Math.round(parent.width * Math.min(1.0, Math.max(0.04, (root.storagePercInt / 100.0))))
                                    radius: parent.radius
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
                    implicitHeight: Math.max(hwCol.implicitHeight, maintCol.implicitHeight) + 44
                    radius: 20 // M3Shapes.large
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
                    border.color: "transparent"
                    border.width: 0

                    ColumnLayout {
                        id: maintCol
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 22
                        spacing: 18

                        // Header: Maintainer
                        RowLayout {
                            spacing: 10

                            MaterialShape {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 32
                                implicitHeight: 32
                                implicitSize: 32
                                shape: MaterialShape.Clover4Leaf
                                color: Colours.palette.m3primary

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "verified_user"
                                    color: Colours.palette.m3onPrimary
                                    iconPointSize: 15
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            StyledText {
                                text: qsTr("Maintainer")
                                color: Colours.palette.m3onSurface
                                font.weight: Font.DemiBold
                                textPointSize: 15
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
                                color: profileArea.containsMouse 
                                    ? (Colours.light ? Qt.alpha(Colours.palette.m3primary, 0.20) : Qt.alpha(Colours.palette.m3primary, 0.25)) 
                                    : (Colours.light ? Qt.alpha(Colours.palette.m3primary, 0.12) : Qt.alpha(Colours.palette.m3primary, 0.15))
                                border.color: Colours.light 
                                    ? Qt.alpha(Colours.palette.m3outlineVariant, 0.45) 
                                    : Qt.alpha(Colours.palette.m3primary, 0.35)
                                border.width: avatarImg.status === Image.Ready ? 1.5 : 0
                                clip: true

                                Behavior on color { CAnim {} }
                                Behavior on border.color { CAnim {} }

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
                                        color: "white"
                                        antialiasing: true
                                        smooth: true
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
                                        maskSpreadAtMin: 1
                                        maskThresholdMin: 0.5
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

                        // Contact Links List (Aligned Squircle Icons & M3 Sub-cards)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // GitHub Repository Link
                            StyledRect {
                                id: repoCard
                                Layout.fillWidth: true
                                implicitHeight: 52
                                radius: 12
                                color: repoArea.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.10) : Qt.alpha(Colours.palette.m3onSurface, 0.05)
                                border.width: 0
                                border.color: "transparent"

                                Behavior on color { CAnim {} }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 14
                                    spacing: 12

                                    MaterialShape {
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitWidth: 38
                                        implicitHeight: 38
                                        implicitSize: 38
                                        shape: MaterialShape.SoftBurst
                                        color: Colours.palette.m3primary

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            text: "code"
                                            color: Colours.palette.m3onPrimary
                                            iconPointSize: 17
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 2

                                        StyledText {
                                            text: qsTr("Repository")
                                            color: Colours.palette.m3onSurface
                                            font.weight: Font.DemiBold
                                            textPointSize: Tokens.font.size.small
                                        }
                                        StyledText {
                                            text: "github.com/MHMNR/Olvex"
                                            color: Colours.palette.m3onSurfaceVariant
                                            font.family: Tokens.font.family.mono
                                            font.weight: Font.Medium
                                            textPointSize: (Tokens.font.size.smaller) - 1
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    MaterialIcon {
                                        Layout.alignment: Qt.AlignVCenter
                                        text: "open_in_new"
                                        color: repoArea.containsMouse ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                        iconPointSize: 14
                                        Behavior on color { CAnim {} }
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
                                implicitHeight: 52
                                radius: 12
                                color: cfgArea.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.10) : Qt.alpha(Colours.palette.m3onSurface, 0.05)
                                border.width: 0
                                border.color: "transparent"

                                Behavior on color { CAnim {} }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 14
                                    spacing: 12

                                    MaterialShape {
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitWidth: 38
                                        implicitHeight: 38
                                        implicitSize: 38
                                        shape: MaterialShape.Cookie4Sided
                                        color: Colours.palette.m3primary

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            text: "folder_open"
                                            color: Colours.palette.m3onPrimary
                                            iconPointSize: 17
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 2

                                        StyledText {
                                            text: qsTr("Config Directory")
                                            color: Colours.palette.m3onSurface
                                            font.weight: Font.DemiBold
                                            textPointSize: Tokens.font.size.small
                                        }
                                        StyledText {
                                            text: "~/.config/olvex"
                                            color: Colours.palette.m3onSurfaceVariant
                                            font.family: Tokens.font.family.mono
                                            font.weight: Font.Medium
                                            textPointSize: (Tokens.font.size.smaller) - 1
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    MaterialIcon {
                                        Layout.alignment: Qt.AlignVCenter
                                        text: "chevron_right"
                                        color: cfgArea.containsMouse ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                        iconPointSize: 16
                                        Behavior on color { CAnim {} }
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
                                implicitHeight: 52
                                radius: 12
                                color: issueArea.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.10) : Qt.alpha(Colours.palette.m3onSurface, 0.05)
                                border.width: 0
                                border.color: "transparent"

                                Behavior on color { CAnim {} }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 14
                                    spacing: 12

                                    MaterialShape {
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitWidth: 38
                                        implicitHeight: 38
                                        implicitSize: 38
                                        shape: MaterialShape.Gem
                                        color: Colours.palette.m3primary

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            text: "bug_report"
                                            color: Colours.palette.m3onPrimary
                                            iconPointSize: 17
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 2

                                        StyledText {
                                            text: qsTr("Report Issue")
                                            color: Colours.palette.m3onSurface
                                            font.weight: Font.DemiBold
                                            textPointSize: Tokens.font.size.small
                                        }
                                        StyledText {
                                            text: "github.com/MHMNR/Olvex/issues"
                                            color: Colours.palette.m3onSurfaceVariant
                                            font.family: Tokens.font.family.mono
                                            font.weight: Font.Medium
                                            textPointSize: (Tokens.font.size.smaller) - 1
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    MaterialIcon {
                                        Layout.alignment: Qt.AlignVCenter
                                        text: "open_in_new"
                                        color: issueArea.containsMouse ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                        iconPointSize: 14
                                        Behavior on color { CAnim {} }
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
