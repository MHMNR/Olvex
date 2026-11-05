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
import qs.utils
import qs.components.filedialog

ColumnLayout {
    id: root
    
    property Session session
    spacing: Tokens.spacing.large
    opacity: 0.0
    transform: Translate { y: 20; id: yTrans }

    Component.onCompleted: {
        revealAnim.start();
        Wallpapers.ensureCatalog();
        if (Wallpapers.isVideoPath(Wallpapers.actualCurrent)) {
            root.wallpaperMode = "live";
        } else if (GlobalConfig.background && GlobalConfig.background.liveWallpaper && GlobalConfig.background.liveWallpaper.enabled && Wallpapers.liveEntryObjects && Wallpapers.liveEntryObjects.length > 0) {
            root.wallpaperMode = "live";
        } else {
            root.wallpaperMode = "static";
        }
    }

    ParallelAnimation {
        id: revealAnim
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: 400; easing.type: Easing.OutCubic }
        NumberAnimation { target: yTrans; property: "y"; to: 0; duration: 400; easing.type: Easing.OutCubic }
    }
    
    property string wallpaperMode: Wallpapers.isVideoPath(Wallpapers.actualCurrent) ? "live" : "static"
    readonly property var transitionTypes: ["fade", "wipe", "disc", "stripes", "iris", "pixelate", "portal", "random"]
    readonly property var clockPositions: ["middle-center", "top-left", "top-center", "top-right", "middle-left", "middle-right", "bottom-left", "bottom-center", "bottom-right"]

    function idxOf(list, val) {
        for (let i = 0; i < list.length; i++) {
            if (list[i] === val) return i;
        }
        return 0;
    }

    function setWallpaperMode(mode) {
        root.wallpaperMode = mode === "live" ? "live" : "static";
        if (GlobalConfig.background && GlobalConfig.background.liveWallpaper)
            GlobalConfig.background.liveWallpaper.enabled = root.wallpaperMode === "live";
        Wallpapers.ensureCatalog();
    }

    Section {
        Layout.fillWidth: true
        title: qsTr("General")
        description: root.wallpaperMode === "live" ? qsTr("Video wallpapers from ~/Pictures/Wallpapers/Live") : qsTr("Still images from your wallpaper folder")
        icon: "image"

        SettingRow {
            title: qsTr("Turn on/off olvex walls")
            description: qsTr("Draw the selected wallpaper on the desktop")
            StyledSwitch {
                checked: GlobalConfig.background.wallpaperEnabled
                onToggled: {
                    GlobalConfig.background.wallpaperEnabled = checked;
                    GlobalConfig.save();
                }
            }
        }

        // Unified Wallpaper Type & Grid Card
        StyledRect {
            id: wallpaperPickerCard
            Layout.fillWidth: true
            implicitWidth: parent ? parent.width : 0
            width: parent ? parent.width : implicitWidth

            // Group position flags for Section.qml connected stack
            property bool isFirstInGroup: false
            property bool isLastInGroup: false
            property bool isSingleInGroup: false

            readonly property real topR: (isSingleInGroup || isFirstInGroup) ? 22 : 6
            readonly property real bottomR: (isSingleInGroup || isLastInGroup) ? 22 : 6
            topLeftRadius: topR
            topRightRadius: topR
            bottomLeftRadius: bottomR
            bottomRightRadius: bottomR

            color: Colours.palette.m3surfaceContainerHigh
            border.width: 0

            implicitHeight: cardContent.implicitHeight + 28

            ColumnLayout {
                id: cardContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 14
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                // Header: Professional title + description + segmented selector
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    Column {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            width: parent.width
                            text: qsTr("Wallpaper Type")
                            font.weight: Font.DemiBold
                            font.letterSpacing: -0.1
                            color: Colours.palette.m3onSurface
                            textPointSize: Tokens.font.size.normal
                        }

                        StyledText {
                            width: parent.width
                            text: qsTr("Static images or live video backgrounds")
                            color: Colours.palette.m3onSurfaceVariant
                            font.weight: Font.Normal
                            font.letterSpacing: 0.1
                            textPointSize: Tokens.font.size.small
                        }
                    }

                    Segmented {
                        id: sourceSeg
                        minSegmentWidth: 88
                        model: [{
                                label: qsTr("Static")
                            }, {
                                label: qsTr("Live")
                            }]
                        currentIndex: root.wallpaperMode === "live" ? 1 : 0
                        onSelected: i => root.setWallpaperMode(i === 1 ? "live" : "static")
                    }
                }

                // Live wallpaper mute toggle (only visible in live mode)
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.wallpaperMode === "live"
                    spacing: 16

                    Column {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            width: parent.width
                            text: qsTr("Turn off live wallpaper audio")
                            font.weight: Font.DemiBold
                            color: Colours.palette.m3onSurface
                            textPointSize: Tokens.font.size.normal
                        }

                        StyledText {
                            width: parent.width
                            text: qsTr("Silence sound from the video wallpaper")
                            color: Colours.palette.m3onSurfaceVariant
                            textPointSize: Tokens.font.size.small
                        }
                    }

                    StyledSwitch {
                        checked: (GlobalConfig.background && GlobalConfig.background.liveWallpaper && GlobalConfig.background.liveWallpaper.muted !== undefined)
                                 ? GlobalConfig.background.liveWallpaper.muted
                                 : true
                        onToggled: {
                            if (GlobalConfig.background && GlobalConfig.background.liveWallpaper) {
                                GlobalConfig.background.liveWallpaper.muted = checked;
                                GlobalConfig.save();
                            }
                        }
                    }
                }

                // Integrated Wallpaper Thumbnail Grid
                WallpaperGrid {
                    id: wallGrid
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    session: root.session
                    mode: root.wallpaperMode
                    columnsCount: 5
                    visibleRows: 3
                }
            }
        }
        
        SettingRow {
            title: qsTr("Per-monitor wallpaper")
            description: qsTr("Use an independent wallpaper on each display")
            divider: false
            StyledSwitch {
                checked: GlobalConfig.background.perMonitorWallpaper
                onToggled: {
                    GlobalConfig.background.perMonitorWallpaper = checked;
                    GlobalConfig.save();
                }
            }
        }
    }
    
    Section {
        Layout.fillWidth: true
        title: qsTr("Transition")
        description: qsTr("Animation when the wallpaper changes")
        icon: "transition_fade"

        SettingRow {
            title: qsTr("Transition type")
            description: qsTr("Visual effect used to swap wallpapers")
            OptionPicker {
                model: root.transitionTypes
                currentIndex: root.idxOf(root.transitionTypes, (GlobalConfig.background.wallpaperTransition && GlobalConfig.background.wallpaperTransition.type) ? GlobalConfig.background.wallpaperTransition.type : "random")
                onSelected: i => {
                    if (GlobalConfig.background && GlobalConfig.background.wallpaperTransition) {
                        GlobalConfig.background.wallpaperTransition.type = root.transitionTypes[i];
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Duration")
            description: qsTr("How long the transition lasts (ms)")
            CustomSpinBox {
                value: (GlobalConfig.background.wallpaperTransition && GlobalConfig.background.wallpaperTransition.duration !== undefined) ? GlobalConfig.background.wallpaperTransition.duration : 1000
                min: 200
                max: 3000
                step: 100
                onValueModified: v => {
                    if (GlobalConfig.background && GlobalConfig.background.wallpaperTransition) {
                        GlobalConfig.background.wallpaperTransition.duration = v;
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Edge smoothness")
            description: qsTr("Softness of the transition boundary")
            divider: false
            StyledSlider {
                width: 260
                from: 0
                to: 0.3
                value: (GlobalConfig.background.wallpaperTransition && GlobalConfig.background.wallpaperTransition.edgeSmoothness !== undefined) ? GlobalConfig.background.wallpaperTransition.edgeSmoothness : 0.1
                onMoved: {
                    if (GlobalConfig.background && GlobalConfig.background.wallpaperTransition) {
                        GlobalConfig.background.wallpaperTransition.edgeSmoothness = value;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }
    
    Section {
        Layout.fillWidth: true
        title: qsTr("Cycling")
        description: qsTr("Automatically rotate through wallpapers")
        icon: "autorenew"

        SettingRow {
            title: qsTr("Auto-cycle wallpapers")
            description: qsTr("Switch on a schedule")
            StyledSwitch {
                checked: (GlobalConfig.background.wallpaperCycling && GlobalConfig.background.wallpaperCycling.enabled !== undefined) ? GlobalConfig.background.wallpaperCycling.enabled : false
                onToggled: {
                    if (GlobalConfig.background && GlobalConfig.background.wallpaperCycling) {
                        GlobalConfig.background.wallpaperCycling.enabled = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Interval")
            description: qsTr("Seconds between changes")
            CustomSpinBox {
                value: (GlobalConfig.background.wallpaperCycling && GlobalConfig.background.wallpaperCycling.intervalSeconds !== undefined) ? GlobalConfig.background.wallpaperCycling.intervalSeconds : 300
                min: 30
                max: 3600
                step: 30
                onValueModified: v => {
                    if (GlobalConfig.background && GlobalConfig.background.wallpaperCycling) {
                        GlobalConfig.background.wallpaperCycling.intervalSeconds = v;
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Shuffle order")
            description: qsTr("Randomize the sequence")
            StyledSwitch {
                checked: (GlobalConfig.background.wallpaperCycling && GlobalConfig.background.wallpaperCycling.shuffle !== undefined) ? GlobalConfig.background.wallpaperCycling.shuffle : true
                onToggled: {
                    if (GlobalConfig.background && GlobalConfig.background.wallpaperCycling) {
                        GlobalConfig.background.wallpaperCycling.shuffle = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Pause on fullscreen")
            description: qsTr("Stop cycling when an app is fullscreen")
            divider: false
            StyledSwitch {
                checked: (GlobalConfig.background.wallpaperCycling && GlobalConfig.background.wallpaperCycling.pauseOnFullscreen !== undefined) ? GlobalConfig.background.wallpaperCycling.pauseOnFullscreen : true
                onToggled: {
                    if (GlobalConfig.background && GlobalConfig.background.wallpaperCycling) {
                        GlobalConfig.background.wallpaperCycling.pauseOnFullscreen = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }
    
    Section {
        Layout.fillWidth: true
        title: qsTr("Desktop Clock")
        description: qsTr("Large time display on the background")
        icon: "schedule"

        SettingRow {
            title: qsTr("Show desktop clock")
            description: qsTr("Draw the time over the wallpaper")
            StyledSwitch {
                checked: (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.enabled !== undefined) ? GlobalConfig.background.desktopClock.enabled : false
                onToggled: {
                    if (GlobalConfig.background && GlobalConfig.background.desktopClock) {
                        GlobalConfig.background.desktopClock.enabled = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Position")
            description: qsTr("Where the clock is anchored")
            OptionPicker {
                model: root.clockPositions
                currentIndex: root.idxOf(root.clockPositions, (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.position) ? GlobalConfig.background.desktopClock.position : "bottom-right")
                onSelected: i => {
                    if (GlobalConfig.background && GlobalConfig.background.desktopClock) {
                        GlobalConfig.background.desktopClock.position = root.clockPositions[i];
                        GlobalConfig.save();
                    }
                }
            }
        }
        
        SettingRow {
            title: qsTr("Scale")
            description: qsTr("Size of the clock text")
            StyledSlider {
                width: 260
                from: 0.5
                to: 3.0
                value: (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.scale !== undefined) ? GlobalConfig.background.desktopClock.scale : 1.0
                onMoved: {
                    if (GlobalConfig.background && GlobalConfig.background.desktopClock) {
                        GlobalConfig.background.desktopClock.scale = value;
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Invert color")
            description: qsTr("Force dark text instead of light")
            divider: false
            StyledSwitch {
                checked: (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.invertColors !== undefined) ? GlobalConfig.background.desktopClock.invertColors : false
                onToggled: {
                    if (GlobalConfig.background && GlobalConfig.background.desktopClock) {
                        GlobalConfig.background.desktopClock.invertColors = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }
    
    readonly property FileDialog wallpaperDirPicker: FileDialog {
        title: qsTr("Select Wallpaper Directory")
        filterLabel: qsTr("Folders")
        filters: ["*"]
        initialCwd: ["Home", "Pictures", "Wallpapers"]
        resetCwdOnOpen: true

        onAccepted: path => {
            let dirPath = path;
            if (dirPath.includes(".")) {
                const parts = dirPath.split("/");
                parts.pop();
                dirPath = parts.join("/");
            }
            GlobalConfig.paths.wallpaperDir = dirPath;
            GlobalConfig.save();
            Wallpapers.ensureCatalog();
            Quickshell.execDetached(["notify-send", "-a", "olvex-shell", "-u", "low", qsTr("Wallpaper directory updated"), qsTr("Set to %1").arg(dirPath)]);
        }
    }

    Section {
        Layout.fillWidth: true
        title: qsTr("Wallpaper Directory")
        description: qsTr("Folder containing your static wallpapers")
        icon: "folder"

        SettingRow {
            title: qsTr("Default Directory")
            description: GlobalConfig.paths.wallpaperDir || qsTr("~/Pictures/Wallpapers")
            divider: false
            IconTextButton {
                icon: "edit"
                text: qsTr("Change")
                type: IconTextButton.Filled
                onClicked: root.wallpaperDirPicker.open()
            }
        }
    }
}
