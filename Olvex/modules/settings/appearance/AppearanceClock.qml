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

ColumnLayout {
    id: root
    
    property Session session
    spacing: Tokens.spacing.large
    opacity: 0.0
    transform: Translate { y: 20; id: yTrans }

    readonly property var placementStrategies: ["leastBusy", "mostBusy", "fixed"]
    readonly property var strategyLabels: [qsTr("Auto (Least Busy)"), qsTr("Auto (Most Busy)"), qsTr("Fixed (Manual)")]
    readonly property var clockPositions: ["middle-center", "top-left", "top-center", "top-right", "middle-left", "middle-right", "bottom-left", "bottom-center", "bottom-right"]

    function idxOf(list, val) {
        for (let i = 0; i < list.length; i++) {
            if (list[i] === val) return i;
        }
        return 0;
    }

    Component.onCompleted: {
        revealAnim.start();
    }

    ParallelAnimation {
        id: revealAnim
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: 400; easing.type: Easing.OutCubic }
        NumberAnimation { target: yTrans; property: "y"; to: 0; duration: 400; easing.type: Easing.OutCubic }
    }

    Section {
        Layout.fillWidth: true
        title: qsTr("Desktop Clock")
        description: qsTr("Configure desktop clock widget and automatic positioning")
        icon: "schedule"

        SettingRow {
            title: qsTr("Show clock")
            description: qsTr("Display time and date widget on the desktop wallpaper")
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
            title: qsTr("Placement strategy")
            description: qsTr("Auto-place in wallpaper's empty area or keep fixed")
            OptionPicker {
                model: root.strategyLabels
                currentIndex: root.idxOf(root.placementStrategies, (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.placementStrategy) ? GlobalConfig.background.desktopClock.placementStrategy : "fixed")
                onSelected: i => {
                    if (GlobalConfig.background && GlobalConfig.background.desktopClock) {
                        GlobalConfig.background.desktopClock.placementStrategy = root.placementStrategies[i];
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            visible: (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.placementStrategy === "fixed")
            title: qsTr("Clock position")
            description: qsTr("Where the clock is fixed on the desktop")
            OptionPicker {
                model: root.clockPositions
                currentIndex: root.idxOf(root.clockPositions, (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.position) ? GlobalConfig.background.desktopClock.position : "middle-center")
                onSelected: i => {
                    if (GlobalConfig.background && GlobalConfig.background.desktopClock) {
                        GlobalConfig.background.desktopClock.position = root.clockPositions[i];
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Clock scale")
            description: qsTr("Adjust size of the desktop clock widget")
            StyledSlider {
                width: 240
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
            title: qsTr("Adaptive text contrast")
            description: qsTr("Automatically pick high contrast color based on wallpaper region")
            StyledSwitch {
                checked: (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.adaptiveTextColor !== undefined) ? GlobalConfig.background.desktopClock.adaptiveTextColor : true
                onToggled: {
                    if (GlobalConfig.background && GlobalConfig.background.desktopClock) {
                        GlobalConfig.background.desktopClock.adaptiveTextColor = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Invert color")
            description: qsTr("Force dark text palette instead of light")
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

    Section {
        Layout.fillWidth: true
        title: qsTr("Background Plate & Blur")
        description: qsTr("Surface card styling behind clock digits")
        icon: "blur_on"

        SettingRow {
            title: qsTr("Clock background card")
            description: qsTr("Show a subtle rounded M3 card behind the clock")
            StyledSwitch {
                checked: Boolean(GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.background && GlobalConfig.background.desktopClock.background.enabled)
                onToggled: {
                    if (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.background) {
                        GlobalConfig.background.desktopClock.background.enabled = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            visible: Boolean(GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.background && GlobalConfig.background.desktopClock.background.enabled)
            title: qsTr("Card background blur")
            description: qsTr("Frosted glass effect behind clock")
            StyledSwitch {
                checked: Boolean(GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.background && GlobalConfig.background.desktopClock.background.blur)
                onToggled: {
                    if (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.background) {
                        GlobalConfig.background.desktopClock.background.blur = checked;
                        GlobalConfig.save();
                    }
                }
            }
        }

        SettingRow {
            visible: Boolean(GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.background && GlobalConfig.background.desktopClock.background.enabled)
            title: qsTr("Card opacity")
            description: qsTr("Transparency of the clock card plate")
            divider: false
            StyledSlider {
                width: 240
                from: 0.1
                to: 1.0
                value: (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.background && GlobalConfig.background.desktopClock.background.opacity !== undefined) ? GlobalConfig.background.desktopClock.background.opacity : 0.7
                onMoved: {
                    if (GlobalConfig.background && GlobalConfig.background.desktopClock && GlobalConfig.background.desktopClock.background) {
                        GlobalConfig.background.desktopClock.background.opacity = value;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }
}

