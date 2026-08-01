pragma ComponentBehavior: Bound

import ".."
import "../chrome"
import QtQuick
import Quickshell
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    property Session session
    signal back

    function appJoin(list): string {
        if (!list || !list.length)
            return "";
        const parts = [];
        for (let i = 0; i < list.length; i++)
            parts.push(String(list[i]));
        return parts.join(" ");
    }

    function appSplit(text: string): var {
        const t = (text || "").trim();
        if (!t)
            return [];
        return t.split(/\s+/);
    }

    function idxOf(list, val) {
        const v = (val || "").toLowerCase();
        for (let i = 0; i < list.length; i++) {
            if (String(list[i]).toLowerCase() === v)
                return i;
        }
        return 0;
    }

    SettingsPage {
        anchors.fill: parent
        title: qsTr("System")
        subtitle: qsTr("Apps, clock, media and advanced")
        icon: "tune"
        accent: Colours.palette.m3primary
        onBack: root.back()

        Section {
            title: qsTr("Default apps")
            description: qsTr("Programs the shell launches for common actions")
            icon: "open_in_new"

            SettingRow {
                title: qsTr("Terminal")
                description: qsTr("Command used to open a terminal")
                icon: "terminal"
                StyledTextField {
                    width: 240
                    text: root.appJoin(GlobalConfig.general.apps.terminal)
                    onEditingFinished: {
                        GlobalConfig.general.apps.terminal = root.appSplit(text);
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Audio mixer")
                description: qsTr("App opened from the volume controls")
                icon: "tune"
                StyledTextField {
                    width: 240
                    text: root.appJoin(GlobalConfig.general.apps.audio)
                    onEditingFinished: {
                        GlobalConfig.general.apps.audio = root.appSplit(text);
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Media player")
                description: qsTr("App used for playback actions")
                icon: "movie"
                StyledTextField {
                    width: 240
                    text: root.appJoin(GlobalConfig.general.apps.playback)
                    onEditingFinished: {
                        GlobalConfig.general.apps.playback = root.appSplit(text);
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("File manager")
                description: qsTr("App opened to browse files")
                icon: "folder"
                divider: false
                StyledTextField {
                    width: 240
                    text: root.appJoin(GlobalConfig.general.apps.explorer)
                    onEditingFinished: {
                        GlobalConfig.general.apps.explorer = root.appSplit(text);
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            title: qsTr("Clock & weather")
            description: qsTr("Time format and locale")
            icon: "schedule"

            SettingRow {
                title: qsTr("Clock format")
                description: qsTr("12-hour or 24-hour time")
                Segmented {
                    minSegmentWidth: 96
                    model: [{
                            label: qsTr("24-hour")
                        }, {
                            label: qsTr("12-hour")
                        }]
                    currentIndex: GlobalConfig.services.useTwelveHourClock ? 1 : 0
                    onSelected: i => {
                        GlobalConfig.services.useTwelveHourClock = i === 1;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Temperature unit")
                description: qsTr("Units used for weather readouts")
                Segmented {
                    model: [{
                            label: "°C"
                        }, {
                            label: "°F"
                        }]
                    currentIndex: GlobalConfig.services.useFahrenheit ? 1 : 0
                    onSelected: i => {
                        GlobalConfig.services.useFahrenheit = i === 1;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Weather location")
                description: qsTr("City used for the weather widget")
                divider: false
                StyledTextField {
                    width: 240
                    text: GlobalConfig.services.weatherLocation || ""
                    onEditingFinished: {
                        GlobalConfig.services.weatherLocation = text;
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            title: qsTr("Media")
            description: qsTr("Now-playing and lyrics behavior")
            icon: "music_note"

            SettingRow {
                title: qsTr("Default player")
                description: qsTr("Preferred source when several are playing")
                OptionPicker {
                    id: playerPicker
                    model: ["Spotify", "mpv", "firefox", "vlc", "auto"]
                    currentIndex: root.idxOf(playerPicker.model, GlobalConfig.services.defaultPlayer || "Spotify")
                    onSelected: i => {
                        GlobalConfig.services.defaultPlayer = playerPicker.model[i];
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Show lyrics")
                description: qsTr("Display synced lyrics when available")
                divider: false
                StyledSwitch {
                    checked: GlobalConfig.services.showLyrics
                    onToggled: {
                        GlobalConfig.services.showLyrics = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        Section {
            title: qsTr("Advanced")
            description: qsTr("Power-user knobs — edit with care")
            icon: "build"

            SettingRow {
                title: qsTr("GPU type")
                description: qsTr("Vendor used for performance monitoring")
                OptionPicker {
                    id: gpuPicker
                    model: ["", "auto", "amd", "nvidia", "intel"]
                    currentIndex: root.idxOf(gpuPicker.model, GlobalConfig.services.gpuType || "")
                    onSelected: i => {
                        GlobalConfig.services.gpuType = gpuPicker.model[i];
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Open config folder")
                description: qsTr("Edit shell.json & shell-tokens.json directly")
                clickable: true
                divider: false
                MaterialIcon {
                    text: "chevron_right"
                    color: Colours.palette.m3onSurfaceVariant
                    iconPointSize: Tokens.font.size.large
                }
                onClicked: Quickshell.execDetached(["xdg-open", Paths.config])
            }
        }
    }
}
