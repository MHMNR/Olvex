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

    required property bool active
    required property int secondsRemaining

    signal confirmClicked
    signal revertClicked

    readonly property int rExLarge: (Tokens.rounding && typeof Tokens.rounding.extraLarge !== "undefined") ? Tokens.rounding.extraLarge : 24
    readonly property int rFull: (Tokens.rounding && typeof Tokens.rounding.full !== "undefined") ? Tokens.rounding.full : 999
    readonly property int padLarge: (Tokens.padding && typeof Tokens.padding.large !== "undefined") ? Tokens.padding.large : 16
    readonly property int spLarge: (Tokens.spacing && typeof Tokens.spacing.large !== "undefined") ? Tokens.spacing.large : 16
    readonly property int spNormal: (Tokens.spacing && typeof Tokens.spacing.normal !== "undefined") ? Tokens.spacing.normal : 12
    readonly property int fLarge: (Tokens.font && typeof Tokens.font.size.large !== "undefined") ? Tokens.font.size.large : 16
    readonly property int fNormal: (Tokens.font && typeof Tokens.font.size.normal !== "undefined") ? Tokens.font.size.normal : 14
    readonly property int fSmall: (Tokens.font && typeof Tokens.font.size.small !== "undefined") ? Tokens.font.size.small : 12
    readonly property int fSmaller: (Tokens.font && typeof Tokens.font.size.smaller !== "undefined") ? Tokens.font.size.smaller : 11

    anchors.fill: parent
    visible: active
    z: 999

    // Dimmed Scrim Background
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Colours.palette.m3scrim || "#000000", 0.65)

        MouseArea {
            anchors.fill: parent
            // Block background clicks
        }
    }

    // Modal Card
    StyledRect {
        anchors.centerIn: parent
        implicitWidth: 440
        implicitHeight: cardCol.implicitHeight + root.padLarge * 2
        radius: root.rExLarge
        color: Colours.palette.m3surfaceContainerHigh
        border.width: 1
        border.color: Colours.palette.m3primary

        ColumnLayout {
            id: cardCol
            anchors.fill: parent
            anchors.margins: root.padLarge
            spacing: root.spLarge

            // Countdown Header Icon & Number
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: root.spNormal

                StyledRect {
                    implicitWidth: 54
                    implicitHeight: 54
                    radius: root.rFull
                    color: Colours.palette.m3primaryContainer

                    StyledText {
                        anchors.centerIn: parent
                        text: String(root.secondsRemaining)
                        font.weight: Font.Bold
                        textPointSize: root.fLarge
                        color: Colours.palette.m3onPrimaryContainer
                    }
                }

                ColumnLayout {
                    spacing: 2
                    StyledText {
                        text: qsTr("Confirm Display Settings")
                        font.weight: Font.Bold
                        textPointSize: root.fNormal
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        text: qsTr("Testing new monitor configuration")
                        textPointSize: root.fSmaller
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }

            // Message text
            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Do you want to keep these changes? If your screen is blank or unsupported, settings will automatically revert in %1 seconds.").arg(root.secondsRemaining)
                color: Colours.palette.m3onSurfaceVariant
                textPointSize: root.fSmall
                wrapMode: Text.WordWrap
            }

            // Action Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: root.spNormal

                // Revert button
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: root.rFull
                    color: Colours.palette.m3surfaceContainerHighest
                    border.width: 1
                    border.color: Qt.alpha(Colours.palette.m3outline, 0.5)

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialIcon {
                            text: "undo"
                            iconPointSize: root.fNormal
                            color: Colours.palette.m3onSurface
                        }
                        StyledText {
                            text: qsTr("Revert Now")
                            font.weight: Font.Bold
                            textPointSize: root.fSmall
                            color: Colours.palette.m3onSurface
                        }
                    }

                    StateLayer {
                        radius: parent.radius
                        onClicked: root.revertClicked()
                    }
                }

                // Keep Changes button
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: root.rFull
                    color: Colours.palette.m3primary

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialIcon {
                            text: "check"
                            iconPointSize: root.fNormal
                            color: Colours.palette.m3onPrimary
                        }
                        StyledText {
                            text: qsTr("Keep Changes")
                            font.weight: Font.Bold
                            textPointSize: root.fSmall
                            color: Colours.palette.m3onPrimary
                        }
                    }

                    StateLayer {
                        radius: parent.radius
                        onClicked: root.confirmClicked()
                    }
                }
            }
        }
    }
}
