pragma ComponentBehavior: Bound

import ".."
import "../chrome"
import QtQuick
import Olvex.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    property Session session
    signal back

    SettingsPage {
        anchors.fill: parent
        title: qsTr("Lock & Security")
        subtitle: qsTr("Lock screen and authentication")
        icon: "lock"
        accent: Colours.palette.m3secondary
        onBack: root.back()

        Section {
            title: qsTr("Lock screen")
            description: qsTr("Layout of the lock screen")
            icon: "screen_lock_portrait"

            SettingRow {
                title: qsTr("Style")
                description: qsTr("Card shows a full panel; minimal is bare")
                divider: false
                Segmented {
                    // Room for icon + "Minimal" label — default 64px slots were crushing the pill
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
                title: qsTr("Element opacity")
                description: qsTr("Opacity of minimal-style elements")
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
                title: qsTr("Recolor logo")
                description: qsTr("Tint the lock-screen logo to the theme")
                StyledSwitch {
                    checked: GlobalConfig.lock.recolourLogo
                    onToggled: {
                        GlobalConfig.lock.recolourLogo = checked;
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
            title: qsTr("Fingerprint")
            description: qsTr("Biometric unlock")
            icon: "fingerprint"

            SettingRow {
                title: qsTr("Enable fingerprint")
                description: qsTr("Allow unlocking with a fingerprint reader")
                StyledSwitch {
                    checked: GlobalConfig.lock.enableFprint
                    onToggled: {
                        GlobalConfig.lock.enableFprint = checked;
                        GlobalConfig.save();
                    }
                }
            }
            SettingRow {
                title: qsTr("Max attempts")
                description: qsTr("Fingerprint tries before password fallback")
                divider: false
                CustomSpinBox {
                    value: GlobalConfig.lock.maxFprintTries ?? 3
                    min: 1
                    max: 10
                    step: 1
                    onValueModified: v => {
                        GlobalConfig.lock.maxFprintTries = v;
                        GlobalConfig.save();
                    }
                }
            }
        }
    }
}
