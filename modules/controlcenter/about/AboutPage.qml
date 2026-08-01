pragma ComponentBehavior: Bound

import ".."
import "../chrome"
import QtQuick
import QtQuick.Layouts
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

    SettingsPage {
        anchors.fill: parent
        title: qsTr("About")
        subtitle: qsTr("Version and system information")
        icon: "info"
        accent: Colours.palette.m3tertiary
        onBack: root.back()

        // Hero
        Item {
            width: parent.width
            height: 170

            StyledRect {
                anchors.fill: parent
                radius: Tokens.rounding.large
                color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

                // Flat primary tint (no gradient)
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Qt.alpha(Colours.palette.m3primary, 0.12)
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.large

                    StyledRect {
                        width: 88
                        height: 88
                        radius: Tokens.rounding.large
                        color: Qt.alpha(Colours.palette.m3primary, 0.22)

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "deployed_code"
                            fill: 1
                            color: Colours.palette.m3primary
                            iconPointSize: Tokens.font.size.extraLarge * 1.5
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Tokens.spacing.small

                        StyledText {
                            text: "Olvex"
                            font.weight: Font.Normal
                            font.letterSpacing: -0.3
                            color: Colours.palette.m3onSurface
                            // headline-small class — hero only; regular weight
                            textPointSize: Tokens.font.size.extraLarge
                        }
                        StyledText {
                            text: qsTr("A Quickshell desktop for Hyprland")
                            color: Colours.palette.m3onSurfaceVariant
                            font.weight: Font.Normal
                            font.letterSpacing: 0.1
                            lineHeight: 1.35
                            lineHeightMode: Text.ProportionalHeight
                            textPointSize: Tokens.font.size.normal
                        }
                        StyledText {
                            text: qsTr("User: %1 · Shell: %2").arg(SysInfo.user || "—").arg(SysInfo.shell || "—")
                            color: Colours.palette.m3onSurfaceVariant
                            font.weight: Font.Normal
                            font.letterSpacing: 0.15
                            textPointSize: Tokens.font.size.small
                        }
                    }
                }
            }
        }

        Section {
            title: qsTr("System")
            description: qsTr("Environment Olvex is running in")
            icon: "monitor_heart"

            SettingRow {
                title: qsTr("Distribution")
                description: qsTr("Operating system in use")
                divider: true
                StyledText {
                    text: SysInfo.osPrettyName || SysInfo.osName || qsTr("Linux")
                    color: Colours.palette.m3primary
                    font.weight: Font.Normal
                    font.letterSpacing: 0.05
                    textPointSize: Tokens.font.size.normal
                }
            }
            SettingRow {
                title: qsTr("Compositor")
                description: qsTr("Wayland compositor")
                StyledText {
                    text: SysInfo.wm || "Hyprland"
                    color: Colours.palette.m3primary
                    font.weight: Font.Normal
                    font.letterSpacing: 0.05
                    textPointSize: Tokens.font.size.normal
                }
            }
            SettingRow {
                title: qsTr("Uptime")
                description: qsTr("Time since last boot")
                StyledText {
                    text: SysInfo.uptime || qsTr("—")
                    color: Colours.palette.m3primary
                    font.weight: Font.Normal
                    font.letterSpacing: 0.05
                    textPointSize: Tokens.font.size.normal
                }
            }
            SettingRow {
                title: qsTr("Shell framework")
                description: qsTr("What Olvex is built on")
                divider: false
                StyledText {
                    text: "Quickshell · Qt 6"
                    color: Colours.palette.m3primary
                    font.weight: Font.Normal
                    font.letterSpacing: 0.05
                    textPointSize: Tokens.font.size.normal
                }
            }
        }

        Section {
            title: qsTr("Resources")
            description: qsTr("Project links and help")
            icon: "link"

            SettingRow {
                title: qsTr("Repository")
                description: qsTr("Source code and releases on GitHub")
                clickable: true
                MaterialIcon {
                    text: "open_in_new"
                    color: Colours.palette.m3onSurfaceVariant
                    iconPointSize: Tokens.font.size.large
                }
                onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/olvex-dots/shell"])
            }
            SettingRow {
                title: qsTr("Open config folder")
                description: qsTr("shell.json and shell-tokens.json")
                clickable: true
                divider: false
                MaterialIcon {
                    text: "folder_open"
                    color: Colours.palette.m3onSurfaceVariant
                    iconPointSize: Tokens.font.size.large
                }
                onClicked: Quickshell.execDetached(["xdg-open", Paths.config])
            }
        }
    }
}
