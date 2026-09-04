pragma ComponentBehavior: Bound


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

    Section {
        Layout.fillWidth: true
        title: qsTr("Lock screen")
        description: qsTr("Layout of the lock screen")
        icon: "screen_lock_portrait"

        SettingRow {
            title: qsTr("Style")
            description: qsTr("Card shows a full panel; minimal is bare")
            divider: false
            Segmented {
                minSegmentWidth: 104
                implicitHeight: 42
                model: [{
                        label: qsTr("Card"),
                        icon: "credit_card"
                    }, {
                        label: qsTr("Minimal"),
                        icon: "crop_square"
                    }]
                currentIndex: (GlobalConfig.lock.style || "card") === "minimal" ? 1 : 0
                onSelected: i => {
                    GlobalConfig.lock.style = i === 0 ? "card" : "minimal";
                    GlobalConfig.save();
                }
            }
        }
    }

    Section {
        Layout.fillWidth: true
        title: qsTr("Background")
        description: qsTr("How the wallpaper looks while locked")
        icon: "blur_on"

        SettingRow {
            title: qsTr("Blur wallpaper")
            description: qsTr("Apply a blur to the locked background")
            StyledSwitch {
                checked: GlobalConfig.lock.blurBackground
                onToggled: {
                    GlobalConfig.lock.blurBackground = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Glass blur")
            description: qsTr("Frosted glass effect on lock cards and elements")
            StyledSwitch {
                checked: GlobalConfig.lock.cardBlur
                onToggled: {
                    GlobalConfig.lock.cardBlur = checked;
                    GlobalConfig.save();
                }
            }
        }

        SettingRow {
            title: qsTr("Blur radius")
            description: qsTr("Intensity and radius of the blur effect")
            StyledSlider {
                implicitWidth: 220
                from: 8
                to: 80
                stepSize: 2
                value: GlobalConfig.lock.blurRadius || 48
                onMoved: {
                    GlobalConfig.lock.blurRadius = Math.round(value);
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Dim wallpaper")
            description: qsTr("Darken the background for readability")
            StyledSwitch {
                checked: GlobalConfig.lock.dimWallpaper
                onToggled: {
                    GlobalConfig.lock.dimWallpaper = checked;
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Background opacity")
            description: qsTr("Card and pill background opacity")
            divider: false
            StyledSlider {
                implicitWidth: 220
                from: 0.2
                to: 1.0
                stepSize: 0.01
                value: GlobalConfig.lock.minimalOpacity
                onMoved: {
                    GlobalConfig.lock.minimalOpacity = value;
                    GlobalConfig.save();
                }
            }
        }
    }

    Section {
        Layout.fillWidth: true
        title: qsTr("Behavior")
        description: qsTr("When and how the screen locks")
        icon: "policy"

        SettingRow {
            title: qsTr("Lock on startup")
            description: qsTr("Require unlock right after logging in")
            StyledSwitch {
                checked: GlobalConfig.lock.showOnStartup
                onToggled: {
                    GlobalConfig.lock.showOnStartup = checked;
                    GlobalConfig.save();
                }
            }
        }
        
        SettingRow {
            title: qsTr("Hide notifications")
            description: qsTr("Don't reveal notification content while locked")
            divider: false
            StyledSwitch {
                checked: GlobalConfig.lock.hideNotifs
                onToggled: {
                    GlobalConfig.lock.hideNotifs = checked;
                    GlobalConfig.save();
                }
            }
        }
    }

    Section {
        Layout.fillWidth: true
        title: qsTr("Fingerprint")
        description: qsTr("Biometric unlock")
        icon: "fingerprint"

        SettingRow {
            title: qsTr("Enable fingerprint")
            description: qsTr("Allow unlocking with a fingerprint reader")
            divider: false
            StyledSwitch {
                checked: GlobalConfig.lock.enableFprint
                onToggled: {
                    GlobalConfig.lock.enableFprint = checked;
                    GlobalConfig.save();
                }
            }
        }
    }
}
