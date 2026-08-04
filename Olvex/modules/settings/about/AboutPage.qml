import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import M3Shapes
import Olvex.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils
import "../chrome"

SettingsPage {
    id: root

    property var session

    title: qsTr("About")
    subtitle: qsTr("System specifications, version info and project links")
    icon: "info"
    accent: Colours.palette.m3tertiary

    // ── Hero Banner Card ──
    StyledRect {
        Layout.fillWidth: true
        implicitHeight: 180
        radius: Tokens.rounding.large
        color: Colours.layer(Colours.palette.m3surfaceContainerLow, 2)

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.alpha(Colours.palette.m3tertiary, 0.08)
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large * 1.5
            spacing: Tokens.spacing.large

            // Pure Animated Olvex Logo Emblem (M3 Expressive Motion Physics)
            Item {
                id: logoContainer
                Layout.preferredWidth: 100
                Layout.preferredHeight: 100
                Layout.alignment: Qt.AlignVCenter

                Component.onCompleted: logoEntranceAnim.start()

                // Scaled inner wrapper around artwork bounding box (160x128)
                Item {
                    id: markArt
                    anchors.centerIn: parent
                    width: 160
                    height: 128

                    readonly property real baseScale: Math.min(logoContainer.width / width, logoContainer.height / height)
                    property real hoverScale: logoMouseArea.containsMouse ? 1.06 : 1.0
                    property real clickScale: 1.0
                    property real clickYOffset: 0

                    scale: baseScale * hoverScale * clickScale
                    anchors.verticalCenterOffset: clickYOffset

                    // M3 Expressive Fast Spatial Spring (hover scale pop)
                    Behavior on hoverScale { SpringAnimation { spring: 4.2; damping: 0.70 } }

                    // 1. Left Indigo Beam (#675FFF)
                    Item {
                        id: leftBeamContainer
                        width: 240
                        height: 240
                        x: -36
                        y: -82
                        opacity: 0
                        rotation: -20
                        transformOrigin: Item.BottomLeft

                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                strokeColor: "#675FFF"
                                strokeWidth: 28
                                capStyle: ShapePath.RoundCap
                                fillColor: "transparent"

                                PathSvg {
                                    path: "M58,190 L103,96"
                                }
                            }
                        }
                    }

                    // 2. Right Coral Beam (#FF8A5B)
                    Item {
                        id: rightBeamContainer
                        width: 240
                        height: 240
                        x: -36
                        y: -82
                        opacity: 0
                        rotation: 20
                        transformOrigin: Item.BottomRight

                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                strokeColor: "#FF8A5B"
                                strokeWidth: 28
                                capStyle: ShapePath.RoundCap
                                fillColor: "transparent"

                                PathSvg {
                                    path: "M182,190 L137,96"
                                }
                            }
                        }
                    }

                    // 3. Wavy Signal Line (OnSurface)
                    Item {
                        id: waveContainer
                        width: 240
                        height: 240
                        x: -36
                        y: -82
                        opacity: 0
                        scale: 0.1
                        transformOrigin: Item.Center

                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                strokeColor: Colours.palette.m3onSurface
                                strokeWidth: 8
                                capStyle: ShapePath.RoundCap
                                fillColor: "transparent"

                                PathSvg {
                                    path: "M40,206 C70,192 90,220 120,206 C150,192 170,220 200,206"
                                }
                            }
                        }
                    }
                }

                // --- Entrance Animation Sequence (M3 Emphasized & Spring Physics) ---
                SequentialAnimation {
                    id: logoEntranceAnim

                    ParallelAnimation {
                        NumberAnimation { target: leftBeamContainer; property: "opacity"; to: 1.0; duration: 350; easing.type: Easing.OutCubic }
                        NumberAnimation { target: leftBeamContainer; property: "rotation"; to: 0; duration: 450; easing.type: Easing.OutBack }
                    }

                    ParallelAnimation {
                        NumberAnimation { target: rightBeamContainer; property: "opacity"; to: 1.0; duration: 350; easing.type: Easing.OutCubic }
                        NumberAnimation { target: rightBeamContainer; property: "rotation"; to: 0; duration: 450; easing.type: Easing.OutBack }
                    }

                    ParallelAnimation {
                        NumberAnimation { target: waveContainer; property: "opacity"; to: 1.0; duration: 300; easing.type: Easing.OutCubic }
                        NumberAnimation { target: waveContainer; property: "scale"; to: 1.0; duration: 550; easing.type: Easing.OutBack }
                    }

                    ScriptAction {
                        script: idleBreathing.start()
                    }
                }

                // --- Idle Floating / Breathing Micro-motion ---
                SequentialAnimation {
                    id: idleBreathing
                    loops: Animation.Infinite

                    ParallelAnimation {
                        NumberAnimation { target: waveContainer; property: "scale"; to: 1.03; duration: 2200; easing.type: Easing.InOutSine }
                    }
                    ParallelAnimation {
                        NumberAnimation { target: waveContainer; property: "scale"; to: 0.97; duration: 2200; easing.type: Easing.InOutSine }
                    }
                }

                // --- Interactive Mouse Area (Hover & Click) ---
                MouseArea {
                    id: logoMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        logoClickAnim.restart();
                    }
                }

                // --- M3 Spring Press & Elastic Bounce Click Animation ---
                SequentialAnimation {
                    id: logoClickAnim

                    ParallelAnimation {
                        NumberAnimation { target: markArt; property: "clickScale"; to: 0.94; duration: 70; easing.type: Easing.OutCubic }
                        NumberAnimation { target: markArt; property: "clickYOffset"; to: 2; duration: 70; easing.type: Easing.OutCubic }
                        NumberAnimation { target: leftBeamContainer; property: "rotation"; to: 3; duration: 70; easing.type: Easing.OutCubic }
                        NumberAnimation { target: rightBeamContainer; property: "rotation"; to: -3; duration: 70; easing.type: Easing.OutCubic }
                        NumberAnimation { target: waveContainer; property: "scale"; to: 0.92; duration: 70; easing.type: Easing.OutCubic }
                    }

                    ParallelAnimation {
                        NumberAnimation { target: markArt; property: "clickScale"; to: 1.04; duration: 200; easing.type: Easing.OutBack }
                        NumberAnimation { target: markArt; property: "clickYOffset"; to: -2; duration: 200; easing.type: Easing.OutBack }
                        NumberAnimation { target: leftBeamContainer; property: "rotation"; to: -3; duration: 200; easing.type: Easing.OutBack }
                        NumberAnimation { target: rightBeamContainer; property: "rotation"; to: 3; duration: 200; easing.type: Easing.OutBack }
                        NumberAnimation { target: waveContainer; property: "scale"; to: 1.06; duration: 200; easing.type: Easing.OutBack }
                    }

                    ParallelAnimation {
                        NumberAnimation { target: markArt; property: "clickScale"; to: 1.0; duration: 150; easing.type: Easing.OutCubic }
                        NumberAnimation { target: markArt; property: "clickYOffset"; to: 0; duration: 150; easing.type: Easing.OutCubic }
                        NumberAnimation { target: leftBeamContainer; property: "rotation"; to: 0; duration: 150; easing.type: Easing.OutCubic }
                        NumberAnimation { target: rightBeamContainer; property: "rotation"; to: 0; duration: 150; easing.type: Easing.OutCubic }
                        NumberAnimation { target: waveContainer; property: "scale"; to: 1.0; duration: 150; easing.type: Easing.OutCubic }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                RowLayout {
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: "Olvex Desktop Shell"
                        font.weight: Font.Bold
                        font.letterSpacing: -0.4
                        color: Colours.palette.m3onSurface
                        textPointSize: Tokens.font.size.extraLarge
                    }

                    StyledRect {
                        implicitWidth: verText.implicitWidth + 16
                        implicitHeight: 22
                        radius: height / 2
                        color: Qt.alpha(Colours.palette.m3primary, 0.16)
                        border.color: Qt.alpha(Colours.palette.m3primary, 0.3)
                        border.width: 1

                        StyledText {
                            id: verText
                            anchors.centerIn: parent
                            text: "v2026.6"
                            font.weight: Font.DemiBold
                            color: Colours.palette.m3primary
                            textPointSize: Tokens.font.size.extraSmall
                        }
                    }
                }

                StyledText {
                    text: qsTr("A Material 3 Expressive desktop environment crafted for Hyprland and Wayland.")
                    color: Colours.palette.m3onSurfaceVariant
                    font.weight: Font.Normal
                    font.letterSpacing: 0.1
                    lineHeight: 1.25
                    lineHeightMode: Text.ProportionalHeight
                    textPointSize: Tokens.font.size.normal
                    Layout.fillWidth: true
                }

                Row {
                    Layout.topMargin: Tokens.spacing.small
                    spacing: Tokens.spacing.small

                    Repeater {
                        model: ["Qt 6.7", "Quickshell Engine", "Hyprland IPC", "M3 Expressive"]

                        delegate: StyledRect {
                            required property string modelData
                            implicitWidth: tagLbl.implicitWidth + 18
                            implicitHeight: 24
                            radius: Tokens.rounding.full
                            color: Colours.palette.m3surfaceContainerHigh

                            StyledText {
                                id: tagLbl
                                anchors.centerIn: parent
                                text: parent.modelData
                                color: Colours.palette.m3onSurfaceVariant
                                font.weight: Font.Medium
                                textPointSize: Tokens.font.size.extraSmall
                            }
                        }
                    }
                }
            }
        }
    }

    // ── System Information Section (Bento Grid Redesign) ──
    Section {
        Layout.fillWidth: true
        title: qsTr("System Specs")
        description: qsTr("Hardware, distribution and display environment details")
        icon: "computer"

        Item {
            width: parent ? parent.width : 600
            implicitHeight: gridLayout.implicitHeight + Tokens.spacing.small

            GridLayout {
                id: gridLayout
                anchors.left: parent.left
                anchors.right: parent.right
                columns: 2
                rowSpacing: Tokens.spacing.medium
                columnSpacing: Tokens.spacing.medium

                // Bento Tile 1: OS Distribution
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 80
                    radius: Tokens.rounding.large
                    color: Colours.layer(Colours.palette.m3surfaceContainerLow, 2)
                    border.color: tile1Hover.hovered ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outlineVariant, 0.3)
                    border.width: 1

                    Behavior on border.color { CAnim {} }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.normal
                        anchors.rightMargin: Tokens.padding.normal
                        anchors.topMargin: Tokens.padding.small
                        anchors.bottomMargin: Tokens.padding.small
                        spacing: Tokens.spacing.normal

                        StyledRect {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            Layout.alignment: Qt.AlignVCenter
                            radius: Tokens.rounding.medium
                            color: Colours.palette.m3primaryContainer

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "computer"
                                color: Colours.palette.m3onPrimaryContainer
                                iconPointSize: Tokens.font.size.large
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            StyledText {
                                text: qsTr("OS Distribution")
                                color: Colours.palette.m3onSurfaceVariant
                                textPointSize: Tokens.font.size.small
                            }
                            StyledText {
                                text: SysInfo.osPrettyName || SysInfo.osName || qsTr("Arch Linux")
                                color: Colours.palette.m3onSurface
                                font.weight: Font.Bold
                                textPointSize: Tokens.font.size.normal
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    HoverHandler { id: tile1Hover }
                }

                // Bento Tile 2: Compositor
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 80
                    radius: Tokens.rounding.large
                    color: Colours.layer(Colours.palette.m3surfaceContainerLow, 2)
                    border.color: tile2Hover.hovered ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outlineVariant, 0.3)
                    border.width: 1

                    Behavior on border.color { CAnim {} }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.normal
                        anchors.rightMargin: Tokens.padding.normal
                        anchors.topMargin: Tokens.padding.small
                        anchors.bottomMargin: Tokens.padding.small
                        spacing: Tokens.spacing.normal

                        StyledRect {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            Layout.alignment: Qt.AlignVCenter
                            radius: Tokens.rounding.medium
                            color: Colours.palette.m3secondaryContainer

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "display_settings"
                                color: Colours.palette.m3onSecondaryContainer
                                iconPointSize: Tokens.font.size.large
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            StyledText {
                                text: qsTr("Compositor")
                                color: Colours.palette.m3onSurfaceVariant
                                textPointSize: Tokens.font.size.small
                            }
                            StyledText {
                                text: (SysInfo.wm || "Hyprland") + " (Wayland)"
                                color: Colours.palette.m3onSurface
                                font.weight: Font.Bold
                                textPointSize: Tokens.font.size.normal
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    HoverHandler { id: tile2Hover }
                }

                // Bento Tile 3: System Uptime
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 80
                    radius: Tokens.rounding.large
                    color: Colours.layer(Colours.palette.m3surfaceContainerLow, 2)
                    border.color: tile3Hover.hovered ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outlineVariant, 0.3)
                    border.width: 1

                    Behavior on border.color { CAnim {} }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.normal
                        anchors.rightMargin: Tokens.padding.normal
                        anchors.topMargin: Tokens.padding.small
                        anchors.bottomMargin: Tokens.padding.small
                        spacing: Tokens.spacing.normal

                        StyledRect {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            Layout.alignment: Qt.AlignVCenter
                            radius: Tokens.rounding.medium
                            color: Colours.palette.m3tertiaryContainer

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "schedule"
                                color: Colours.palette.m3onTertiaryContainer
                                iconPointSize: Tokens.font.size.large
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            StyledText {
                                text: qsTr("System Uptime")
                                color: Colours.palette.m3onSurfaceVariant
                                textPointSize: Tokens.font.size.small
                            }
                            StyledText {
                                text: SysInfo.uptime || qsTr("—")
                                color: Colours.palette.m3onSurface
                                font.weight: Font.Bold
                                textPointSize: Tokens.font.size.normal
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    HoverHandler { id: tile3Hover }
                }

                // Bento Tile 4: Active User
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 80
                    radius: Tokens.rounding.large
                    color: Colours.layer(Colours.palette.m3surfaceContainerLow, 2)
                    border.color: tile4Hover.hovered ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outlineVariant, 0.3)
                    border.width: 1

                    Behavior on border.color { CAnim {} }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.normal
                        anchors.rightMargin: Tokens.padding.normal
                        anchors.topMargin: Tokens.padding.small
                        anchors.bottomMargin: Tokens.padding.small
                        spacing: Tokens.spacing.normal

                        StyledRect {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            Layout.alignment: Qt.AlignVCenter
                            radius: Tokens.rounding.medium
                            color: Colours.palette.m3surfaceContainerHigh

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "person"
                                color: Colours.palette.m3primary
                                iconPointSize: Tokens.font.size.large
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            StyledText {
                                text: qsTr("Active Session")
                                color: Colours.palette.m3onSurfaceVariant
                                textPointSize: Tokens.font.size.small
                            }
                            StyledText {
                                text: (SysInfo.user || "user") + " @ " + (SysInfo.hostname || "localhost")
                                color: Colours.palette.m3onSurface
                                font.weight: Font.Bold
                                textPointSize: Tokens.font.size.normal
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    HoverHandler { id: tile4Hover }
                }
            }
        }
    }

    // ── Quick Actions Section (Interactive Card Redesign) ──
    Section {
        Layout.fillWidth: true
        title: qsTr("Resources & Config")
        description: qsTr("Project repository and configuration files")
        icon: "folder_managed"

        Item {
            width: parent ? parent.width : 600
            implicitHeight: actionsCol.implicitHeight + Tokens.spacing.small

            ColumnLayout {
                id: actionsCol
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Tokens.spacing.medium

                // Action Card 1: GitHub Repository
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 72
                    radius: Tokens.rounding.large
                    color: Colours.layer(Colours.palette.m3surfaceContainerLow, 2)
                    border.color: ghState.containsMouse ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outlineVariant, 0.3)
                    border.width: 1

                    Behavior on border.color { CAnim {} }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.normal
                        anchors.rightMargin: Tokens.padding.normal
                        anchors.topMargin: Tokens.padding.small
                        anchors.bottomMargin: Tokens.padding.small
                        spacing: Tokens.spacing.normal

                        StyledRect {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            Layout.alignment: Qt.AlignVCenter
                            radius: Tokens.rounding.medium
                            color: Colours.palette.m3primaryContainer

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "code"
                                color: Colours.palette.m3onPrimaryContainer
                                iconPointSize: Tokens.font.size.normal
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            StyledText {
                                text: qsTr("GitHub Repository")
                                color: Colours.palette.m3onSurface
                                font.weight: Font.Bold
                                textPointSize: Tokens.font.size.normal
                            }
                            StyledText {
                                text: qsTr("Source code, issue tracker, and release updates")
                                color: Colours.palette.m3onSurfaceVariant
                                textPointSize: Tokens.font.size.small
                                elide: Text.ElideRight
                            }
                        }

                        StyledRect {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: ghBtnText.implicitWidth + 28
                            implicitHeight: 34
                            radius: Tokens.rounding.full
                            color: ghState.containsMouse ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHigh

                            Behavior on color { CAnim {} }

                            Row {
                                anchors.centerIn: parent
                                spacing: Tokens.spacing.small

                                StyledText {
                                    id: ghBtnText
                                    text: qsTr("Open Repo")
                                    color: ghState.containsMouse ? Colours.palette.m3onPrimary : Colours.palette.m3primary
                                    font.weight: Font.DemiBold
                                    textPointSize: Tokens.font.size.small
                                }

                                MaterialIcon {
                                    text: "open_in_new"
                                    color: ghState.containsMouse ? Colours.palette.m3onPrimary : Colours.palette.m3primary
                                    iconPointSize: Tokens.font.size.small
                                }
                            }
                        }
                    }

                    StateLayer {
                        id: ghState
                        anchors.fill: parent
                        radius: parent.radius
                        color: Colours.palette.m3primary
                        onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/olvex-dots/shell"])
                    }
                }

                // Action Card 2: Configuration Folder
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 72
                    radius: Tokens.rounding.large
                    color: Colours.layer(Colours.palette.m3surfaceContainerLow, 2)
                    border.color: cfgState.containsMouse ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outlineVariant, 0.3)
                    border.width: 1

                    Behavior on border.color { CAnim {} }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.normal
                        anchors.rightMargin: Tokens.padding.normal
                        anchors.topMargin: Tokens.padding.small
                        anchors.bottomMargin: Tokens.padding.small
                        spacing: Tokens.spacing.normal

                        StyledRect {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            Layout.alignment: Qt.AlignVCenter
                            radius: Tokens.rounding.medium
                            color: Colours.palette.m3secondaryContainer

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "folder_open"
                                color: Colours.palette.m3onSecondaryContainer
                                iconPointSize: Tokens.font.size.normal
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            StyledText {
                                text: qsTr("Configuration Folder")
                                color: Colours.palette.m3onSurface
                                font.weight: Font.Bold
                                textPointSize: Tokens.font.size.normal
                            }
                            StyledText {
                                text: Paths.config || qsTr("~/.config/olvex")
                                color: Colours.palette.m3onSurfaceVariant
                                textPointSize: Tokens.font.size.small
                                elide: Text.ElideRight
                            }
                        }

                        StyledRect {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: cfgBtnText.implicitWidth + 28
                            implicitHeight: 34
                            radius: Tokens.rounding.full
                            color: cfgState.containsMouse ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHigh

                            Behavior on color { CAnim {} }

                            Row {
                                anchors.centerIn: parent
                                spacing: Tokens.spacing.small

                                StyledText {
                                    id: cfgBtnText
                                    text: qsTr("Explore")
                                    color: cfgState.containsMouse ? Colours.palette.m3onPrimary : Colours.palette.m3primary
                                    font.weight: Font.DemiBold
                                    textPointSize: Tokens.font.size.small
                                }

                                MaterialIcon {
                                    text: "folder"
                                    color: cfgState.containsMouse ? Colours.palette.m3onPrimary : Colours.palette.m3primary
                                    iconPointSize: Tokens.font.size.small
                                }
                            }
                        }
                    }

                    StateLayer {
                        id: cfgState
                        anchors.fill: parent
                        radius: parent.radius
                        color: Colours.palette.m3primary
                        onClicked: Quickshell.execDetached(["xdg-open", Paths.config])
                    }
                }
            }
        }
    }
}
