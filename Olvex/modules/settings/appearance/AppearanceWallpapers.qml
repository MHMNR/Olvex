pragma ComponentBehavior: Bound


import ".."
import "../ui"
import "../components"
import "../../../components"
import "../../olvex/settings/components" as OlvexWp
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
    
    property string wallpaperMode: Wallpapers.isVideoPath(Wallpapers.actualCurrent) ? "live" : "static"
    readonly property var transitionTypes: ["fade", "wipe", "disc", "stripes", "iris", "pixelate", "portal", "random"]
    readonly property var clockPositions: ["middle-center", "top-left", "top-center", "top-right", "middle-left", "middle-right", "bottom-left", "bottom-center", "bottom-right"]

    function idxOf(list, val) {
        for (let i = 0; i < list.length; i++) {
            if (list[i] === val) return i;
        }
        return 0;
    }

    function setWallpaperMode(mode: string): void {
        root.wallpaperMode = mode === "live" ? "live" : "static";
        if (GlobalConfig.background?.liveWallpaper)
            GlobalConfig.background.liveWallpaper.enabled = root.wallpaperMode === "live";
        GlobalConfig.save();
        Wallpapers.ensureCatalog();
    }
    
    Component.onCompleted: {
        Wallpapers.ensureCatalog();
        if (Wallpapers.isVideoPath(Wallpapers.actualCurrent))
            root.wallpaperMode = "live";
        else if (GlobalConfig.background?.liveWallpaper?.enabled && Wallpapers.liveEntryObjects?.length > 0)
            root.wallpaperMode = "live";
        else
            root.wallpaperMode = "static";
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

        SettingRow {
            title: qsTr("Source")
            description: qsTr("Static images or live video backgrounds")
            Segmented {
                id: sourceSeg
                minSegmentWidth: 88
                model: [{
                        label: qsTr("Static"),
                        icon: "image"
                    }, {
                        label: qsTr("Live"),
                        icon: "movie"
                    }]
                currentIndex: root.wallpaperMode === "live" ? 1 : 0
                onSelected: i => root.setWallpaperMode(i === 1 ? "live" : "static")
            }
        }
        
        SettingRow {
            title: qsTr("Turn off live wallpaper audio")
            description: qsTr("Silence sound from the video wallpaper")
            visible: root.wallpaperMode === "live"
            StyledSwitch {
                checked: GlobalConfig.background.liveWallpaper?.muted ?? true
                onToggled: {
                    if (GlobalConfig.background?.liveWallpaper)
                        GlobalConfig.background.liveWallpaper.muted = checked;
                    GlobalConfig.save();
                }
            }
        }

        Item {
            width: parent.width
            height: wallGrid.implicitHeight

            OlvexWp.WallpaperGrid {
                id: wallGrid
                anchors.fill: parent
                session: root.session
                mode: root.wallpaperMode
                columnsCount: 5
                visibleRows: 3
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
                currentIndex: root.idxOf(root.transitionTypes, GlobalConfig.background.wallpaperTransition?.type || "random")
                onSelected: i => {
                    GlobalConfig.background.wallpaperTransition.type = root.transitionTypes[i];
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Duration")
            description: qsTr("How long the transition lasts (ms)")
            CustomSpinBox {
                value: GlobalConfig.background.wallpaperTransition?.duration ?? 1000
                min: 200
                max: 3000
                step: 100
                onValueModified: v => {
                    GlobalConfig.background.wallpaperTransition.duration = v;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Edge smoothness")
            description: qsTr("Softness of the transition boundary")
            divider: false
            StyledSlider {
                width: 220
                from: 0
                to: 0.3
                value: GlobalConfig.background.wallpaperTransition?.edgeSmoothness ?? 0.1
                onMoved: {
                    GlobalConfig.background.wallpaperTransition.edgeSmoothness = value;
                    GlobalConfig.save();
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
                checked: GlobalConfig.background.wallpaperCycling?.enabled ?? false
                onToggled: {
                    GlobalConfig.background.wallpaperCycling.enabled = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Interval")
            description: qsTr("Seconds between changes")
            CustomSpinBox {
                value: GlobalConfig.background.wallpaperCycling?.intervalSeconds ?? 300
                min: 30
                max: 3600
                step: 30
                onValueModified: v => {
                    GlobalConfig.background.wallpaperCycling.intervalSeconds = v;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Shuffle order")
            description: qsTr("Randomize the sequence")
            StyledSwitch {
                checked: GlobalConfig.background.wallpaperCycling?.shuffle ?? true
                onToggled: {
                    GlobalConfig.background.wallpaperCycling.shuffle = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Pause on fullscreen")
            description: qsTr("Stop cycling when an app is fullscreen")
            divider: false
            StyledSwitch {
                checked: GlobalConfig.background.wallpaperCycling?.pauseOnFullscreen ?? true
                onToggled: {
                    GlobalConfig.background.wallpaperCycling.pauseOnFullscreen = checked;
                    GlobalConfig.save();
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
                checked: GlobalConfig.background?.desktopClock?.enabled ?? false
                onToggled: {
                    if (GlobalConfig.background?.desktopClock) {
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
                currentIndex: root.idxOf(root.clockPositions, GlobalConfig.background?.desktopClock?.position || "bottom-right")
                onSelected: i => {
                    if (GlobalConfig.background?.desktopClock) {
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
                width: 220
                from: 0.5
                to: 3.0
                value: GlobalConfig.background?.desktopClock?.scale ?? 1.0
                onMoved: {
                    if (GlobalConfig.background?.desktopClock) {
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
                checked: GlobalConfig.background?.desktopClock?.invertColors ?? false
                onToggled: {
                    if (GlobalConfig.background?.desktopClock) {
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
        title: qsTr("Wallpaper Source")
        description: qsTr("Directory containing your static wallpapers")
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
