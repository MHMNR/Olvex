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

SectionContainer {
    id: root

    required property var rootItem

    Layout.fillWidth: true
    alignTop: true

    StyledText {
        text: qsTr("Weather Settings")
        textPointSize: Tokens.font.size.normal
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.normal

        StyledText {
            text: qsTr("Temperature Unit")
            textPointSize: Tokens.font.size.normal
        }

        Item {
            Layout.fillWidth: true
        }

        RowLayout {
            spacing: Tokens.spacing.small

            ToggleButton {
                label: "°C"
                toggled: !root.rootItem.useFahrenheit
                accent: "Primary"
                onClicked: {
                    root.rootItem.useFahrenheit = false;
                    root.rootItem.saveConfig();
                }
            }

            ToggleButton {
                label: "°F"
                toggled: root.rootItem.useFahrenheit
                accent: "Primary"
                onClicked: {
                    root.rootItem.useFahrenheit = true;
                    root.rootItem.saveConfig();
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.normal

        StyledText {
            text: qsTr("Location")
            textPointSize: Tokens.font.size.normal
        }

        Item {
            Layout.fillWidth: true
        }

        StyledInputField {
            id: locationInput

            Layout.preferredWidth: 200
            text: root.rootItem.weatherLocation
            onEditingFinished: {
                root.rootItem.weatherLocation = text;
                root.rootItem.saveConfig();
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        text: qsTr("Enter a city name or 'lat,lon'. Leave empty for auto-detection.")
        textPointSize: Tokens.font.size.small
        color: Colours.palette.m3outline
        wrapMode: Text.WordWrap
    }
}
