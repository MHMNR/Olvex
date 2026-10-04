import "."
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

Item {
    id: root

    required property var profiles
    required property string activeProfileName

    signal saveCurrentProfileRequested(string name)
    signal loadProfileRequested(var profileObj)
    signal deleteProfileRequested(string name)

    implicitWidth: parent ? parent.width : 500
    implicitHeight: mainCol.implicitHeight

    property string newProfileName: ""
    property bool bindWallpapers: true

    Column {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing ? Tokens.spacing.large : 16

        Section {
            title: qsTr("Multi-Monitor Profiles")
            description: qsTr("Save and quickly switch between multi-display configurations")
            icon: "bookmarks"
            accentColor: Colours.palette.m3secondary

            // Bind Wallpapers Toggle
            SettingRow {
                title: qsTr("Profile-Bound Wallpapers")
                description: qsTr("Associate and restore wallpaper assignments when switching profiles")

                StyledSwitch {
                    checked: root.bindWallpapers
                    onToggled: root.bindWallpapers = checked
                }
            }

            // Create New Profile Row
            SettingRow {
                title: qsTr("Save Current Setup")
                description: qsTr("Create a new preset profile with current monitor arrangement")

                RowLayout {
                    spacing: 8

                    StyledTextField {
                        id: profileInput
                        implicitWidth: 180
                        placeholderText: qsTr("Profile name...")
                        text: root.newProfileName
                        onTextEdited: root.newProfileName = text
                    }

                    TextButton {
                        text: qsTr("Save Profile")
                        enabled: root.newProfileName.trim().length > 0
                        onClicked: {
                            root.saveCurrentProfileRequested(root.newProfileName.trim());
                            profileInput.text = "";
                            root.newProfileName = "";
                        }
                    }
                }
            }

            // Saved Profiles List
            Repeater {
                model: root.profiles

                delegate: SettingRow {
                    id: pRow
                    required property var modelData
                    required property int index

                    readonly property bool isActive: root.activeProfileName === modelData.name

                    title: modelData.name || qsTr("Unnamed Profile")
                    description: `${modelData.monitors ? modelData.monitors.length : 0} ${qsTr("displays")} · ${modelData.updatedAt ? modelData.updatedAt.split("T")[0] : ""}`

                    RowLayout {
                        spacing: 8

                        // Active badge
                        StyledRect {
                            visible: pRow.isActive
                            implicitWidth: 64
                            implicitHeight: 28
                            radius: Tokens.rounding ? Tokens.rounding.full : 999
                            color: Colours.palette.m3primaryContainer

                            StyledText {
                                anchors.centerIn: parent
                                text: qsTr("Active")
                                textPointSize: (Tokens.font ? Tokens.font.size.smaller : 11) - 2
                                font.weight: Font.Bold
                                color: Colours.palette.m3onPrimaryContainer
                            }
                        }

                        // Apply Button
                        TextButton {
                            text: qsTr("Apply")
                            onClicked: root.loadProfileRequested(pRow.modelData)
                        }

                        // Delete Button
                        IconButton {
                            type: IconButton.Text
                            icon: "delete"
                            iconPointSize: Tokens.font ? Tokens.font.size.small : 12
                            onClicked: root.deleteProfileRequested(pRow.modelData.name)
                        }
                    }
                }
            }

            // Empty state if no profiles
            Item {
                visible: !root.profiles || root.profiles.length === 0
                implicitWidth: parent.width
                implicitHeight: 60

                StyledText {
                    anchors.centerIn: parent
                    text: qsTr("No saved profiles yet. Save your current setup above!")
                    color: Colours.palette.m3onSurfaceVariant
                    textPointSize: Tokens.font ? Tokens.font.size.small : 12
                }
            }
        }
    }
}
