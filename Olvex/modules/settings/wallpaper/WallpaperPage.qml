pragma ComponentBehavior: Bound

import ".."
import "../chrome"
import "../../olvex/settings/components" as OlvexWp
import QtQuick
import QtQuick.Layouts
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    property Session session
    signal back

    // static | live — drives catalog grid + live playback flag
    property string wallpaperMode: Wallpapers.isVideoPath(Wallpapers.actualCurrent) ? "live" : "static"

    readonly property var transitionTypes: ["fade", "wipe", "disc", "stripes", "iris", "pixelate", "portal", "random"]
    readonly property var clockPositions: ["center", "top-left", "top-right", "bottom-left", "bottom-right"]

    function idxOf(list, val) {
        for (let i = 0; i < list.length; i++) {
            if (list[i] === val)
                return i;
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
        // Prefer current wallpaper type; fall back to config flag
        if (Wallpapers.isVideoPath(Wallpapers.actualCurrent))
            root.wallpaperMode = "live";
        else if (GlobalConfig.background?.liveWallpaper?.enabled && Wallpapers.liveEntryObjects?.length > 0)
            root.wallpaperMode = "live";
        else
            root.wallpaperMode = "static";
    }

    SettingsPage {
        anchors.fill: parent
        title: qsTr("Wallpaper & Desktop")
        subtitle: qsTr("Wallpaper, transitions, desktop clock and visualiser")
        icon: "wallpaper"
        accent: Colours.palette.m3secondary
        onBack: root.back()

        Section {
            title: qsTr("Wallpaper")
            description: root.wallpaperMode === "live" ? qsTr("Video wallpapers from ~/Pictures/Wallpapers/Live") : qsTr("Still images from your wallpaper folder")
            icon: "image"

            SettingRow {
                title: qsTr("Source")
                description: qsTr("Static images or live video backgrounds")
                // Same sliding-pill pattern as utilities Record FPS selector
                Segmented {
                    id: sourceSeg

                    // Content-measured slots; floor keeps icon+label comfortable
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

            // Mode-aware grid — 5×3 viewport
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
                title: qsTr("Show wallpaper")
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
                title: qsTr("Desktop background")
                description: qsTr("Render backdrop when wallpaper is off")
                StyledSwitch {
                    checked: GlobalConfig.background.enabled
                    onToggled: {
                        GlobalConfig.background.enabled = checked;
                        GlobalConfig.save();
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
            title: qsTr("Live wallpaper")
            description: qsTr("Playback options for video wallpapers")
            icon: "movie"
            visible: root.wallpaperMode === "live"

            SettingRow {
                title: qsTr("Enable live playback")
                description: qsTr("Play video wallpapers (off = first frame only)")
                StyledSwitch {
                    checked: GlobalConfig.background.liveWallpaper?.enabled ?? true
                    onToggled: {
                        if (GlobalConfig.background?.liveWallpaper)
                            GlobalConfig.background.liveWallpaper.enabled = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Mute audio")
                description: qsTr("Silence sound from the video wallpaper")
                divider: false
                StyledSwitch {
                    checked: GlobalConfig.background.liveWallpaper?.muted ?? true
                    onToggled: {
                        if (GlobalConfig.background?.liveWallpaper)
                            GlobalConfig.background.liveWallpaper.muted = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            title: qsTr("Transitions")
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
                description: qsTr("Pick the next wallpaper at random")
                StyledSwitch {
                    checked: GlobalConfig.background.wallpaperCycling?.shuffle ?? false
                    onToggled: {
                        GlobalConfig.background.wallpaperCycling.shuffle = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Pause when fullscreen")
                description: qsTr("Hold cycling while an app is fullscreen")
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
            title: qsTr("Desktop clock")
            description: qsTr("Large floating clock on the desktop")
            icon: "schedule"

            SettingRow {
                title: qsTr("Show desktop clock")
                description: qsTr("Display the clock over the wallpaper")
                StyledSwitch {
                    checked: GlobalConfig.background.desktopClock?.enabled ?? false
                    onToggled: {
                        GlobalConfig.background.desktopClock.enabled = checked;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Position")
                description: qsTr("Where the clock sits on screen")
                OptionPicker {
                    model: root.clockPositions
                    currentIndex: root.idxOf(root.clockPositions, GlobalConfig.background.desktopClock?.position || "bottom-right")
                    onSelected: i => {
                        GlobalConfig.background.desktopClock.position = root.clockPositions[i];
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Scale")
                description: qsTr("Size of the desktop clock")
                StyledSlider {
                    width: 220
                    from: 0.5
                    to: 2
                    value: GlobalConfig.background.desktopClock?.scale ?? 1
                    onMoved: {
                        GlobalConfig.background.desktopClock.scale = value;
                        GlobalConfig.save();
                    }
                }
            }

            SettingRow {
                title: qsTr("Invert colors")
                description: qsTr("Flip the clock color for light wallpapers")
                divider: false
                StyledSwitch {
                    checked: GlobalConfig.background.desktopClock?.invertColors ?? false
                    onToggled: {
                        GlobalConfig.background.desktopClock.invertColors = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }



        Section {
            title: qsTr("Location")
            description: qsTr("Where wallpapers are loaded from")
            icon: "folder"

            SettingRow {
                title: qsTr("Wallpaper folder")
                description: qsTr("Directory scanned for wallpapers")
                divider: false
                StyledTextField {
                    width: 280
                    text: GlobalConfig.paths.wallpaperDir || ""
                    onEditingFinished: {
                        GlobalConfig.paths.wallpaperDir = text;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }
}
